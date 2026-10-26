interface CacheEntry<T> {
  readonly value: T;
  readonly expiresAt: number;
}

export class BoundedTtlCache<T> {
  private readonly entries = new Map<string, CacheEntry<T>>();

  constructor(
    private readonly maxEntries: number,
    private readonly ttlMs: number,
  ) {
    if (maxEntries <= 0 || ttlMs <= 0) throw new Error("invalid-cache-config");
  }

  get(key: string, nowMs: number): T | undefined {
    const entry = this.entries.get(key);
    if (entry === undefined) return undefined;
    this.entries.delete(key);
    if (entry.expiresAt <= nowMs) return undefined;
    this.entries.set(key, entry);
    return entry.value;
  }

  set(key: string, value: T, nowMs: number): void {
    this.entries.delete(key);
    this.entries.set(key, {value, expiresAt: nowMs + this.ttlMs});
    while (this.entries.size > this.maxEntries) {
      const oldest = this.entries.keys().next().value as string | undefined;
      if (oldest === undefined) break;
      this.entries.delete(oldest);
    }
  }

  get size(): number {
    return this.entries.size;
  }
}
