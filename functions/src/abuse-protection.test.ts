import assert from "node:assert/strict";
import {Buffer} from "node:buffer";
import {test} from "node:test";

import express, {Express, Request} from "express";
import request from "supertest";

import {
  BoundedAbuseSignalTracker,
  BoundedBurstProtector,
  BoundedConcurrencyGate,
  BurstProtectionConfiguration,
} from "./abuse-protection";
import {
  SecurityAuditLogger,
  ThreatIntelligenceAuditEvent,
} from "./audit";
import {
  AuthenticationError,
  RequestAuthenticator,
} from "./auth";
import {BoundedTtlCache} from "./cache";
import {createThreatIntelligenceHttpHandler} from "./http-handler";
import {
  ProviderTransport,
  ProviderTransportResponse,
  VirusTotalProviderClient,
} from "./provider";
import {
  defaultProxyRateLimitConfiguration,
  InMemoryProxyRateLimiter,
  ProxyRateLimitConfiguration,
  ProxyRateLimiter,
} from "./rate-limit";
import {ThreatIntelligenceProxyService} from "./service";
import {
  NormalizedIndicatorRequest,
  RuntimeSecurityConfiguration,
  VerifiedRequestIdentity,
} from "./types";
import {validateIndicatorRequest} from "./validation";

const providerCredentialCanary = ["provider", "credential", "canary"].join("-");
const authTokenCanary = ["firebase", "id", "token", "canary"].join("-");
const appCheckTokenCanary = ["app", "check", "token", "canary"].join("-");
const hashA = "a".repeat(64);
const hashB = "b".repeat(64);
const requestA = normalizedHash(hashA);

class TestTransport implements ProviderTransport {
  readonly calls: Array<{path: string; credential: string}> = [];
  responder: (path: string) => Promise<ProviderTransportResponse> = async () =>
    providerJson(0, 0, 2, 2);

  async get(path: string, credential: string): Promise<ProviderTransportResponse> {
    this.calls.push({path, credential});
    return this.responder(path);
  }
}

class TestAuditLogger implements SecurityAuditLogger {
  readonly events: ThreatIntelligenceAuditEvent[] = [];

  record(event: ThreatIntelligenceAuditEvent): void {
    this.events.push(event);
  }
}

class TestAuthenticator implements RequestAuthenticator {
  private readonly consumedAppCheckTokens = new Set<string>();

  constructor(
    private readonly replayProtection = false,
  ) {}

  async verify(
    authorization: string | undefined,
    appCheck: string | undefined,
    requireAppCheck: boolean,
  ): Promise<VerifiedRequestIdentity> {
    if (authorization === "Bearer revoked-auth-token" ||
        authorization === "Bearer invalid-auth-token" ||
        authorization === undefined) {
      throw new AuthenticationError("AUTHENTICATION");
    }
    if (requireAppCheck && (appCheck === undefined || appCheck === "invalid-app-check")) {
      throw new AuthenticationError("APP_CHECK");
    }
    if (this.replayProtection && appCheck !== undefined) {
      if (this.consumedAppCheckTokens.has(appCheck)) {
        throw new AuthenticationError("APP_CHECK");
      }
      this.consumedAppCheckTokens.add(appCheck);
    }
    return {uid: "citizen-1", appId: "cyber-uday-app"};
  }
}

interface TestHarness {
  readonly app: Express;
  readonly service: ThreatIntelligenceProxyService;
  readonly transport: TestTransport;
  readonly audit: TestAuditLogger;
  readonly limiter: InMemoryProxyRateLimiter;
  readonly abuseTracker: BoundedAbuseSignalTracker;
  readonly concurrencyGate: BoundedConcurrencyGate;
  readonly runtime: RuntimeSecurityConfiguration;
}

function createHarness(options: {
  readonly transport?: TestTransport;
  readonly authenticator?: RequestAuthenticator;
  readonly rateConfiguration?: ProxyRateLimitConfiguration;
  readonly rateLimiter?: ProxyRateLimiter;
  readonly burstConfiguration?: BurstProtectionConfiguration;
  readonly concurrency?: number;
  readonly maxInFlight?: number;
  readonly cacheEntries?: number;
  readonly cacheTtlMs?: number;
  readonly now?: () => number;
  readonly runtime?: RuntimeSecurityConfiguration;
  readonly rateStorageEntries?: number;
} = {}): TestHarness {
  const transport = options.transport ?? new TestTransport();
  const audit = new TestAuditLogger();
  const abuseTracker = new BoundedAbuseSignalTracker();
  const limiter = options.rateLimiter instanceof InMemoryProxyRateLimiter ?
    options.rateLimiter :
    new InMemoryProxyRateLimiter(
      () => options.rateConfiguration ?? permissiveRateConfiguration(),
      options.rateStorageEntries ?? 4_096,
    );
  const concurrencyGate = new BoundedConcurrencyGate(
    () => options.concurrency ?? 100,
  );
  const runtime = options.runtime ?? {
    enabled: true,
    requireAppCheck: true,
    providerApiKey: providerCredentialCanary,
  };
  const service = new ThreatIntelligenceProxyService({
    provider: new VirusTotalProviderClient(transport, async () => {}),
    rateLimiter: options.rateLimiter ?? limiter,
    cache: new BoundedTtlCache(
      options.cacheEntries ?? 256,
      options.cacheTtlMs ?? 10 * 60_000,
    ),
    burstProtector: new BoundedBurstProtector(() =>
      options.burstConfiguration ?? permissiveBurstConfiguration()),
    concurrencyGate,
    abuseTracker,
    maxInFlight: () => options.maxInFlight ?? 64,
    auditLogger: audit,
    now: options.now,
  });
  const handler = createThreatIntelligenceHttpHandler({
    authenticator: options.authenticator ?? new TestAuthenticator(),
    service,
    auditLogger: audit,
    abuseTracker,
    allowedOrigins: new Set(["https://cyberuday.in"]),
    runtimeConfiguration: () => runtime,
  });
  const app = express();
  app.use(express.json({
    limit: "32kb",
    verify: (req: Request, _res, body) => {
      (req as Request & {rawBody?: Buffer}).rawBody = Buffer.from(body);
    },
  }));
  app.all("/", handler);
  return {app, service, transport, audit, limiter, abuseTracker, concurrencyGate, runtime};
}

test("1. per-user minute limit", async () => {
  const limiter = rateLimiter({userRequestsPerMinute: 1});
  assert.equal((await consumeRequest(limiter, requestA, 0)).allowed, true);
  const decision = await consumeRequest(limiter, normalizedHash(hashB), 1);
  assert.deepEqual(decision, {allowed: false, reason: "USER_MINUTE"});
});

test("2. per-user hourly limit", async () => {
  const limiter = rateLimiter({userRequestsPerHour: 1});
  await consumeRequest(limiter, requestA, 0);
  const decision = await consumeRequest(limiter, normalizedHash(hashB), 60_001);
  assert.deepEqual(decision, {allowed: false, reason: "USER_HOUR"});
});

test("3. per-user daily limit", async () => {
  const limiter = rateLimiter({userRequestsPerDay: 1});
  await consumeRequest(limiter, requestA, 0);
  const decision = await consumeRequest(limiter, normalizedHash(hashB), 60 * 60_000 + 1);
  assert.deepEqual(decision, {allowed: false, reason: "USER_DAY"});
});

test("4. operation-specific limit", async () => {
  const limiter = rateLimiter({
    userOperationRequestsPerMinute: operationLimits({HASH: 1}),
  });
  await consumeRequest(limiter, requestA, 0);
  const decision = await consumeRequest(limiter, normalizedHash(hashB), 1);
  assert.deepEqual(decision, {allowed: false, reason: "USER_OPERATION"});
});

test("5. duplicate request uses cache", async () => {
  const value = createHarness();
  await lookup(value, "request-1", requestA);
  const second = await lookup(value, "request-2", requestA);
  assert.equal(second.response.cache.hit, true);
  assert.equal(value.transport.calls.length, 1);
  assert.ok(value.audit.events.some((event) => event.type === "THREAT_INTEL_DUPLICATE"));
});

test("6. concurrent duplicate request reuses one lookup", async () => {
  const transport = new TestTransport();
  let release: (() => void) | undefined;
  transport.responder = () => new Promise((resolve) => {
    release = () => resolve(providerJson(0, 0, 1, 1));
  });
  const value = createHarness({transport});
  const first = lookup(value, "request-1", requestA);
  const second = lookup(value, "request-2", requestA);
  await waitUntil(() => transport.calls.length === 1);
  release?.();
  await Promise.all([first, second]);
  assert.equal(transport.calls.length, 1);
});

test("7. cache hit avoids rate-limit storage writes", async () => {
  const value = createHarness();
  await lookup(value, "request-1", requestA);
  const storageSize = value.limiter.memoryStorage.size;
  await lookup(value, "request-2", requestA);
  assert.equal(value.limiter.memoryStorage.size, storageSize);
  assert.equal(value.transport.calls.length, 1);
});

test("8. cache expiration permits a fresh provider lookup", async () => {
  let now = 0;
  const value = createHarness({now: () => now, cacheTtlMs: 100});
  await lookup(value, "request-1", requestA);
  now = 101;
  await lookup(value, "request-2", requestA);
  assert.equal(value.transport.calls.length, 2);
});

test("9. provider quota exhausted", async () => {
  const limiter = rateLimiter({providerRequestsPerMinute: 1});
  assert.equal((await limiter.consumeProvider("HASH", 0)).allowed, true);
  const decision = await limiter.consumeProvider("URL", 1);
  assert.deepEqual(decision, {allowed: false, reason: "PROVIDER_MINUTE"});
});

test("10. burst protection", () => {
  const burst = new BoundedBurstProtector(() => ({
    userRequests: 1,
    userWindowMs: 10_000,
    instanceRequests: 10,
    instanceWindowMs: 1_000,
    maxUserEntries: 10,
  }));
  assert.equal(burst.consume(identity(), 0).allowed, true);
  assert.deepEqual(burst.consume(identity(), 1), {
    allowed: false,
    reason: "USER_BURST",
  });
});

test("11. concurrent request limit", async () => {
  const transport = new TestTransport();
  let release: (() => void) | undefined;
  transport.responder = () => new Promise((resolve) => {
    release = () => resolve(providerJson(0, 0, 1, 1));
  });
  const value = createHarness({transport, concurrency: 1});
  const first = lookup(value, "request-1", requestA);
  await waitUntil(() => transport.calls.length === 1);
  const second = await lookup(value, "request-2", normalizedHash(hashB));
  assert.equal(second.statusCode, 429);
  release?.();
  await first;
  assert.equal(value.concurrencyGate.activeCount, 0);
});

test("12. invalid App Check is rejected before provider access", async () => {
  const value = createHarness();
  const response = await post(value.app, validBody(), {
    appCheck: "invalid-app-check",
  });
  assert.equal(response.status, 403);
  assert.equal(value.transport.calls.length, 0);
});

test("13. missing App Check is rejected", async () => {
  const value = createHarness();
  const response = await post(value.app, validBody(), {appCheck: undefined});
  assert.equal(response.status, 403);
  assert.equal(value.transport.calls.length, 0);
});

test("14. App Check replay is rejected", async () => {
  const value = createHarness({authenticator: new TestAuthenticator(true)});
  await post(value.app, validBody()).expect(200);
  const replay = await post(value.app, validBody());
  assert.equal(replay.status, 403);
  assert.equal(value.transport.calls.length, 1);
});

test("15. unauthenticated request does not consume provider quota", async () => {
  const value = createHarness();
  const response = await request(value.app).post("/").send(validBody());
  assert.equal(response.status, 401);
  assert.equal(value.transport.calls.length, 0);
});

test("16. revoked authentication is rejected", async () => {
  const value = createHarness();
  const response = await post(value.app, validBody(), {
    authorization: "Bearer revoked-auth-token",
  });
  assert.equal(response.status, 401);
  assert.equal(value.transport.calls.length, 0);
});

test("17. client userId spoof attempt is rejected", async () => {
  const value = createHarness();
  const response = await post(value.app, {...validBody(), userId: "admin"});
  assert.equal(response.status, 400);
  assert.equal(value.transport.calls.length, 0);
});

test("18. hash normalization is canonical and whitespace is rejected", () => {
  const normalized = validateIndicatorRequest({...validBody(), indicator: "A".repeat(64)});
  assert.equal(normalized.indicator, hashA);
  assert.throws(() => validateIndicatorRequest({...validBody(), indicator: ` ${hashA}`}));
});

test("19. URL normalization deduplicates equivalent representations", async () => {
  const first = validateIndicatorRequest({
    provider: "virustotal-premium",
    indicatorType: "url",
    indicator: "HTTPS://Example.COM:443/a/../login",
  });
  const second = validateIndicatorRequest({
    provider: "virustotal-premium",
    indicatorType: "url",
    indicator: "https://example.com/login",
  });
  assert.equal(first.indicator, second.indicator);
  const value = createHarness();
  await lookup(value, "request-1", first);
  await lookup(value, "request-2", second);
  assert.equal(value.transport.calls.length, 1);
});

test("20. domain normalization deduplicates casing", () => {
  const upper = validateIndicatorRequest({
    provider: "virustotal-premium",
    indicatorType: "domain",
    indicator: "Example.COM",
  });
  const lower = validateIndicatorRequest({
    provider: "virustotal-premium",
    indicatorType: "domain",
    indicator: "example.com",
  });
  assert.equal(upper.indicator, lower.indicator);
});

test("21. IPv6 normalization produces one canonical indicator", () => {
  const expanded = validateIndicatorRequest({
    provider: "virustotal-premium",
    indicatorType: "ip",
    indicator: "2606:4700:4700:0:0:0:0:1111",
  });
  const compressed = validateIndicatorRequest({
    provider: "virustotal-premium",
    indicatorType: "ip",
    indicator: "2606:4700:4700::1111",
  });
  assert.equal(expanded.indicator, compressed.indicator);
});

test("22. atomic rate-limit transaction contract prevents races", async () => {
  const limiter = rateLimiter({userRequestsPerMinute: 1});
  const decisions = await Promise.all([
    consumeRequest(limiter, requestA, 0),
    consumeRequest(limiter, normalizedHash(hashB), 0),
  ]);
  assert.equal(decisions.filter((item) => item.allowed).length, 1);
});

test("23. expired rate-limit records are reusable", async () => {
  const limiter = new InMemoryProxyRateLimiter(
    () => permissiveRateConfiguration(),
    3,
  );
  assert.equal((await consumeRequest(limiter, requestA, 0)).allowed, true);
  assert.equal((await limiter.consumeRequest(
    identity("citizen-2"),
    normalizedHash(hashB),
    49 * 60 * 60_000,
  )).allowed, true);
  assert.equal(limiter.memoryStorage.size, 3);
});

test("24. bounded rate-limit storage fails closed", async () => {
  const limiter = new InMemoryProxyRateLimiter(
    () => permissiveRateConfiguration(),
    3,
  );
  await consumeRequest(limiter, requestA, 0);
  const decision = await limiter.consumeRequest(
    identity("citizen-2"),
    validateIndicatorRequest({
      provider: "virustotal-premium",
      indicatorType: "url",
      indicator: "https://example.com/second",
    }),
    1,
  );
  assert.deepEqual(decision, {allowed: false, reason: "STORAGE_CAPACITY"});
  assert.equal(limiter.memoryStorage.size, 3);
});

test("25. no raw file is accepted", async () => {
  const value = createHarness();
  const response = await post(value.app, {...validBody(), fileBytes: "AA=="});
  assert.equal(response.status, 400);
  assert.equal(value.transport.calls.length, 0);
});

test("26. no arbitrary proxy URL is accepted", async () => {
  const value = createHarness();
  const response = await post(value.app, {
    ...validBody(),
    providerUrl: "https://attacker.invalid",
  });
  assert.equal(response.status, 400);
  assert.equal(value.transport.calls.length, 0);
});

test("27. provider timeout releases concurrency and in-flight state", async () => {
  const transport = new TestTransport();
  transport.responder = async () => {
    const error = new Error("timeout");
    error.name = "HeadersTimeoutError";
    throw error;
  };
  const value = createHarness({transport, concurrency: 1, maxInFlight: 1});
  const result = await lookup(value, "request-1", requestA);
  assert.equal(result.statusCode, 504);
  assert.equal(value.concurrencyGate.activeCount, 0);
  assert.equal(value.service.inFlightCount, 0);
});

test("28. provider failure releases concurrency and in-flight state", async () => {
  const transport = new TestTransport();
  transport.responder = async () => { throw new Error("offline"); };
  const value = createHarness({transport, concurrency: 1, maxInFlight: 1});
  const result = await lookup(value, "request-1", requestA);
  assert.equal(result.statusCode, 503);
  assert.equal(value.concurrencyGate.activeCount, 0);
  assert.equal(value.service.inFlightCount, 0);
});

test("29. abuse signal generation never bans automatically", () => {
  const tracker = new BoundedAbuseSignalTracker(10, 1_000, 2, 4, 3, 5);
  assert.equal(tracker.observe({kind: "DUPLICATE", scope: "safe"}, 0), "NORMAL");
  assert.equal(tracker.observe({kind: "DUPLICATE", scope: "safe"}, 1), "WATCH");
  assert.equal(tracker.observe({kind: "DUPLICATE", scope: "safe"}, 2), "WATCH");
  assert.equal(tracker.observe({kind: "DUPLICATE", scope: "safe"}, 3), "HIGH_ABUSE_SIGNAL");
});

test("30. safe 429 response hides quota internals", async () => {
  const value = createHarness({
    burstConfiguration: {
      userRequests: 1,
      userWindowMs: 10_000,
      instanceRequests: 10,
      instanceWindowMs: 1_000,
      maxUserEntries: 10,
    },
  });
  await post(value.app, validBody()).expect(200);
  const response = await post(value.app, validBody());
  assert.equal(response.status, 429);
  assert.equal(response.body.errorCategory, "RATE_LIMITED");
  assert.doesNotMatch(response.text, /Firestore|240|quota remaining/i);
});

test("31. safe 503 response for unavailable provider", async () => {
  const value = createHarness({runtime: {
    enabled: false,
    requireAppCheck: true,
    providerApiKey: "",
  }});
  const response = await post(value.app, validBody());
  assert.equal(response.status, 503);
  assert.equal(response.body.status, "NOT_CONFIGURED");
  assert.doesNotMatch(response.text, /stack|firebase|internal/i);
});

test("32. safe 504 response for provider timeout", async () => {
  const transport = new TestTransport();
  transport.responder = async () => {
    const error = new Error("timeout");
    error.name = "HeadersTimeoutError";
    throw error;
  };
  const response = await post(createHarness({transport}).app, validBody());
  assert.equal(response.status, 504);
  assert.equal(response.body.status, "TIMEOUT");
  assert.doesNotMatch(response.text, /HeadersTimeoutError|stack/i);
});

test("33. provider credential is never logged", async () => {
  const value = createHarness();
  await post(value.app, validBody());
  assert.doesNotMatch(JSON.stringify(value.audit.events), new RegExp(providerCredentialCanary));
});

test("34. App Check token is never logged", async () => {
  const value = createHarness();
  await post(value.app, validBody(), {appCheck: appCheckTokenCanary});
  assert.doesNotMatch(JSON.stringify(value.audit.events), new RegExp(appCheckTokenCanary));
});

test("35. Firebase ID token is never logged", async () => {
  const value = createHarness();
  await post(value.app, validBody(), {authorization: `Bearer ${authTokenCanary}`});
  assert.doesNotMatch(JSON.stringify(value.audit.events), new RegExp(authTokenCanary));
});

test("36. malformed provider response cannot poison cache", async () => {
  const transport = new TestTransport();
  transport.responder = async () => ({
    statusCode: 200,
    contentType: "application/json",
    body: Buffer.from("not-json"),
  });
  const value = createHarness({transport});
  await lookup(value, "request-1", requestA);
  await lookup(value, "request-2", requestA);
  assert.equal(transport.calls.length, 2);
});

test("37. in-flight operations are bounded without a queue", async () => {
  const transport = new TestTransport();
  let release: (() => void) | undefined;
  transport.responder = () => new Promise((resolve) => {
    release = () => resolve(providerJson(0, 0, 1, 1));
  });
  const value = createHarness({transport, maxInFlight: 1});
  const first = lookup(value, "request-1", requestA);
  await waitUntil(() => transport.calls.length === 1);
  const second = await lookup(value, "request-2", normalizedHash(hashB));
  assert.equal(second.statusCode, 429);
  assert.equal(value.service.inFlightCount, 1);
  release?.();
  await first;
  assert.equal(value.service.inFlightCount, 0);
});

test("38. global provider quota protects across users", async () => {
  const limiter = rateLimiter({providerRequestsPerHour: 1});
  assert.equal((await limiter.consumeProvider("HASH", 0)).allowed, true);
  const decision = await limiter.consumeProvider("DOMAIN", 60_001);
  assert.deepEqual(decision, {allowed: false, reason: "PROVIDER_HOUR"});
});

test("39. multi-account abuse signal uses privacy-safe actor correlation", () => {
  const tracker = new BoundedAbuseSignalTracker();
  const observation = {kind: "INDICATOR_ACTIVITY" as const, scope: "fingerprint"};
  assert.equal(tracker.observe({...observation, actor: "user-1"}, 0), "NORMAL");
  assert.equal(tracker.observe({...observation, actor: "user-2"}, 1), "NORMAL");
  assert.equal(tracker.observe({...observation, actor: "user-3"}, 2), "WATCH");
  assert.equal(tracker.size, 1);
});

test("40. local analysis boundary remains available when intelligence is unavailable", async () => {
  const value = createHarness({runtime: {
    enabled: false,
    requireAppCheck: true,
    providerApiKey: "",
  }});
  const result = await lookup(value, "request-1", requestA);
  assert.equal(result.response.status, "NOT_CONFIGURED");
  assert.match(result.response.privacy.privacyMode, /INDICATOR_ONLY/);
  assert.equal(value.transport.calls.length, 0);
});

test("41. provider retry is re-budgeted before every outbound attempt", async () => {
  const transport = new TestTransport();
  transport.responder = async () => { throw new Error("retryable-offline"); };
  const value = createHarness({
    transport,
    rateConfiguration: {
      ...permissiveRateConfiguration(),
      providerRequestsPerMinute: 1,
    },
  });
  const result = await lookup(value, "request-1", requestA);
  assert.equal(result.statusCode, 429);
  assert.equal(transport.calls.length, 1);
  assert.ok(value.audit.events.some((event) =>
    event.type === "THREAT_INTEL_PROVIDER_QUOTA"));
});

test("42. concurrent equivalent requests across users share one provider lookup", async () => {
  const transport = new TestTransport();
  let release: (() => void) | undefined;
  transport.responder = () => new Promise((resolve) => {
    release = () => resolve(providerJson(0, 0, 1, 1));
  });
  const value = createHarness({transport});
  const first = lookup(value, "request-1", requestA, identity("citizen-1"));
  await waitUntil(() => transport.calls.length === 1);
  const second = lookup(value, "request-2", requestA, identity("citizen-2"));
  release?.();
  await Promise.all([first, second]);
  assert.equal(transport.calls.length, 1);
});

function rateLimiter(
  overrides: Partial<ProxyRateLimitConfiguration>,
): InMemoryProxyRateLimiter {
  return new InMemoryProxyRateLimiter(() => ({
    ...permissiveRateConfiguration(),
    ...overrides,
  }));
}

function permissiveRateConfiguration(): ProxyRateLimitConfiguration {
  return {
    ...defaultProxyRateLimitConfiguration,
    userRequestsPerMinute: 10_000,
    userRequestsPerHour: 10_000,
    userRequestsPerDay: 10_000,
    userOperationRequestsPerMinute: operationLimits(),
    operationRequestsPerMinute: operationLimits(),
    indicatorRequestsPerTenMinutes: 10_000,
    providerRequestsPerMinute: 10_000,
    providerRequestsPerHour: 10_000,
    providerOperationRequestsPerMinute: operationLimits(),
  };
}

function operationLimits(
  overrides: Partial<ProxyRateLimitConfiguration["operationRequestsPerMinute"]> = {},
): ProxyRateLimitConfiguration["operationRequestsPerMinute"] {
  return {
    HASH: 10_000,
    URL: 10_000,
    DOMAIN: 10_000,
    IPV4: 10_000,
    IPV6: 10_000,
    ...overrides,
  };
}

function permissiveBurstConfiguration(): BurstProtectionConfiguration {
  return {
    userRequests: 10_000,
    userWindowMs: 10_000,
    instanceRequests: 10_000,
    instanceWindowMs: 1_000,
    maxUserEntries: 1_000,
  };
}

function consumeRequest(
  limiter: ProxyRateLimiter,
  indicator: NormalizedIndicatorRequest,
  nowMs: number,
) {
  return limiter.consumeRequest(identity(), indicator, nowMs);
}

function lookup(
  value: TestHarness,
  requestId: string,
  indicator: NormalizedIndicatorRequest,
  requestIdentity: VerifiedRequestIdentity = identity(),
) {
  return value.service.lookup(requestId, requestIdentity, indicator, value.runtime);
}

function identity(uid = "citizen-1"): VerifiedRequestIdentity {
  return {uid, appId: "cyber-uday-app"};
}

function normalizedHash(hash: string): NormalizedIndicatorRequest {
  return {
    operation: "HASH",
    indicator: hash,
    transmittedValueType: "SHA256",
  };
}

function validBody() {
  return {
    provider: "virustotal-premium",
    indicatorType: "sha256",
    indicator: hashA,
  };
}

function post(
  app: Express,
  body: object,
  headers: {
    readonly authorization?: string;
    readonly appCheck?: string;
  } = {},
) {
  const pending = request(app)
    .post("/")
    .set("Authorization", headers.authorization ?? `Bearer ${authTokenCanary}`)
    .set("Content-Type", "application/json");
  if (headers.appCheck !== undefined || !("appCheck" in headers)) {
    pending.set("X-Firebase-AppCheck", headers.appCheck ?? appCheckTokenCanary);
  }
  return pending.send(body);
}

function providerJson(
  malicious: number,
  suspicious: number,
  harmless: number,
  undetected: number,
): ProviderTransportResponse {
  return {
    statusCode: 200,
    contentType: "application/json",
    body: Buffer.from(JSON.stringify({
      data: {
        attributes: {
          last_analysis_stats: {malicious, suspicious, harmless, undetected},
        },
      },
    })),
  };
}

async function waitUntil(predicate: () => boolean): Promise<void> {
  for (let attempt = 0; attempt < 200; attempt += 1) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 1));
  }
  throw new Error("condition-timeout");
}
