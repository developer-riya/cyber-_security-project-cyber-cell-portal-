import {Buffer} from "node:buffer";

import {Request, Response} from "express";

import {BoundedAbuseSignalTracker} from "./abuse-protection";
import {
  createRequestId,
  safeFingerprint,
  SecurityAuditLogger,
} from "./audit";
import {
  AuthenticationError,
  RequestAuthenticator,
} from "./auth";
import {ThreatIntelligenceProxyService} from "./service";
import {
  RuntimeSecurityConfiguration,
  ThreatIntelligenceProxyResponse,
} from "./types";
import {
  RequestValidationError,
  validateIndicatorRequest,
} from "./validation";

const MAX_REQUEST_BYTES = 2_048;

export interface ThreatIntelligenceHttpDependencies {
  readonly authenticator: RequestAuthenticator;
  readonly service: ThreatIntelligenceProxyService;
  readonly auditLogger: SecurityAuditLogger;
  readonly abuseTracker: BoundedAbuseSignalTracker;
  readonly allowedOrigins: ReadonlySet<string>;
  readonly runtimeConfiguration: () => RuntimeSecurityConfiguration;
}

export function createThreatIntelligenceHttpHandler(
  dependencies: ThreatIntelligenceHttpDependencies,
): (request: Request, response: Response) => Promise<void> {
  return async (request: Request, response: Response): Promise<void> => {
    const requestId = createRequestId();
    applySecurityHeaders(response);
    if (!applyCors(request, response, dependencies.allowedOrigins)) {
      reject(dependencies.auditLogger, response, requestId, 403, "VALIDATION");
      return;
    }
    if (request.method === "OPTIONS") {
      response.status(204).send();
      return;
    }
    if (request.method !== "POST") {
      response.setHeader("Allow", "POST, OPTIONS");
      reject(dependencies.auditLogger, response, requestId, 405, "VALIDATION");
      return;
    }
    const contentType = request.header("content-type")?.toLowerCase() ?? "";
    if (!contentType.startsWith("application/json")) {
      reject(dependencies.auditLogger, response, requestId, 415, "VALIDATION");
      return;
    }
    const rawBody = (request as Request & {rawBody?: Buffer}).rawBody;
    const measuredSize = rawBody?.length ?? Buffer.byteLength(safeSerialize(request.body));
    if (measuredSize === 0 || measuredSize > MAX_REQUEST_BYTES) {
      reject(dependencies.auditLogger, response, requestId, 413, "VALIDATION");
      return;
    }

    const runtime = dependencies.runtimeConfiguration();
    let identity;
    try {
      identity = await dependencies.authenticator.verify(
        request.header("authorization"),
        request.header("x-firebase-appcheck"),
        runtime.requireAppCheck,
      );
    } catch (error) {
      const category = error instanceof AuthenticationError ?
        error.category : "AUTHENTICATION";
      const abuseSignal = dependencies.abuseTracker.observe({
        kind: category === "APP_CHECK" ? "APP_CHECK_FAILURE" : "AUTH_FAILURE",
        scope: category,
      }, Date.now());
      dependencies.auditLogger.record({
        type: category === "APP_CHECK" ?
          "THREAT_INTEL_APP_CHECK_REJECTED" : "THREAT_INTEL_AUTH_REJECTED",
        requestId,
        status: category,
        ...(abuseSignal === "NORMAL" ? {} : {abuseSignal}),
      });
      if (abuseSignal !== "NORMAL") {
        dependencies.auditLogger.record({
          type: "THREAT_INTEL_ABUSE_SIGNAL",
          requestId,
          status: abuseSignal,
          reason: category,
          abuseSignal,
        });
      }
      reject(
        dependencies.auditLogger,
        response,
        requestId,
        category === "APP_CHECK" ? 403 : 401,
        category,
      );
      return;
    }

    let normalized;
    try {
      normalized = validateIndicatorRequest(request.body);
    } catch (error) {
      const category = error instanceof RequestValidationError ?
        "VALIDATION" : "VALIDATION";
      const abuseSignal = dependencies.abuseTracker.observe({
        kind: "INVALID_INDICATOR",
        scope: safeFingerprint(identity.uid),
        actor: identity.uid,
      }, Date.now());
      if (abuseSignal !== "NORMAL") {
        dependencies.auditLogger.record({
          type: "THREAT_INTEL_ABUSE_SIGNAL",
          requestId,
          userFingerprint: safeFingerprint(identity.uid),
          status: abuseSignal,
          reason: "INVALID_INDICATOR",
          abuseSignal,
        });
      }
      reject(dependencies.auditLogger, response, requestId, 400, category);
      return;
    }
    dependencies.auditLogger.record({
      type: "THREAT_INTEL_PROXY_REQUEST",
      requestId,
      userFingerprint: safeFingerprint(identity.uid),
      indicatorFingerprint: safeFingerprint(normalized.indicator),
      operation: normalized.operation,
      provider: "virustotal-premium",
    });

    try {
      const result = await dependencies.service.lookup(
        requestId,
        identity,
        normalized,
        runtime,
      );
      response.status(result.statusCode).json(result.response);
    } catch {
      dependencies.auditLogger.record({
        type: "THREAT_INTEL_PROXY_PROVIDER_ERROR",
        requestId,
        userFingerprint: safeFingerprint(identity.uid),
        indicatorFingerprint: safeFingerprint(normalized.indicator),
        operation: normalized.operation,
        provider: "virustotal-premium",
        status: "ERROR",
      });
      response.status(503).json(errorResponse(normalized.operation, normalized.transmittedValueType));
    }
  };
}

function applyCors(
  request: Request,
  response: Response,
  allowedOrigins: ReadonlySet<string>,
): boolean {
  const origin = request.header("origin");
  response.setHeader("Vary", "Origin");
  if (origin === undefined) return true;
  if (!allowedOrigins.has(origin)) return false;
  response.setHeader("Access-Control-Allow-Origin", origin);
  response.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.setHeader(
    "Access-Control-Allow-Headers",
    "Authorization, Content-Type, X-Firebase-AppCheck",
  );
  response.setHeader("Access-Control-Max-Age", "600");
  return true;
}

function applySecurityHeaders(response: Response): void {
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Content-Type", "application/json; charset=utf-8");
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Referrer-Policy", "no-referrer");
}

function reject(
  auditLogger: SecurityAuditLogger,
  response: Response,
  requestId: string,
  statusCode: number,
  category: "AUTHENTICATION" | "APP_CHECK" | "VALIDATION",
): void {
  auditLogger.record({
    type: "THREAT_INTEL_PROXY_REJECTED",
    requestId,
    status: category,
  });
  response.status(statusCode).json({
    status: "ERROR",
    errorCategory: category,
  });
}

function errorResponse(
  operation: ThreatIntelligenceProxyResponse["operation"],
  transmittedValueType: ThreatIntelligenceProxyResponse["privacy"]["transmittedValueType"],
): ThreatIntelligenceProxyResponse {
  return {
    operation,
    status: "ERROR",
    evidence: ["Threat intelligence was unavailable; local analysis remains available."],
    providerStatus: "UNAVAILABLE",
    durationMs: 0,
    cache: {hit: false},
    privacy: {
      rawContentTransmitted: false,
      transmittedValueType,
      privacyMode: "INDICATOR_ONLY",
    },
    errorCategory: "PROVIDER",
  };
}

function safeSerialize(value: unknown): string {
  try {
    return JSON.stringify(value) ?? "";
  } catch {
    return "";
  }
}
