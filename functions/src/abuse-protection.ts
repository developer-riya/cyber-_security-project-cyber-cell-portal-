import {createHash} from "node:crypto";

import {VerifiedRequestIdentity} from "./types";

export type AbuseSignalLevel = "NORMAL" | "WATCH" | "HIGH_ABUSE_SIGNAL";

export type AbuseObservationKind =
  | "AUTH_FAILURE"
  | "APP_CHECK_FAILURE"
  | "INVALID_INDICATOR"
  | "DUPLICATE"
  | "BURST"
  | "RATE_LIMIT"
  | "PROVIDER_QUOTA"
  | "INDICATOR_ACTIVITY";

export interface AbuseObservation {
  readonly kind: AbuseObservationKind;
  readonly scope: string;
  readonly actor?: string;
}

interface AbuseEntry {
  count: number;
  readonly actors: Set<string>;
  expiresAt: number;
}

export class BoundedAbuseSignalTracker {
  private readonly entries = new Map<string, AbuseEntry>();

  constructor(
    private readonly maxEntries = 256,
    private readonly ttlMs = 10 * 60_000,
    private readonly watchThreshold = 3,
    private readonly highThreshold = 8,
    private readonly multiAccountWatchThreshold = 3,
    private readonly multiAccountHighThreshold = 5,
  ) {
    if (maxEntries <= 0 || ttlMs <= 0) throw new Error("invalid-abuse-config");
  }

  observe(observation: AbuseObservation, nowMs: number): AbuseSignalLevel {
    this.prune(nowMs);
    const key = fingerprint(`${observation.kind}\u0000${observation.scope}`);
    let entry = this.entries.get(key);
    if (entry === undefined) {
      if (this.entries.size >= this.maxEntries) return "HIGH_ABUSE_SIGNAL";
      entry = {count: 0, actors: new Set<string>(), expiresAt: nowMs + this.ttlMs};
    } else {
      this.entries.delete(key);
    }
    entry.count += 1;
    entry.expiresAt = nowMs + this.ttlMs;
    if (observation.actor !== undefined && entry.actors.size < 16) {
      entry.actors.add(fingerprint(observation.actor));
    }
    this.entries.set(key, entry);

    if (entry.count >= this.highThreshold ||
        entry.actors.size >= this.multiAccountHighThreshold) {
      return "HIGH_ABUSE_SIGNAL";
    }
    if (entry.count >= this.watchThreshold ||
        entry.actors.size >= this.multiAccountWatchThreshold) {
      return "WATCH";
    }
    return "NORMAL";
  }

  get size(): number {
    return this.entries.size;
  }

  private prune(nowMs: number): void {
    for (const [key, entry] of this.entries) {
      if (entry.expiresAt <= nowMs) this.entries.delete(key);
    }
  }
}

export interface BurstProtectionConfiguration {
  readonly userRequests: number;
  readonly userWindowMs: number;
  readonly instanceRequests: number;
  readonly instanceWindowMs: number;
  readonly maxUserEntries: number;
}

interface BurstEntry {
  count: number;
  windowStart: number;
  lastUsed: number;
}

export interface BurstProtectionDecision {
  readonly allowed: boolean;
  readonly reason?: "USER_BURST" | "INSTANCE_BURST" | "CAPACITY";
}

export class BoundedBurstProtector {
  private readonly users = new Map<string, BurstEntry>();
  private instance: BurstEntry = {count: 0, windowStart: 0, lastUsed: 0};

  constructor(
    private readonly configuration: () => BurstProtectionConfiguration,
  ) {}

  consume(
    identity: VerifiedRequestIdentity,
    nowMs: number,
  ): BurstProtectionDecision {
    const configuration = this.configuration();
    validateBurstConfiguration(configuration);
    this.prune(nowMs, configuration.userWindowMs);

    const userKey = fingerprint(identity.uid);
    const existing = this.users.get(userKey);
    if (existing === undefined && this.users.size >= configuration.maxUserEntries) {
      return {allowed: false, reason: "CAPACITY"};
    }
    const user = activeWindow(existing, nowMs, configuration.userWindowMs);
    const instance = activeWindow(
      this.instance,
      nowMs,
      configuration.instanceWindowMs,
    );
    if (user.count >= configuration.userRequests) {
      return {allowed: false, reason: "USER_BURST"};
    }
    if (instance.count >= configuration.instanceRequests) {
      return {allowed: false, reason: "INSTANCE_BURST"};
    }
    user.count += 1;
    user.lastUsed = nowMs;
    instance.count += 1;
    instance.lastUsed = nowMs;
    this.users.delete(userKey);
    this.users.set(userKey, user);
    this.instance = instance;
    return {allowed: true};
  }

  get trackedUsers(): number {
    return this.users.size;
  }

  private prune(nowMs: number, windowMs: number): void {
    for (const [key, entry] of this.users) {
      if (entry.windowStart + windowMs <= nowMs) this.users.delete(key);
    }
  }
}

export class BoundedConcurrencyGate {
  private active = 0;

  constructor(private readonly limit: () => number) {}

  tryAcquire(): (() => void) | undefined {
    const limit = this.limit();
    if (!Number.isSafeInteger(limit) || limit <= 0) {
      throw new Error("invalid-concurrency-limit");
    }
    if (this.active >= limit) return undefined;
    this.active += 1;
    let released = false;
    return () => {
      if (released) return;
      released = true;
      this.active -= 1;
    };
  }

  get activeCount(): number {
    return this.active;
  }
}

function activeWindow(
  entry: BurstEntry | undefined,
  nowMs: number,
  windowMs: number,
): BurstEntry {
  if (entry === undefined || entry.windowStart + windowMs <= nowMs) {
    return {count: 0, windowStart: nowMs, lastUsed: nowMs};
  }
  return entry;
}

function validateBurstConfiguration(configuration: BurstProtectionConfiguration): void {
  const values = [
    configuration.userRequests,
    configuration.userWindowMs,
    configuration.instanceRequests,
    configuration.instanceWindowMs,
    configuration.maxUserEntries,
  ];
  if (values.some((value) => !Number.isSafeInteger(value) || value <= 0)) {
    throw new Error("invalid-burst-config");
  }
}

function fingerprint(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}
