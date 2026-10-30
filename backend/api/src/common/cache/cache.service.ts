import { Injectable, Logger, OnModuleDestroy, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ICacheStore } from './cache.interface';
import { InMemoryCacheStore } from './in-memory-cache.store';
import { RedisCacheStore } from './redis-cache.store';
import { TelemetryService } from '../monitoring/telemetry.service';

@Injectable()
export class CacheService implements OnModuleDestroy {
  private readonly logger = new Logger(CacheService.name);
  private readonly store: ICacheStore;

  constructor(
    private readonly configService: ConfigService,
    @Optional() private readonly telemetry?: TelemetryService,
  ) {
    const redisEnabled = this.configService.get<boolean>('redis.enabled', false);
    const host = this.configService.get<string>('redis.host', 'localhost');
    const port = this.configService.get<number>('redis.port', 6379);
    const password = this.configService.get<string>('redis.password');

    if (redisEnabled) {
      this.logger.log(`Initializing distributed Redis cache store (${host}:${port})...`);
      this.store = new RedisCacheStore({ host, port, password });
    } else {
      this.logger.log('Redis disabled. Initializing high-performance in-memory cache store...');
      this.store = new InMemoryCacheStore();
    }
  }

  async get(key: string): Promise<string | null> {
    try {
      const res = await this.store.get(key);
      if (res !== null) {
        this.telemetry?.recordCacheHit();
      } else {
        this.telemetry?.recordCacheMiss();
      }
      return res;
    } catch (err: any) {
      this.telemetry?.recordCacheError();
      this.logger.warn(`Cache get failed for key "${key}": ${err.message}`);
      return null;
    }
  }

  async getJson<T>(key: string): Promise<T | null> {
    const raw = await this.get(key);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as T;
    } catch {
      return null;
    }
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    try {
      await this.store.set(key, value, ttlSeconds);
    } catch (err: any) {
      this.logger.warn(`Cache set failed for key "${key}": ${err.message}`);
    }
  }

  async setJson<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
    try {
      const raw = JSON.stringify(value);
      await this.set(key, raw, ttlSeconds);
    } catch (err: any) {
      this.logger.warn(`Cache setJson serialization failed for key "${key}": ${err.message}`);
    }
  }

  async del(key: string): Promise<void> {
    try {
      await this.store.del(key);
    } catch (err: any) {
      this.logger.warn(`Cache del failed for key "${key}": ${err.message}`);
    }
  }

  async delByPrefix(prefix: string): Promise<void> {
    try {
      await this.store.delByPrefix(prefix);
    } catch (err: any) {
      this.logger.warn(`Cache delByPrefix failed for prefix "${prefix}": ${err.message}`);
    }
  }

  async increment(key: string, ttlMs: number): Promise<{ count: number; resetTime: number }> {
    try {
      return await this.store.increment(key, ttlMs);
    } catch {
      return { count: 1, resetTime: Date.now() + ttlMs };
    }
  }

  async onModuleDestroy(): Promise<void> {
    // Graceful teardown
  }
}

