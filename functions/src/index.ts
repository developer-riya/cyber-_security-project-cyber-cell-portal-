import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import * as functionsLogger from "firebase-functions/logger";
import {
  defineBoolean,
  defineInt,
  defineSecret,
} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";

import {
  BoundedAbuseSignalTracker,
  BoundedBurstProtector,
  BoundedConcurrencyGate,
} from "./abuse-protection";
import {
  SecurityAuditLogger,
  ThreatIntelligenceAuditEvent,
} from "./audit";
import {FirebaseRequestAuthenticator} from "./auth";
import {BoundedTtlCache} from "./cache";
import {createThreatIntelligenceHttpHandler} from "./http-handler";
import {
  VirusTotalHttpsTransport,
  VirusTotalProviderClient,
} from "./provider";
import {
  FirestoreProxyRateLimiter,
  ProxyRateLimitConfiguration,
} from "./rate-limit";
import {ThreatIntelligenceProxyService} from "./service";
import {createCyberCellCase, cyberCellApi} from "./cyber-cell";

export {createCyberCellCase, cyberCellApi};

const virusTotalApiKey = defineSecret("VIRUSTOTAL_API_KEY");
const threatIntelEnabled = defineBoolean("THREAT_INTEL_ENABLED", {
  default: false,
  description: "Enables the server-side threat-intelligence provider.",
});
const providerRequestsPerMinute = defineInt("THREAT_INTEL_PROVIDER_REQUESTS_PER_MINUTE", {
  default: 240,
  description: "Server-side provider quota guard.",
});
const providerRequestsPerHour = defineInt("THREAT_INTEL_PROVIDER_REQUESTS_PER_HOUR", {
  default: 5_000,
  description: "Shared provider requests allowed per hour.",
});
const userRequestsPerMinute = defineInt("THREAT_INTEL_USER_REQUESTS_PER_MINUTE", {
  default: 30,
  description: "Authenticated user requests allowed per minute.",
});
const userRequestsPerHour = defineInt("THREAT_INTEL_USER_REQUESTS_PER_HOUR", {
  default: 300,
  description: "Authenticated user requests allowed per hour.",
});
const userRequestsPerDay = defineInt("THREAT_INTEL_USER_REQUESTS_PER_DAY", {
  default: 1_000,
  description: "Authenticated user requests allowed per day.",
});
const userOperationRequestsPerMinute = defineInt(
  "THREAT_INTEL_USER_OPERATION_REQUESTS_PER_MINUTE",
  {default: 20, description: "Per-user requests allowed for one operation per minute."},
);
const operationRequestsPerMinute = defineInt(
  "THREAT_INTEL_OPERATION_REQUESTS_PER_MINUTE",
  {default: 200, description: "Global requests allowed for one operation per minute."},
);
const indicatorRequestsPerTenMinutes = defineInt(
  "THREAT_INTEL_INDICATOR_REQUESTS_PER_TEN_MINUTES",
  {default: 10, description: "Distributed repeat limit for a normalized indicator."},
);
const providerOperationRequestsPerMinute = defineInt(
  "THREAT_INTEL_PROVIDER_OPERATION_REQUESTS_PER_MINUTE",
  {default: 120, description: "Provider calls allowed for one operation per minute."},
);
const userBurstRequests = defineInt("THREAT_INTEL_USER_BURST_REQUESTS", {
  default: 10,
  description: "Per-instance user burst requests allowed per ten seconds.",
});
const instanceBurstRequests = defineInt("THREAT_INTEL_INSTANCE_BURST_REQUESTS", {
  default: 50,
  description: "Per-instance burst requests allowed per second.",
});
const providerConcurrency = defineInt("THREAT_INTEL_PROVIDER_CONCURRENCY", {
  default: 8,
  description: "Maximum provider calls concurrently active in one instance.",
});
const maximumInFlight = defineInt("THREAT_INTEL_MAX_IN_FLIGHT", {
  default: 64,
  description: "Maximum unique in-flight lookups retained in one instance.",
});
const allowedOrigins = new Set([
  "https://cyberuday.in",
  "https://www.cyberuday.in",
]);

const app = getApps()[0] ?? initializeApp();

class FirebaseFunctionsAuditLogger implements SecurityAuditLogger {
  record(event: ThreatIntelligenceAuditEvent): void {
    functionsLogger.info(event.type, event);
  }
}

const auditLogger = new FirebaseFunctionsAuditLogger();
const abuseTracker = new BoundedAbuseSignalTracker();
const rateLimiter = new FirestoreProxyRateLimiter(
  getFirestore(app),
  rateLimitConfiguration,
);
const service = new ThreatIntelligenceProxyService({
  provider: new VirusTotalProviderClient(new VirusTotalHttpsTransport()),
  rateLimiter,
  cache: new BoundedTtlCache(256, 10 * 60_000),
  burstProtector: new BoundedBurstProtector(() => ({
    userRequests: userBurstRequests.value(),
    userWindowMs: 10_000,
    instanceRequests: instanceBurstRequests.value(),
    instanceWindowMs: 1_000,
    maxUserEntries: 1_024,
  })),
  concurrencyGate: new BoundedConcurrencyGate(() => providerConcurrency.value()),
  abuseTracker,
  maxInFlight: () => maximumInFlight.value(),
  auditLogger,
});

const handler = createThreatIntelligenceHttpHandler({
  authenticator: new FirebaseRequestAuthenticator(),
  service,
  auditLogger,
  abuseTracker,
  allowedOrigins,
  runtimeConfiguration: () => ({
    enabled: threatIntelEnabled.value(),
    requireAppCheck: true,
    providerApiKey: readProviderSecret(),
  }),
});

export const threatIntelligenceProxy = onRequest({
  region: "asia-south1",
  memory: "256MiB",
  timeoutSeconds: 10,
  maxInstances: 10,
  concurrency: 20,
  invoker: "public",
  secrets: [virusTotalApiKey],
}, handler);

function readProviderSecret(): string {
  try {
    return virusTotalApiKey.value().trim();
  } catch {
    return "";
  }
}

function rateLimitConfiguration(): ProxyRateLimitConfiguration {
  const userOperation = operationRecord(userOperationRequestsPerMinute.value());
  const operation = operationRecord(operationRequestsPerMinute.value());
  const providerOperation = operationRecord(
    providerOperationRequestsPerMinute.value(),
  );
  return {
    userRequestsPerMinute: userRequestsPerMinute.value(),
    userRequestsPerHour: userRequestsPerHour.value(),
    userRequestsPerDay: userRequestsPerDay.value(),
    userOperationRequestsPerMinute: userOperation,
    operationRequestsPerMinute: operation,
    indicatorRequestsPerTenMinutes: indicatorRequestsPerTenMinutes.value(),
    providerRequestsPerMinute: providerRequestsPerMinute.value(),
    providerRequestsPerHour: providerRequestsPerHour.value(),
    providerOperationRequestsPerMinute: providerOperation,
  };
}

function operationRecord(value: number): ProxyRateLimitConfiguration[
  "operationRequestsPerMinute"
] {
  return {HASH: value, URL: value, DOMAIN: value, IPV4: value, IPV6: value};
}
