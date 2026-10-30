export interface ICacheStore {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, ttlSeconds?: number): Promise<void>;
  del(key: string): Promise<void>;
  delByPrefix(prefix: string): Promise<void>;
  increment(key: string, ttlMs: number): Promise<{ count: number; resetTime: number }>;
  ping(): Promise<boolean>;
}

