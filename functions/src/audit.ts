import {createHash, randomUUID} from "node:crypto";

export type ThreatIntelligenceAuditEventType =
  | "THREAT_INTEL_PROXY_REQUEST"
  | "THREAT_INTEL_PROXY_COMPLETED"
  | "THREAT_INTEL_PROXY_REJECTED"
  | "THREAT_INTEL_PROXY_TIMEOUT"
  | "THREAT_INTEL_PROXY_RATE_LIMITED"
  | "THREAT_INTEL_PROXY_PROVIDER_ERROR"
  | "THREAT_INTEL_RATE_LIMITED"
  | "THREAT_INTEL_DUPLICATE"
  | "THREAT_INTEL_PROVIDER_QUOTA"
  | "THREAT_INTEL_APP_CHECK_REJECTED"
  | "THREAT_INTEL_AUTH_REJECTED"
  | "THREAT_INTEL_ABUSE_SIGNAL";

export interface ThreatIntelligenceAuditEvent {
  readonly type: ThreatIntelligenceAuditEventType;
  readonly requestId: string;
  readonly userFingerprint?: string;
  readonly indicatorFingerprint?: string;
  readonly operation?: string;
  readonly provider?: "virustotal-premium";
  readonly status?: string;
  readonly durationMs?: number;
  readonly cacheHit?: boolean;
  readonly rateLimitOutcome?: "ALLOWED" | "BLOCKED";
  readonly reason?: string;
  readonly abuseSignal?: "NORMAL" | "WATCH" | "HIGH_ABUSE_SIGNAL";
}

export interface SecurityAuditLogger {
  record(event: ThreatIntelligenceAuditEvent): void;
}

export class NoopSecurityAuditLogger implements SecurityAuditLogger {
  record(_event: ThreatIntelligenceAuditEvent): void {}
}

export function createRequestId(): string {
  return randomUUID();
}

export function safeFingerprint(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 24);
}
