import {createHash} from "node:crypto";

import {Firestore, Timestamp} from "firebase-admin/firestore";

import {
  NormalizedIndicatorRequest,
  ThreatIntelligenceOperation,
  VerifiedRequestIdentity,
} from "./types";

export type RateLimitReason =
  | "USER_MINUTE"
  | "USER_HOUR"
  | "USER_DAY"
  | "USER_OPERATION"
  | "OPERATION"
  | "INDICATOR"
  | "PROVIDER_MINUTE"
  | "PROVIDER_HOUR"
  | "PROVIDER_OPERATION"
  | "STORAGE_CAPACITY";

export interface RateLimitDecision {
  readonly allowed: boolean;
  readonly reason?: RateLimitReason;
}

export interface ProxyRateLimitConfiguration {
  readonly userRequestsPerMinute: number;
  readonly userRequestsPerHour: number;
  readonly userRequestsPerDay: number;
  readonly userOperationRequestsPerMinute:
    Readonly<Record<ThreatIntelligenceOperation, number>>;
  readonly operationRequestsPerMinute:
    Readonly<Record<ThreatIntelligenceOperation, number>>;
  readonly indicatorRequestsPerTenMinutes: number;
  readonly providerRequestsPerMinute: number;
  readonly providerRequestsPerHour: number;
  readonly providerOperationRequestsPerMinute:
    Readonly<Record<ThreatIntelligenceOperation, number>>;
}

export const defaultProxyRateLimitConfiguration: ProxyRateLimitConfiguration = {
  userRequestsPerMinute: 30,
  userRequestsPerHour: 300,
  userRequestsPerDay: 1_000,
  userOperationRequestsPerMinute: operationRecord(20),
  operationRequestsPerMinute: operationRecord(200),
  indicatorRequestsPerTenMinutes: 10,
  providerRequestsPerMinute: 240,
  providerRequestsPerHour: 5_000,
  providerOperationRequestsPerMinute: operationRecord(120),
};

interface RateLimitWindow {
  readonly name: string;
  readonly limit: number;
  readonly windowMs: number;
  readonly reason: RateLimitReason;
}

interface RateLimitScope {
  readonly key: string;
  readonly windows: readonly RateLimitWindow[];
}

interface StoredCounter {
  readonly count: number;
  readonly windowStart: number;
}

interface StoredScope {
  readonly counters: Readonly<Record<string, StoredCounter>>;
  readonly expiresAt: number;
}

export interface RateLimitStorage {
  consume(
    scopes: readonly RateLimitScope[],
    nowMs: number,
  ): Promise<RateLimitDecision>;
}

export interface ProxyRateLimiter {
  consumeRequest(
    identity: VerifiedRequestIdentity,
    request: NormalizedIndicatorRequest,
    nowMs: number,
  ): Promise<RateLimitDecision>;

  consumeProvider(
    operation: ThreatIntelligenceOperation,
    nowMs: number,
  ): Promise<RateLimitDecision>;
}

export class FirestoreRateLimitStorage implements RateLimitStorage {
  constructor(private readonly firestore: Firestore) {}

  consume(
    scopes: readonly RateLimitScope[],
    nowMs: number,
  ): Promise<RateLimitDecision> {
    return this.firestore.runTransaction(async (transaction) => {
      const references = scopes.map((scope) => this.firestore
        .collection("threat_intel_rate_limits")
        .doc(bucketId(scope.key)));
      const snapshots = await Promise.all(references.map((reference) =>
        transaction.get(reference)));
      const evaluated = scopes.map((scope, index) => evaluateScope(
        scope,
        readCounters(snapshots[index].data()),
        nowMs,
      ));
      const blocked = evaluated.flatMap((item) => item.blockedReasons)[0];
      if (blocked !== undefined) return {allowed: false, reason: blocked};

      evaluated.forEach((item, index) => {
        transaction.set(references[index], {
          counters: item.counters,
          expiresAt: Timestamp.fromMillis(item.expiresAt),
        });
      });
      return {allowed: true};
    });
  }
}

export class InMemoryRateLimitStorage implements RateLimitStorage {
  private readonly records = new Map<string, StoredScope>();
  private tail: Promise<void> = Promise.resolve();

  constructor(private readonly maxRecords = 4_096) {
    if (maxRecords <= 0) throw new Error("invalid-rate-limit-storage-config");
  }

  async consume(
    scopes: readonly RateLimitScope[],
    nowMs: number,
  ): Promise<RateLimitDecision> {
    let release: (() => void) | undefined;
    const previous = this.tail;
    this.tail = new Promise<void>((resolve) => { release = resolve; });
    await previous;
    try {
      this.prune(nowMs);
      const newKeys = scopes.filter((scope) => !this.records.has(scope.key)).length;
      if (this.records.size + newKeys > this.maxRecords) {
        return {allowed: false, reason: "STORAGE_CAPACITY"};
      }
      const evaluated = scopes.map((scope) => evaluateScope(
        scope,
        this.records.get(scope.key)?.counters ?? {},
        nowMs,
      ));
      const blocked = evaluated.flatMap((item) => item.blockedReasons)[0];
      if (blocked !== undefined) return {allowed: false, reason: blocked};
      evaluated.forEach((item, index) => {
        this.records.set(scopes[index].key, {
          counters: item.counters,
          expiresAt: item.expiresAt,
        });
      });
      return {allowed: true};
    } finally {
      release?.();
    }
  }

  get size(): number {
    return this.records.size;
  }

  private prune(nowMs: number): void {
    for (const [key, record] of this.records) {
      if (record.expiresAt <= nowMs) this.records.delete(key);
    }
  }
}

class ConfiguredProxyRateLimiter implements ProxyRateLimiter {
  constructor(
    private readonly backendStorage: RateLimitStorage,
    private readonly configuration: () => ProxyRateLimitConfiguration,
  ) {}

  consumeRequest(
    identity: VerifiedRequestIdentity,
    request: NormalizedIndicatorRequest,
    nowMs: number,
  ): Promise<RateLimitDecision> {
    const configuration = this.configuration();
    validateConfiguration(configuration);
    return this.backendStorage.consume([
      {
        key: `user:${identity.uid}`,
        windows: [
          counter("minute", configuration.userRequestsPerMinute, 60_000, "USER_MINUTE"),
          counter("hour", configuration.userRequestsPerHour, 60 * 60_000, "USER_HOUR"),
          counter("day", configuration.userRequestsPerDay, 24 * 60 * 60_000, "USER_DAY"),
          counter(
            `operation-${request.operation}`,
            configuration.userOperationRequestsPerMinute[request.operation],
            60_000,
            "USER_OPERATION",
          ),
        ],
      },
      {
        key: `operation:${request.operation}`,
        windows: [counter(
          "minute",
          configuration.operationRequestsPerMinute[request.operation],
          60_000,
          "OPERATION",
        )],
      },
      {
        key: `indicator:${request.operation}:${request.indicator}`,
        windows: [counter(
          "ten-minute",
          configuration.indicatorRequestsPerTenMinutes,
          10 * 60_000,
          "INDICATOR",
        )],
      },
    ], nowMs);
  }

  consumeProvider(
    operation: ThreatIntelligenceOperation,
    nowMs: number,
  ): Promise<RateLimitDecision> {
    const configuration = this.configuration();
    validateConfiguration(configuration);
    return this.backendStorage.consume([{
      key: "provider:virustotal-premium",
      windows: [
        counter(
          "minute",
          configuration.providerRequestsPerMinute,
          60_000,
          "PROVIDER_MINUTE",
        ),
        counter(
          "hour",
          configuration.providerRequestsPerHour,
          60 * 60_000,
          "PROVIDER_HOUR",
        ),
        counter(
          `operation-${operation}`,
          configuration.providerOperationRequestsPerMinute[operation],
          60_000,
          "PROVIDER_OPERATION",
        ),
      ],
    }], nowMs);
  }
}

export class FirestoreProxyRateLimiter extends ConfiguredProxyRateLimiter {
  constructor(
    firestore: Firestore,
    configuration: () => ProxyRateLimitConfiguration,
  ) {
    super(new FirestoreRateLimitStorage(firestore), configuration);
  }
}

export class InMemoryProxyRateLimiter extends ConfiguredProxyRateLimiter {
  readonly memoryStorage: InMemoryRateLimitStorage;

  constructor(
    configuration: () => ProxyRateLimitConfiguration =
      () => defaultProxyRateLimitConfiguration,
    maxRecords = 4_096,
  ) {
    const storage = new InMemoryRateLimitStorage(maxRecords);
    super(storage, configuration);
    this.memoryStorage = storage;
  }
}

interface EvaluatedScope {
  readonly counters: Readonly<Record<string, StoredCounter>>;
  readonly expiresAt: number;
  readonly blockedReasons: readonly RateLimitReason[];
}

function evaluateScope(
  scope: RateLimitScope,
  stored: Readonly<Record<string, StoredCounter>>,
  nowMs: number,
): EvaluatedScope {
  const counters: Record<string, StoredCounter> = {};
  const blockedReasons: RateLimitReason[] = [];
  let expiresAt = nowMs;
  for (const window of scope.windows) {
    const previous = stored[window.name];
    const active = previous !== undefined &&
      previous.windowStart >= 0 &&
      nowMs < previous.windowStart + window.windowMs;
    const count = active ? previous.count : 0;
    const windowStart = active ? previous.windowStart : nowMs;
    if (count >= window.limit) blockedReasons.push(window.reason);
    counters[window.name] = {count: count + 1, windowStart};
    expiresAt = Math.max(expiresAt, windowStart + window.windowMs * 2);
  }
  return {counters, expiresAt, blockedReasons};
}

function readCounters(
  data: FirebaseFirestore.DocumentData | undefined,
): Readonly<Record<string, StoredCounter>> {
  if (!isRecord(data?.counters)) return {};
  const result: Record<string, StoredCounter> = {};
  for (const [name, value] of Object.entries(data.counters)) {
    if (!isRecord(value) || typeof value.count !== "number" ||
        !Number.isSafeInteger(value.count) || value.count < 0 ||
        typeof value.windowStart !== "number" ||
        !Number.isSafeInteger(value.windowStart) || value.windowStart < 0) {
      continue;
    }
    result[name] = {count: value.count, windowStart: value.windowStart};
  }
  return result;
}

function counter(
  name: string,
  limit: number,
  windowMs: number,
  reason: RateLimitReason,
): RateLimitWindow {
  return {name, limit, windowMs, reason};
}

function validateConfiguration(configuration: ProxyRateLimitConfiguration): void {
  const values = [
    configuration.userRequestsPerMinute,
    configuration.userRequestsPerHour,
    configuration.userRequestsPerDay,
    configuration.indicatorRequestsPerTenMinutes,
    configuration.providerRequestsPerMinute,
    configuration.providerRequestsPerHour,
    ...Object.values(configuration.userOperationRequestsPerMinute),
    ...Object.values(configuration.operationRequestsPerMinute),
    ...Object.values(configuration.providerOperationRequestsPerMinute),
  ];
  if (values.some((value) => !Number.isSafeInteger(value) || value <= 0)) {
    throw new Error("invalid-rate-limit-config");
  }
}

function operationRecord(value: number): Record<ThreatIntelligenceOperation, number> {
  return {HASH: value, URL: value, DOMAIN: value, IPV4: value, IPV6: value};
}

function bucketId(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
