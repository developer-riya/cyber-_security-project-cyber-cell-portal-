import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const db = getFirestore();
const allowedStatuses = new Set([
  "Submitted", "Accepted", "Under Review", "Additional Information Required",
  "Case Updated", "Closed",
]);
type OfficerRole = "officer" | "admin";

export const createCyberCellCase = onDocumentCreated(
  {document: "reports/{reportId}", region: "asia-south1"},
  async (event) => {
    const report = event.data?.data();
    const reportId = event.params.reportId;
    if (report === undefined || report.destination !== "Cyber Cell") return;
    const existing = await db.collection("cyber_cell_cases")
      .where("incidentId", "==", reportId).limit(1).get();
    if (!existing.empty) return;

    const sequenceRef = db.collection("system").doc("cyber_cell");
    const sequence = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(sequenceRef);
      const next = (snapshot.data()?.nextCaseNumber as number | undefined ?? 0) + 1;
      transaction.set(sequenceRef, {nextCaseNumber: next}, {merge: true});
      return next;
    });
    const caseId = `CYB-${new Date().getUTCFullYear()}-${String(sequence).padStart(5, "0")}`;
    const riskScore = scoreReport(report);
    const riskLevel = riskScore >= 75 ? "HIGH" : riskScore >= 45 ? "MEDIUM" : "LOW";
    const priority = riskScore >= 75 ? "URGENT" : riskScore >= 45 ? "HIGH" : "NORMAL";
    const createdAt = report.createdAt ?? FieldValue.serverTimestamp();
    const caseRef = db.collection("cyber_cell_cases").doc(reportId);
    const trackingRef = db.collection("case_tracking").doc(reportId);

    await db.runTransaction(async (transaction) => {
      transaction.create(caseRef, {
        caseId, incidentId: reportId, userId: report.userId ?? null,
        userEmail: report.userEmail ?? null,
        incidentType: String(report.type ?? "Cybercrime Report"),
        incidentCategory: String(report.category ?? "Uncategorized"),
        description: String(report.description ?? ""),
        timeline: String(report.timeline ?? ""), location: report.location ?? null,
        evidenceReferences: evidenceReferences(report, reportId),
        riskScore, riskLevel, priority, status: "Submitted", assignedOfficer: null,
        createdAt, updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(trackingRef, {
        caseId, incidentId: reportId, userId: report.userId ?? null,
        status: "Submitted", createdAt, updatedAt: FieldValue.serverTimestamp(),
        visibleUpdates: [],
      });
    });
  },
);

export const cyberCellApi = onRequest(
  {region: "asia-south1", invoker: "public", cors: true},
  async (request, response) => {
    try {
      const identity = await authenticateOfficer(request.headers.authorization);
      const path = request.path.replace(/^\/+|\/+$/g, "").split("/");
      const method = request.method.toUpperCase();
      if (method === "GET" && path.length === 2 && path[1] === "dashboard") {
        response.json(await dashboard()); return;
      }
      if (method === "GET" && path.length === 2 && path[1] === "cases") {
        response.json({cases: await listCases()}); return;
      }
      if (path[0] !== "cases" || path.length < 2) {
        response.status(404).json({error: "not-found"}); return;
      }
      const caseId = path[1];
      const caseSnapshot = await findCase(caseId);
      if (caseSnapshot === null) {
        response.status(404).json({error: "case-not-found"}); return;
      }
      if (method === "GET" && path.length === 2) {
        response.json({case: {id: caseSnapshot.id, ...caseSnapshot.data()}}); return;
      }
      if (method === "GET" && path[2] === "history") {
        const history = await db.collection("cyber_cell_cases").doc(caseSnapshot.id)
          .collection("history").orderBy("timestamp", "desc").get();
        response.json({history: history.docs.map((item) => ({id: item.id, ...item.data()}))}); return;
      }
      if (method === "PATCH" && path[2] === "status") {
        const status = String(request.body?.status ?? "");
        if (!allowedStatuses.has(status)) { response.status(400).json({error: "invalid-status"}); return; }
        await updateStatus(caseSnapshot, status, String(request.body?.note ?? ""), identity);
        response.json({ok: true}); return;
      }
      if (method === "PATCH" && path[2] === "assign") {
        const officer = String(request.body?.assignedOfficer ?? "").trim();
        if (officer.length === 0 || officer.length > 160) { response.status(400).json({error: "invalid-officer"}); return; }
        await caseSnapshot.ref.update({assignedOfficer: officer, updatedAt: FieldValue.serverTimestamp()});
        await writeHistory(caseSnapshot.id, "Assignment updated", identity, officer);
        response.json({ok: true}); return;
      }
      if (method === "POST" && path[2] === "request-info") {
        const note = boundedText(request.body?.message);
        if (note === null) { response.status(400).json({error: "invalid-message"}); return; }
        await updateStatus(caseSnapshot, "Additional Information Required", note, identity);
        await db.collection("case_information_requests").add({
          caseId: caseSnapshot.data().caseId,
          requestMessage: note,
          requestedBy: identity.uid,
          requestedAt: FieldValue.serverTimestamp(),
          response: null,
          responseAt: null,
          userId: caseSnapshot.data().userId,
        });
        await db.collection("notifications").add({
          userId: caseSnapshot.data().userId, type: "case-information-request",
          caseId: caseSnapshot.data().caseId, message: note, read: false,
          createdAt: FieldValue.serverTimestamp(),
        });
        response.json({ok: true}); return;
      }
      if (method === "POST" && path[2] === "updates") {
        const note = boundedText(request.body?.message);
        if (note === null) { response.status(400).json({error: "invalid-message"}); return; }
        await updateStatus(caseSnapshot, "Case Updated", note, identity);
        response.json({ok: true}); return;
      }
      response.status(404).json({error: "not-found"});
    } catch (error) {
      if (error instanceof Error && ["unauthorized", "role-missing", "inactive"].includes(error.message)) {
        response.status(403).json({error: error.message}); return;
      }
      logger.error("Cyber Cell API failure", error);
      response.status(500).json({error: "internal-error"});
    }
  },
);

async function authenticateOfficer(header: string | undefined): Promise<{uid: string; role: OfficerRole}> {
  const match = /^Bearer ([^\s]+)$/.exec(header ?? "");
  if (match === null) throw new Error("unauthorized");
  const token = await getAuth().verifyIdToken(match[1], true);
  const userSnapshot = await db.collection("users").doc(token.uid).get();
  const user = userSnapshot.data();
  if (user === undefined) throw new Error("role-missing");
  if (user.isActive === false) throw new Error("inactive");

  const configuredRoles = Array.isArray(user.roles) ? user.roles : [user.role];
  const firestoreRole = configuredRoles.find((role) =>
    role === "cyber_cell_officer" || role === "cyber_cell_admin" || role === "admin",
  );
  if (firestoreRole === "cyber_cell_admin" || firestoreRole === "admin") {
    return {uid: token.uid, role: "admin"};
  }
  if (firestoreRole === "cyber_cell_officer") {
    return {uid: token.uid, role: "officer"};
  }

  // Keep deployments that already use the server-managed claim compatible,
  // without allowing an unrecognized client-provided value.
  const claimRole = token.cyberCellRole;
  if (claimRole === "admin" || claimRole === "officer") {
    return {uid: token.uid, role: claimRole};
  }
  throw new Error("role-missing");
}

async function dashboard(): Promise<Record<string, number>> {
  const cases = await listCases();
  return {
    totalCases: cases.length,
    newCases: cases.filter((item) => item.status === "Submitted").length,
    acceptedCases: cases.filter((item) => item.status === "Accepted").length,
    underReview: cases.filter((item) => item.status === "Under Review").length,
    highPriority: cases.filter((item) => item.priority === "URGENT" || item.riskLevel === "HIGH").length,
    informationRequired: cases.filter((item) => item.status === "Additional Information Required").length,
    recentlyUpdated: cases.filter((item) => item.status === "Case Updated").length,
  };
}

async function listCases(): Promise<Record<string, unknown>[]> {
  const snapshot = await db.collection("cyber_cell_cases").orderBy("updatedAt", "desc").get();
  return snapshot.docs.map((item) => ({id: item.id, ...item.data()}));
}

async function findCase(caseId: string) {
  if (!/^CYB-\d{4}-\d{5}$/.test(caseId)) return null;
  const snapshot = await db.collection("cyber_cell_cases").where("caseId", "==", caseId).limit(1).get();
  return snapshot.empty ? null : snapshot.docs[0];
}

async function updateStatus(
  snapshot: FirebaseFirestore.QueryDocumentSnapshot,
  status: string,
  note: string,
  identity: {uid: string; role: OfficerRole},
) {
  const previousStatus = String(snapshot.data().status ?? "Submitted");
  await snapshot.ref.update({status, updatedAt: FieldValue.serverTimestamp()});
  await db.collection("case_tracking").doc(snapshot.id).set({
    status, updatedAt: FieldValue.serverTimestamp(),
    visibleUpdates: FieldValue.arrayUnion({status, note, timestamp: Timestamp.now()}),
  }, {merge: true});
  await writeHistory(snapshot.id, previousStatus, identity, note, status);
}

async function writeHistory(documentId: string, previousStatus: string, identity: {uid: string; role: OfficerRole}, note: string, newStatus = previousStatus) {
  await db.collection("cyber_cell_cases").doc(documentId).collection("history").add({
    previousStatus, newStatus, updatedBy: identity.uid, role: identity.role, note,
    timestamp: FieldValue.serverTimestamp(),
  });
}

function boundedText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= 2_000 ? text : null;
}

function scoreReport(report: FirebaseFirestore.DocumentData): number {
  const text = `${report.type ?? ""} ${report.description ?? ""} ${report.evidence ?? ""}`.toLowerCase();
  let score = 20;
  if (/(bank|payment|transaction|otp|account|money|fraud)/.test(text)) score += 35;
  if (/(urgent|threat|blackmail|identity|stolen|large)/.test(text)) score += 30;
  if (String(report.evidence ?? "").trim().length > 0) score += 10;
  return Math.min(score, 100);
}

function evidenceReferences(report: FirebaseFirestore.DocumentData, reportId: string) {
  const evidence = String(report.evidence ?? "").trim();
  return evidence === "" ? [] : [{
    evidenceId: `EVD-${reportId}`, evidenceType: "Citizen-provided reference",
    description: "Reference supplied with the incident report",
    referenceDate: report.createdAt ?? FieldValue.serverTimestamp(),
    secureStorageReference: `reports/${reportId}`, verificationStatus: "Unverified",
  }];
}