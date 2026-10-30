import { ConfigService } from '@nestjs/config';
import { CacheService } from './cache.service';
import { InMemoryCacheStore } from './in-memory-cache.store';

describe('CacheService & Stores', () => {
  describe('InMemoryCacheStore', () => {
    let store: InMemoryCacheStore;

    beforeEach(() => {
      store = new InMemoryCacheStore();
    });

    it('sets and gets values correctly', async () => {
      await store.set('test_key', 'test_value');
      const val = await store.get('test_key');
      expect(val).toBe('test_value');
    });

    it('returns null for nonexistent keys', async () => {
      const val = await store.get('nonexistent');
      expect(val).toBeNull();
    });

    it('deletes keys correctly', async () => {
      await store.set('k1', 'v1');
      await store.del('k1');
      const val = await store.get('k1');
      expect(val).toBeNull();
    });

    it('deletes keys by prefix correctly', async () => {
      await store.set('dashboard:biz_1:today', 'data1');
      await store.set('dashboard:biz_1:month', 'data2');
      await store.set('dashboard:biz_2:today', 'data3');

      await store.delByPrefix('dashboard:biz_1');

      expect(await store.get('dashboard:biz_1:today')).toBeNull();
      expect(await store.get('dashboard:biz_1:month')).toBeNull();
      expect(await store.get('dashboard:biz_2:today')).toBe('data3');
    });

    it('handles atomic increments for rate limiting', async () => {
      const r1 = await store.increment('ratelimit:127.0.0.1:/api/test', 60000);
      expect(r1.count).toBe(1);
      expect(r1.resetTime).toBeGreaterThan(Date.now());

      const r2 = await store.increment('ratelimit:127.0.0.1:/api/test', 60000);
      expect(r2.count).toBe(2);
      expect(r2.resetTime).toBe(r1.resetTime);
    });

    it('expires keys after TTL passes', async () => {
      await store.set('temp_key', 'temp_val', -1); // Already expired
      const val = await store.get('temp_key');
      expect(val).toBeNull();
    });
  });

  describe('CacheService', () => {
    let service: CacheService;
    let configService: Partial<ConfigService>;

    beforeEach(() => {
      configService = {
        get: jest.fn((key: string, defaultVal?: any) => {
          if (key === 'redis.enabled') return false;
          return defaultVal;
        }),
      };
      service = new CacheService(configService as ConfigService);
    });

    it('serializes and deserializes JSON objects correctly', async () => {
      const payload = { totalSales: 50000, invoiceCount: 12 };
      await service.setJson('metrics:biz_1', payload, 60);

      const cached = await service.getJson<typeof payload>('metrics:biz_1');
      expect(cached).toEqual(payload);
    });

    it('returns null when JSON parsing fails or key not found', async () => {
      expect(await service.getJson('unknown_key')).toBeNull();

      await service.set('invalid_json', '{bad_json');
      expect(await service.getJson('invalid_json')).toBeNull();
    });

    it('increments distributed rate limit keys correctly', async () => {
      const res = await service.increment('ip_test', 1000);
      expect(res.count).toBe(1);
    });
  });
});

