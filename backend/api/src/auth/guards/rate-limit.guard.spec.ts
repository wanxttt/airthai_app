import { ExecutionContext, HttpException, HttpStatus } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RateLimitGuard } from './rate-limit.guard';
import { RATE_LIMIT_KEY } from '../decorators/rate-limit.decorator';

describe('RateLimitGuard Abuse & Bypass Prevention', () => {
  let guard: RateLimitGuard;
  let reflector: jest.Mocked<Reflector>;

  beforeEach(() => {
    reflector = {
      getAllAndOverride: jest.fn(),
    } as any;
    guard = new RateLimitGuard(reflector);
  });

  const createMockContext = (ip: string, url: string, path: string) => {
    return {
      getHandler: jest.fn(),
      getClass: jest.fn(),
      switchToHttp: () => ({
        getRequest: () => ({
          ip,
          url,
          path,
          headers: {},
          socket: { remoteAddress: ip },
        }),
      }),
    } as unknown as ExecutionContext;
  };

  it('MUST allow requests under the configured threshold', () => {
    reflector.getAllAndOverride.mockReturnValue({ limit: 3, ttlMs: 60000 });
    const ctx = createMockContext('192.168.1.100', '/api/v1/auth/login', '/api/v1/auth/login');

    expect(guard.canActivate(ctx)).toBe(true);
    expect(guard.canActivate(ctx)).toBe(true);
    expect(guard.canActivate(ctx)).toBe(true);
  });

  it('MUST throw 429 Too Many Requests when threshold is exceeded', () => {
    reflector.getAllAndOverride.mockReturnValue({ limit: 2, ttlMs: 60000 });
    const ctx = createMockContext('192.168.1.101', '/api/v1/auth/login', '/api/v1/auth/login');

    expect(guard.canActivate(ctx)).toBe(true);
    expect(guard.canActivate(ctx)).toBe(true);

    try {
      guard.canActivate(ctx);
      fail('Expected HttpException 429 to be thrown');
    } catch (err: any) {
      expect(err).toBeInstanceOf(HttpException);
      expect(err.getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
    }
  });

  it('MUST NOT allow bypass via query parameter cache-busting (e.g. ?nonce=123)', () => {
    reflector.getAllAndOverride.mockReturnValue({ limit: 2, ttlMs: 60000 });

    // Request 1 with query parameter ?nonce=1
    const ctx1 = createMockContext('192.168.1.102', '/api/v1/auth/login?nonce=1', '/api/v1/auth/login');
    expect(guard.canActivate(ctx1)).toBe(true);

    // Request 2 with different query parameter ?nonce=2
    const ctx2 = createMockContext('192.168.1.102', '/api/v1/auth/login?nonce=2', '/api/v1/auth/login');
    expect(guard.canActivate(ctx2)).toBe(true);

    // Request 3 with different query parameter ?nonce=3 MUST be blocked!
    const ctx3 = createMockContext('192.168.1.102', '/api/v1/auth/login?nonce=3', '/api/v1/auth/login');
    expect(() => guard.canActivate(ctx3)).toThrow(HttpException);
  });
});

