import {createHash} from "node:crypto";

import {
  BoundedAbuseSignalTracker,
  BoundedBurstProtector,
  BoundedConcurrencyGate,
} from "./abuse-protection";
import {safeFingerprint, SecurityAuditLogger} from "./audit";
import {BoundedTtlCache} from "./cache";
import {VirusTotalProviderClient} from "./provider";
import {ProxyRateLimiter} from "./rate-limit";
import {
  NormalizedIndicatorRequest,
  ProviderLookupResult,
  RuntimeSecurityConfiguration,
  ThreatIntelligenceProxyResponse,
  VerifiedRequestIdentity,
} from "./types";

export interface ThreatIntelligenceServiceDependencies {
  readonly provider: VirusTotalProviderClient;
  readonly rateLimiter: ProxyRateLimiter;
  readonly cache: BoundedTtlCache<ProviderLookupResult>;
  readonly burstProtector: BoundedBurstProtector;
  readonly concurrencyGate: BoundedConcurrencyGate;
  readonly abuseTracker: BoundedAbuseSignalTracker;
  readonly maxInFlight: () => number;
  readonly auditLogger: SecurityAuditLogger;
  readonly now?: () => number;
}

export interface ThreatIntelligenceServiceResult {
  readonly response: ThreatIntelligenceProxyResponse;
  readonly rateLimited: boolean;
  readonly statusCode: 200 | 429 | 503 | 504;
}

interface InternalLookupResult {
  readonly providerResult: ProviderLookupResult;
  readonly limitReason?: string;
}

export class ThreatIntelligenceProxyService {
  private readonly inFlight = new Map<string, Promise<InternalLookupResult>>();
  private readonly now: () => number;

  constructor(private readonly dependencies: ThreatIntelligenceServiceDependencies) {
    this.now = dependencies.now ?? Date.now;
  }

  async lookup(
    requestId: string,
    identity: VerifiedRequestIdentity,
    request: NormalizedIndicatorRequest,
    runtime: RuntimeSecurityConfiguration,
  ): Promise<ThreatIntelligenceServiceResult> {
    const startedAt = this.now();
    this.observeAbuse("INDICATOR_ACTIVITY", requestId, identity, request);

    const burst = this.dependencies.burstProtector.consume(identity, startedAt);
    if (!burst.allowed) {
      this.observeAbuse("BURST", requestId, identity, request, burst.reason);
      this.recordRateLimit(requestId, identity, request, burst.reason ?? "BURST");
      return this.finish(
        request,
        rateLimitedResult(),
        startedAt,
        false,
      );
    }

    if (!runtime.enabled || runtime.providerApiKey.length === 0) {
      return this.complete(
        requestId,
        identity,
        request,
        {
          status: "NOT_CONFIGURED",
          evidence: [],
          providerStatus: "NOT_CONFIGURED",
          errorCategory: "NOT_CONFIGURED",
        },
        startedAt,
        false,
      );
    }

    const providerKey = cacheKey(request);
    const cached = this.dependencies.cache.get(providerKey, this.now());
    if (cached !== undefined) {
      this.recordDuplicate(requestId, identity, request, "CACHE");
      this.observeAbuse("DUPLICATE", requestId, identity, request, "CACHE");
      return this.complete(
        requestId,
        identity,
        request,
        cached,
        startedAt,
        true,
      );
    }

    // Reputation results are indicator-only and contain no user-specific data,
    // so one in-flight provider call can safely serve concurrent users.
    const inFlightKey = providerKey;
    let lookup = this.inFlight.get(inFlightKey);
    if (lookup !== undefined) {
      this.recordDuplicate(requestId, identity, request, "IN_FLIGHT");
      this.observeAbuse("DUPLICATE", requestId, identity, request, "IN_FLIGHT");
    } else {
      const maxInFlight = this.dependencies.maxInFlight();
      if (!Number.isSafeInteger(maxInFlight) || maxInFlight <= 0) {
        throw new Error("invalid-in-flight-limit");
      }
      if (this.inFlight.size >= maxInFlight) {
        this.observeAbuse("BURST", requestId, identity, request, "IN_FLIGHT_CAPACITY");
        this.recordRateLimit(requestId, identity, request, "IN_FLIGHT_CAPACITY");
        return this.finish(request, rateLimitedResult(), startedAt, false);
      }
      lookup = this.lookupProvider(
        requestId,
        identity,
        request,
        runtime.providerApiKey,
        providerKey,
      );
      this.inFlight.set(inFlightKey, lookup);
    }

    let internal: InternalLookupResult;
    try {
      internal = await lookup;
    } finally {
      if (this.inFlight.get(inFlightKey) === lookup) this.inFlight.delete(inFlightKey);
    }
    return this.complete(
      requestId,
      identity,
      request,
      internal.providerResult,
      startedAt,
      false,
      internal.limitReason,
    );
  }

  get inFlightCount(): number {
    return this.inFlight.size;
  }

  private async lookupProvider(
    requestId: string,
    identity: VerifiedRequestIdentity,
    request: NormalizedIndicatorRequest,
    apiKey: string,
    providerKey: string,
  ): Promise<InternalLookupResult> {
    const requestLimit = await this.dependencies.rateLimiter.consumeRequest(
      identity,
      request,
      this.now(),
    );
    if (!requestLimit.allowed) {
      const reason = requestLimit.reason ?? "REQUEST_RATE_LIMIT";
      this.recordRateLimit(requestId, identity, request, reason);
      this.observeAbuse("RATE_LIMIT", requestId, identity, request, reason);
      return {providerResult: rateLimitedResult(), limitReason: reason};
    }

    const release = this.dependencies.concurrencyGate.tryAcquire();
    if (release === undefined) {
      this.recordRateLimit(requestId, identity, request, "PROVIDER_CONCURRENCY");
      this.observeAbuse(
        "BURST",
        requestId,
        identity,
        request,
        "PROVIDER_CONCURRENCY",
      );
      return {
        providerResult: rateLimitedResult(),
        limitReason: "PROVIDER_CONCURRENCY",
      };
    }

    try {
      let providerLimitReason: string | undefined;
      const result = await this.dependencies.provider.lookup(
        request,
        apiKey,
        async () => {
          const providerLimit = await this.dependencies.rateLimiter.consumeProvider(
            request.operation,
            this.now(),
          );
          if (providerLimit.allowed) return true;
          providerLimitReason = providerLimit.reason ?? "PROVIDER_QUOTA";
          this.dependencies.auditLogger.record({
            type: "THREAT_INTEL_PROVIDER_QUOTA",
            requestId,
            userFingerprint: safeFingerprint(identity.uid),
            indicatorFingerprint: safeFingerprint(request.indicator),
            operation: request.operation,
            provider: "virustotal-premium",
            status: "BLOCKED",
            reason: providerLimitReason,
          });
          this.observeAbuse(
            "PROVIDER_QUOTA",
            requestId,
            identity,
            request,
            providerLimitReason,
          );
          return false;
        },
      );
      if (isCacheable(result)) {
        this.dependencies.cache.set(providerKey, result, this.now());
      }
      if (result.errorCategory === "RATE_LIMITED") {
        this.dependencies.auditLogger.record({
          type: "THREAT_INTEL_PROVIDER_QUOTA",
          requestId,
          userFingerprint: safeFingerprint(identity.uid),
          indicatorFingerprint: safeFingerprint(request.indicator),
          operation: request.operation,
          provider: "virustotal-premium",
          status: "BLOCKED",
          reason: "PROVIDER_RESPONSE",
        });
      }
      return {providerResult: result, limitReason: providerLimitReason};
    } finally {
      release();
    }
  }

  private complete(
    requestId: string,
    identity: VerifiedRequestIdentity,
    request: NormalizedIndicatorRequest,
    providerResult: ProviderLookupResult,
    startedAt: number,
    cacheHit: boolean,
    limitReason?: string,
  ): ThreatIntelligenceServiceResult {
    const response = createResponse(
      request,
      providerResult,
      this.now() - startedAt,
      cacheHit,
    );
    this.dependencies.auditLogger.record({
      type: providerResult.status === "TIMEOUT" ?
        "THREAT_INTEL_PROXY_TIMEOUT" :
        providerResult.status === "ERROR" &&
          providerResult.errorCategory !== "RATE_LIMITED" ?
          "THREAT_INTEL_PROXY_PROVIDER_ERROR" :
          "THREAT_INTEL_PROXY_COMPLETED",
      requestId,
      userFingerprint: safeFingerprint(identity.uid),
      indicatorFingerprint: safeFingerprint(request.indicator),
      operation: request.operation,
      provider: "virustotal-premium",
      status: providerResult.status,
      durationMs: response.durationMs,
      cacheHit,
      rateLimitOutcome: providerResult.errorCategory === "RATE_LIMITED" ?
        "BLOCKED" : "ALLOWED",
      ...(limitReason === undefined ? {} : {reason: limitReason}),
    });
    return {
      response,
      rateLimited: providerResult.errorCategory === "RATE_LIMITED",
      statusCode: statusCodeFor(providerResult),
    };
  }

  private finish(
    request: NormalizedIndicatorRequest,
    providerResult: ProviderLookupResult,
    startedAt: number,
    cacheHit: boolean,
  ): ThreatIntelligenceServiceResult {
    return {
      response: createResponse(
        request,
        providerResult,
        this.now() - startedAt,
        cacheHit,
      ),
      rateLimited: providerResult.errorCategory === "RATE_LIMITED",
      statusCode: statusCodeFor(providerResult),
    };
  }

  private recordRateLimit(
    requestId: string,
    identity: VerifiedRequestIdentity,
    request: NormalizedIndicatorRequest,
    reason: string,
  ): void {
    this.dependencies.auditLogger.record({
      type: "THREAT_INTEL_RATE_LIMITED",
      requestId,
      userFingerprint: safeFingerprint(identity.uid),
      indicatorFingerprint: safeFingerprint(request.indicator),
      operation: request.operation,
      provider: "virustotal-premium",
      status: "BLOCKED",
      rateLimitOutcome: "BLOCKED",
      reason,
    });
  }

  private recordDuplicate(
    requestId: string,
    identity: VerifiedRequestIdentity,
    request: NormalizedIndicatorRequest,
    reason: "CACHE" | "IN_FLIGHT",
  ): void {
    this.dependencies.auditLogger.record({
      type: "THREAT_INTEL_DUPLICATE",
      requestId,
      userFingerprint: safeFingerprint(identity.uid),
      indicatorFingerprint: safeFingerprint(request.indicator),
      operation: request.operation,
      provider: "virustotal-premium",
      reason,
    });
  }

  private observeAbuse(
    kind: Parameters<BoundedAbuseSignalTracker["observe"]>[0]["kind"],
    requestId: string,
    identity: VerifiedRequestIdentity,
    request: NormalizedIndicatorRequest,
    reason: string = kind,
  ): void {
    const indicatorFingerprint = safeFingerprint(request.indicator);
    const appFingerprint = safeFingerprint(identity.appId ?? "missing-app-id");
    const level = this.dependencies.abuseTracker.observe({
      kind,
      scope: `${appFingerprint}:${request.operation}:${indicatorFingerprint}:${reason}`,
      actor: identity.uid,
    }, this.now());
    if (level === "NORMAL") return;
    this.dependencies.auditLogger.record({
      type: "THREAT_INTEL_ABUSE_SIGNAL",
      requestId,
      userFingerprint: safeFingerprint(identity.uid),
      indicatorFingerprint,
      operation: request.operation,
      status: level,
      reason,
      abuseSignal: level,
    });
  }
}

function createResponse(
  request: NormalizedIndicatorRequest,
  result: ProviderLookupResult,
  durationMs: number,
  cacheHit: boolean,
): ThreatIntelligenceProxyResponse {
  return {
    operation: request.operation,
    status: result.status,
    evidence: result.evidence.slice(0, 10).map((item) => item.slice(0, 240)),
    providerStatus: result.providerStatus,
    durationMs: Math.max(0, Math.round(durationMs)),
    cache: {hit: cacheHit},
    privacy: {
      rawContentTransmitted: false,
      transmittedValueType: request.transmittedValueType,
      privacyMode: "INDICATOR_ONLY",
    },
    ...(result.errorCategory === undefined ? {} : {errorCategory: result.errorCategory}),
  };
}

function statusCodeFor(
  result: ProviderLookupResult,
): 200 | 429 | 503 | 504 {
  if (result.errorCategory === "RATE_LIMITED") return 429;
  if (result.status === "TIMEOUT") return 504;
  if (result.status === "ERROR" || result.status === "NOT_CONFIGURED") return 503;
  return 200;
}

function isCacheable(result: ProviderLookupResult): boolean {
  return result.status === "MALICIOUS" || result.status === "SUSPICIOUS" ||
    result.status === "CLEAN" || result.status === "UNKNOWN";
}

function rateLimitedResult(): ProviderLookupResult {
  return {
    status: "ERROR",
    evidence: ["The request rate limit was reached."],
    providerStatus: "UNAVAILABLE",
    errorCategory: "RATE_LIMITED",
  };
}

function cacheKey(request: NormalizedIndicatorRequest): string {
  return createHash("sha256")
    .update(`virustotal-premium\u0000${request.operation}\u0000${request.indicator}`)
    .digest("hex");
}
