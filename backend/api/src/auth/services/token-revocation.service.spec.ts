import { TokenRevocationService } from './token-revocation.service';
import { CacheService } from '../../common/cache/cache.service';

describe('TokenRevocationService', () => {
  let service: TokenRevocationService;
  let mockCacheService: Partial<CacheService>;
  let cacheStore: Map<string, string>;

  beforeEach(() => {
    cacheStore = new Map<string, string>();
    mockCacheService = {
      get: jest.fn(async (key: string) => cacheStore.get(key) || null),
      set: jest.fn(async (key: string, val: string) => {
        cacheStore.set(key, val);
      }),
      del: jest.fn(async (key: string) => {
        cacheStore.delete(key);
      }),
      getJson: jest.fn(async (key: string) => {
        const raw = cacheStore.get(key);
        return raw ? JSON.parse(raw) : null;
      }),
      setJson: jest.fn(async (key: string, val: any) => {
        cacheStore.set(key, JSON.stringify(val));
      }),
    };

    service = new TokenRevocationService(mockCacheService as CacheService);
  });

  it('registers and rotates refresh tokens cleanly', async () => {
    await service.registerRefreshToken('jti_1', 'fam_1', 'usr_1', 100000);

    const rotated = await service.rotateRefreshToken('jti_1', 'jti_2', 'fam_1', 'usr_1', 100000);
    expect(rotated).toBe(true);

    // Old token should be marked rotated in cache
    expect(mockCacheService.set).toHaveBeenCalledWith(
      'token:rotated:jti_1',
      '1',
      expect.any(Number),
    );
  });

  it('detects token reuse and revokes entire family across distributed cache', async () => {
    await service.registerRefreshToken('jti_a', 'fam_reuse', 'usr_1', 100000);
    await service.rotateRefreshToken('jti_a', 'jti_b', 'fam_reuse', 'usr_1', 100000);

    // Attacker presents rotated token jti_a again
    const reuseAttempt = await service.rotateRefreshToken('jti_a', 'jti_c', 'fam_reuse', 'usr_1', 100000);
    expect(reuseAttempt).toBe(false);

    // Family must now be stored as revoked in cache
    expect(cacheStore.get('token:revoked_family:fam_reuse')).toBe('1');

    // Legitimate user with jti_b now tries to rotate, should also be rejected
    const legitimateNextAttempt = await service.rotateRefreshToken('jti_b', 'jti_d', 'fam_reuse', 'usr_1', 100000);
    expect(legitimateNextAttempt).toBe(false);
  });

  it('revokes user tokens on logout and syncs with cache', async () => {
    await service.registerRefreshToken('jti_x', 'fam_logout', 'usr_out', 100000);
    await service.revokeFamily('fam_logout');

    const tryRotate = await service.rotateRefreshToken('jti_x', 'jti_y', 'fam_logout', 'usr_out', 100000);
    expect(tryRotate).toBe(false);
    expect(cacheStore.get('token:revoked_family:fam_logout')).toBe('1');
  });
});

