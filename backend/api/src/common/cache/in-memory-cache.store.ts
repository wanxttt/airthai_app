import { ICacheStore } from './cache.interface';

interface CacheEntry {
  value: string;
  expiresAt: number | null;
}

interface RateLimitEntry {
  count: number;
  resetTime: number;
}

export class InMemoryCacheStore implements ICacheStore {
  private readonly store = new Map<string, CacheEntry>();
  private readonly rateLimits = new Map<string, RateLimitEntry>();

  async get(key: string): Promise<string | null> {
    const entry = this.store.get(key);
    if (!entry) return null;

    if (entry.expiresAt !== null && Date.now() > entry.expiresAt) {
      this.store.delete(key);
      return null;
    }

    return entry.value;
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    this.pruneIfExceeded();
    const expiresAt = ttlSeconds !== undefined ? Date.now() + ttlSeconds * 1000 : null;
    this.store.set(key, { value, expiresAt });
  }

  async del(key: string): Promise<void> {
    this.store.delete(key);
  }

  async delByPrefix(prefix: string): Promise<void> {
    for (const key of this.store.keys()) {
      if (key.startsWith(prefix)) {
        this.store.delete(key);
      }
    }
  }

  async increment(key: string, ttlMs: number): Promise<{ count: number; resetTime: number }> {
    const now = Date.now();
    const entry = this.rateLimits.get(key);

    if (!entry || now > entry.resetTime) {
      const newEntry: RateLimitEntry = {
        count: 1,
        resetTime: now + ttlMs,
      };
      this.rateLimits.set(key, newEntry);
      return newEntry;
    }

    entry.count += 1;
    return { count: entry.count, resetTime: entry.resetTime };
  }

  async ping(): Promise<boolean> {
    return true;
  }

  private pruneIfExceeded(): void {
    if (this.store.size > 5000) {
      const now = Date.now();
      for (const [key, entry] of this.store.entries()) {
        if (entry.expiresAt !== null && now > entry.expiresAt) {
          this.store.delete(key);
        }
      }
    }

    if (this.rateLimits.size > 2000) {
      const now = Date.now();
      for (const [key, entry] of this.rateLimits.entries()) {
        if (now > entry.resetTime) {
          this.rateLimits.delete(key);
        }
      }
    }
  }
}
