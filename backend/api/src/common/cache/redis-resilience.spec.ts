import { RedisCacheStore } from './redis-cache.store';

describe('Redis & Distributed Cache Resilience', () => {
  it('falls back cleanly to in-memory store when Redis host is unreachable without crashing', async () => {
    // Attempt connection to a non-existent port
    const unreachableStore = new RedisCacheStore({
      host: '127.0.0.1',
      port: 59999, // Unused port
    });

    // 1. Should not throw when setting data
    await expect(unreachableStore.set('resilient_key', 'resilient_value', 60)).resolves.not.toThrow();

    // 2. Should retrieve from fallback store seamlessly
    const val = await unreachableStore.get('resilient_key');
    expect(val).toBe('resilient_value');

    // 3. Rate limit increment should succeed on fallback store
    const inc = await unreachableStore.increment('ratelimit:fallback:test', 10000);
    expect(inc.count).toBe(1);
    expect(inc.resetTime).toBeGreaterThan(Date.now());

    // 4. Deletion by prefix should succeed on fallback store
    await unreachableStore.set('prefix:1', 'a');
    await unreachableStore.set('prefix:2', 'b');
    await unreachableStore.delByPrefix('prefix:');
    expect(await unreachableStore.get('prefix:1')).toBeNull();
    expect(await unreachableStore.get('prefix:2')).toBeNull();
  });

  it('correctly parses RESP responses including multi-bulk arrays and bulk strings', () => {
    const store = new RedisCacheStore({ host: '127.0.0.1', port: 59999 });
    const parse = (store as any).parseResponse.bind(store);

    expect(parse('+OK\r\n')).toBe('OK');
    expect(parse(':42\r\n')).toBe('42');
    expect(parse('$5\r\nhello\r\n')).toBe('hello');
    expect(parse('$-1\r\n')).toBeNull();

    // Multi-bulk array (such as returned by KEYS command)
    const arrayResp = '*2\r\n$11\r\ndashboard:1\r\n$11\r\ndashboard:2\r\n';
    expect(parse(arrayResp)).toBe('dashboard:1\ndashboard:2');
  });
});
