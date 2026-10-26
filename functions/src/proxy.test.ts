import assert from "node:assert/strict";
import {Buffer} from "node:buffer";
import {test} from "node:test";

import express, {Express, Request} from "express";
import request from "supertest";

import {
  BoundedAbuseSignalTracker,
  BoundedBurstProtector,
  BoundedConcurrencyGate,
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
import {RuntimeSecurityConfiguration, VerifiedRequestIdentity} from "./types";
import {validateIndicatorRequest} from "./validation";

const fixtureProviderCredential = ["fixture", "provider", "credential"].join("-");
const validHash = "a".repeat(64);
const validRequest = {
  provider: "virustotal-premium",
  indicatorType: "sha256",
  indicator: validHash,
};

class FakeAuthenticator implements RequestAuthenticator {
  async verify(
    authorization: string | undefined,
    appCheck: string | undefined,
    requireAppCheck: boolean,
  ): Promise<VerifiedRequestIdentity> {
    if (authorization !== "Bearer valid-auth-token") {
      throw new AuthenticationError("AUTHENTICATION");
    }
    if (requireAppCheck && appCheck !== "valid-app-check") {
      throw new AuthenticationError("APP_CHECK");
    }
    return {uid: "citizen-1", appId: appCheck === undefined ? undefined : "app-1"};
  }
}

class FakeTransport implements ProviderTransport {
  readonly calls: Array<{path: string; credential: string}> = [];
  responder: (path: string) => Promise<ProviderTransportResponse> = async () =>
    jsonResponse(stats(0, 0, 1, 3));

  async get(path: string, credential: string): Promise<ProviderTransportResponse> {
    this.calls.push({path, credential});
    return this.responder(path);
  }
}

class MemoryAuditLogger implements SecurityAuditLogger {
  readonly events: ThreatIntelligenceAuditEvent[] = [];

  record(event: ThreatIntelligenceAuditEvent): void {
    this.events.push(event);
  }
}

interface Harness {
  readonly app: Express;
  readonly transport: FakeTransport;
  readonly audit: MemoryAuditLogger;
  readonly runtime: RuntimeSecurityConfiguration;
}

function harness(options: {
  readonly transport?: FakeTransport;
  readonly authenticator?: RequestAuthenticator;
  readonly rateLimiter?: ProxyRateLimiter;
  readonly now?: () => number;
  readonly runtime?: RuntimeSecurityConfiguration;
} = {}): Harness {
  const transport = options.transport ?? new FakeTransport();
  const audit = new MemoryAuditLogger();
  const abuseTracker = new BoundedAbuseSignalTracker();
  const runtime = options.runtime ?? {
    enabled: true,
    requireAppCheck: true,
    providerApiKey: fixtureProviderCredential,
  };
  const service = new ThreatIntelligenceProxyService({
    provider: new VirusTotalProviderClient(transport, async () => {}),
    rateLimiter: options.rateLimiter ?? new InMemoryProxyRateLimiter(),
    cache: new BoundedTtlCache(16, 10 * 60_000),
    burstProtector: new BoundedBurstProtector(() => ({
      userRequests: 1_000,
      userWindowMs: 10_000,
      instanceRequests: 1_000,
      instanceWindowMs: 1_000,
      maxUserEntries: 1_000,
    })),
    concurrencyGate: new BoundedConcurrencyGate(() => 100),
    abuseTracker,
    maxInFlight: () => 100,
    auditLogger: audit,
    now: options.now,
  });
  const handler = createThreatIntelligenceHttpHandler({
    authenticator: options.authenticator ?? new FakeAuthenticator(),
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
  return {app, transport, audit, runtime};
}

function authenticatedPost(app: Express, body: object) {
  return request(app)
    .post("/")
    .set("Authorization", "Bearer valid-auth-token")
    .set("X-Firebase-AppCheck", "valid-app-check")
    .set("Content-Type", "application/json")
    .send(body);
}

test("1. authenticated valid hash request", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, validRequest);
  assert.equal(response.status, 200);
  assert.equal(response.body.operation, "HASH");
  assert.equal(value.transport.calls.length, 1);
});

test("2. unauthenticated request rejected", async () => {
  const value = harness();
  const response = await request(value.app).post("/").send(validRequest);
  assert.equal(response.status, 401);
  assert.equal(value.transport.calls.length, 0);
});

test("3. invalid authentication rejected", async () => {
  const value = harness();
  const response = await request(value.app).post("/")
    .set("Authorization", "Bearer invalid")
    .set("X-Firebase-AppCheck", "valid-app-check")
    .send(validRequest);
  assert.equal(response.status, 401);
});

test("4. invalid hash rejected", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {...validRequest, indicator: "bad"});
  assert.equal(response.status, 400);
  assert.equal(value.transport.calls.length, 0);
});

test("5. valid URL request", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {
    provider: "virustotal-premium",
    indicatorType: "url",
    indicator: "https://example.com/login",
  });
  assert.equal(response.status, 200);
  assert.equal(response.body.operation, "URL");
  assert.match(value.transport.calls[0].path, /^\/api\/v3\/urls\/[A-Za-z0-9_-]+$/);
});

test("6. invalid URL rejected", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {
    provider: "virustotal-premium",
    indicatorType: "url",
    indicator: "file:///etc/passwd",
  });
  assert.equal(response.status, 400);
});

test("7. domain request", async () => {
  const value = harness();
  await authenticatedPost(value.app, {
    provider: "virustotal-premium",
    indicatorType: "domain",
    indicator: "Example.COM",
  }).expect(200);
  assert.equal(value.transport.calls[0].path, "/api/v3/domains/example.com");
});

test("8. IPv4 request", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {
    provider: "virustotal-premium",
    indicatorType: "ip",
    indicator: "8.8.8.8",
  });
  assert.equal(response.body.operation, "IPV4");
  assert.equal(value.transport.calls[0].path, "/api/v3/ip_addresses/8.8.8.8");
});

test("9. IPv6 request", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {
    provider: "virustotal-premium",
    indicatorType: "ip",
    indicator: "2606:4700:4700::1111",
  });
  assert.equal(response.body.operation, "IPV6");
  assert.equal(value.transport.calls.length, 1);
});

test("10. unknown operation rejected", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {
    provider: "virustotal-premium",
    indicatorType: "execute",
    indicator: "whoami",
  });
  assert.equal(response.status, 400);
});

test("11. oversized request rejected", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {
    ...validRequest,
    indicator: "a".repeat(3_000),
  });
  assert.equal(response.status, 413);
});

test("12. raw file payload rejected", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {
    ...validRequest,
    fileBytes: "ZmFrZQ==",
  });
  assert.equal(response.status, 400);
  assert.equal(value.transport.calls.length, 0);
});

test("13. arbitrary outbound URL rejected", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {
    ...validRequest,
    providerUrl: "https://attacker.invalid/",
  });
  assert.equal(response.status, 400);
  assert.equal(value.transport.calls.length, 0);
});

test("14. provider success returns normalized result", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, validRequest);
  assert.equal(response.body.status, "CLEAN");
  assert.deepEqual(Object.keys(response.body).sort(), [
    "cache", "durationMs", "evidence", "operation", "privacy", "providerStatus", "status",
  ]);
});

test("15. provider malicious result", async () => {
  const transport = new FakeTransport();
  transport.responder = async () => jsonResponse(stats(7, 0, 0, 3));
  const response = await authenticatedPost(harness({transport}).app, validRequest);
  assert.equal(response.body.status, "MALICIOUS");
  assert.match(response.body.evidence[0], /7 malicious/);
});

test("16. provider clean result", async () => {
  const response = await authenticatedPost(harness().app, validRequest);
  assert.equal(response.body.status, "CLEAN");
});

test("17. provider timeout", async () => {
  const transport = new FakeTransport();
  transport.responder = async () => {
    const error = new Error("timeout");
    error.name = "HeadersTimeoutError";
    throw error;
  };
  const response = await authenticatedPost(harness({transport}).app, validRequest);
  assert.equal(response.body.status, "TIMEOUT");
  assert.equal(response.body.errorCategory, "TIMEOUT");
});

test("18. provider error", async () => {
  const transport = new FakeTransport();
  transport.responder = async () => { throw new Error("offline"); };
  const response = await authenticatedPost(harness({transport}).app, validRequest);
  assert.equal(response.body.status, "ERROR");
  assert.equal(transport.calls.length, 2);
});

test("19. provider rate limit", async () => {
  const transport = new FakeTransport();
  transport.responder = async () => jsonResponse({}, 429);
  const response = await authenticatedPost(harness({transport}).app, validRequest);
  assert.equal(response.status, 429);
  assert.equal(response.body.errorCategory, "RATE_LIMITED");
});

test("20. malformed provider response", async () => {
  const transport = new FakeTransport();
  transport.responder = async () => ({
    statusCode: 200,
    contentType: "application/json",
    body: Buffer.from("not-json"),
  });
  const response = await authenticatedPost(harness({transport}).app, validRequest);
  assert.equal(response.body.status, "ERROR");
  assert.equal(response.body.errorCategory, "MALFORMED_RESPONSE");
});

test("21. missing provider credential", async () => {
  const value = harness({runtime: {
    enabled: true,
    requireAppCheck: true,
    providerApiKey: "",
  }});
  const response = await authenticatedPost(value.app, validRequest);
  assert.equal(response.body.status, "NOT_CONFIGURED");
  assert.equal(value.transport.calls.length, 0);
});

test("22. disabled provider returns NOT_CONFIGURED", async () => {
  const value = harness({runtime: {
    enabled: false,
    requireAppCheck: true,
    providerApiKey: fixtureProviderCredential,
  }});
  const response = await authenticatedPost(value.app, validRequest);
  assert.equal(response.body.status, "NOT_CONFIGURED");
});

test("23. server request rate limiting", async () => {
  const value = harness({rateLimiter: new InMemoryProxyRateLimiter(() =>
    rateConfiguration({userRequestsPerMinute: 1}))});
  await authenticatedPost(value.app, validRequest).expect(200);
  const response = await authenticatedPost(value.app, {...validRequest, indicator: "b".repeat(64)});
  assert.equal(response.status, 429);
});

test("24. duplicate request suppression", async () => {
  const transport = new FakeTransport();
  let release: (() => void) | undefined;
  transport.responder = () => new Promise((resolve) => {
    release = () => resolve(jsonResponse(stats(0, 0, 1, 1)));
  });
  const value = harness({transport});
  const first = authenticatedPost(value.app, validRequest).then((response) => response);
  const second = authenticatedPost(value.app, validRequest).then((response) => response);
  await waitUntil(() => transport.calls.length === 1);
  release?.();
  await Promise.all([first, second]);
  assert.equal(transport.calls.length, 1);
});

test("25. cache hit", async () => {
  const value = harness();
  await authenticatedPost(value.app, validRequest).expect(200);
  const second = await authenticatedPost(value.app, validRequest);
  assert.equal(second.body.cache.hit, true);
  assert.equal(value.transport.calls.length, 1);
});

test("26. cache expiration", async () => {
  let now = 1_000;
  const value = harness({now: () => now});
  await authenticatedPost(value.app, validRequest).expect(200);
  now += 10 * 60_000 + 1;
  await authenticatedPost(value.app, validRequest).expect(200);
  assert.equal(value.transport.calls.length, 2);
});

test("27. API key absent from logs", async () => {
  const value = harness();
  await authenticatedPost(value.app, validRequest).expect(200);
  assert.doesNotMatch(JSON.stringify(value.audit.events), new RegExp(fixtureProviderCredential));
});

test("28. API key absent from response", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, validRequest);
  assert.doesNotMatch(response.text, new RegExp(fixtureProviderCredential));
});

test("29. Authorization token absent from logs", async () => {
  const value = harness();
  await authenticatedPost(value.app, validRequest).expect(200);
  assert.doesNotMatch(JSON.stringify(value.audit.events), /valid-auth-token/);
});

test("30. no SSRF behavior for private URL", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, {
    provider: "virustotal-premium",
    indicatorType: "url",
    indicator: "http://169.254.169.254/latest/meta-data/",
  });
  assert.equal(response.status, 400);
  assert.equal(value.transport.calls.length, 0);
});

test("31. no arbitrary proxy behavior", async () => {
  assert.throws(() => validateIndicatorRequest({
    provider: "custom-provider",
    indicatorType: "url",
    indicator: "https://example.com",
  }));
});

test("32. response sanitization removes provider fields", async () => {
  const transport = new FakeTransport();
  transport.responder = async () => jsonResponse({
    ...stats(1, 0, 0, 1),
    providerSecret: "must-not-return",
    internalUrl: "https://internal.invalid",
  });
  const response = await authenticatedPost(harness({transport}).app, validRequest);
  assert.doesNotMatch(response.text, /must-not-return|internal\.invalid/);
});

test("33. App Check validation is enforced", async () => {
  const value = harness();
  const response = await request(value.app).post("/")
    .set("Authorization", "Bearer valid-auth-token")
    .send(validRequest);
  assert.equal(response.status, 403);
  assert.equal(response.body.errorCategory, "APP_CHECK");
});

test("34. Web client cannot access provider credential", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, validRequest)
    .set("Origin", "https://cyberuday.in");
  assert.equal(response.headers["access-control-allow-origin"], "https://cyberuday.in");
  assert.equal(response.headers["cache-control"], "no-store");
  assert.doesNotMatch(JSON.stringify(response.headers) + response.text, new RegExp(fixtureProviderCredential));
});

test("disallowed Web origin is rejected without provider access", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, validRequest)
    .set("Origin", "https://attacker.invalid");
  assert.equal(response.status, 403);
  assert.equal(value.transport.calls.length, 0);
});

test("Firebase preview origins are rejected in production", async () => {
  const value = harness();
  const response = await authenticatedPost(value.app, validRequest)
    .set("Origin", "https://cyber-uday-20.web.app");
  assert.equal(response.status, 403);
  assert.equal(value.transport.calls.length, 0);
});

test("multipart request is rejected", async () => {
  const value = harness();
  const response = await request(value.app).post("/")
    .set("Authorization", "Bearer valid-auth-token")
    .set("X-Firebase-AppCheck", "valid-app-check")
    .field("indicator", validHash);
  assert.equal(response.status, 415);
});

test("reserved IPv4 indicators are rejected", () => {
  assert.throws(() => validateIndicatorRequest({
    provider: "virustotal-premium",
    indicatorType: "ip",
    indicator: "192.0.2.1",
  }));
});

test("IPv4-mapped IPv6 indicators are rejected", () => {
  assert.throws(() => validateIndicatorRequest({
    provider: "virustotal-premium",
    indicatorType: "ip",
    indicator: "::ffff:127.0.0.1",
  }));
});

function stats(
  malicious: number,
  suspicious: number,
  harmless: number,
  undetected: number,
): Record<string, unknown> {
  return {
    data: {
      attributes: {
        last_analysis_stats: {malicious, suspicious, harmless, undetected},
      },
    },
  };
}

function jsonResponse(
  body: Record<string, unknown>,
  statusCode = 200,
): ProviderTransportResponse {
  return {
    statusCode,
    contentType: "application/json; charset=utf-8",
    body: Buffer.from(JSON.stringify(body)),
  };
}

async function waitUntil(predicate: () => boolean): Promise<void> {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 1));
  }
  throw new Error("condition-timeout");
}

function rateConfiguration(
  overrides: Partial<ProxyRateLimitConfiguration> = {},
): ProxyRateLimitConfiguration {
  return {...defaultProxyRateLimitConfiguration, ...overrides};
}
