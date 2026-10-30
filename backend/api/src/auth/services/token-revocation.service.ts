import { Injectable, Logger, Optional } from '@nestjs/common';
import { CacheService } from '../../common/cache/cache.service';

interface ActiveTokenInfo {
  jti: string;
  family: string;
  userId: string;
  expiresAt: number;
}

@Injectable()
export class TokenRevocationService {
  private readonly logger = new Logger(TokenRevocationService.name);

  // Active JTIs that are valid for refresh
  private readonly activeTokens = new Map<string, ActiveTokenInfo>();

  // Rotated JTIs that have been used. If presented again, indicates reuse attack!
  private readonly rotatedTokens = new Set<string>();

  // Revoked token families (e.g. after logout or reuse detected)
  private readonly revokedFamilies = new Set<string>();

  constructor(@Optional() private readonly cacheService?: CacheService) {}

  /**
   * Registers a newly issued refresh token.
   */
  async registerRefreshToken(jti: string, family: string, userId: string, ttlMs: number): Promise<void> {
    this.cleanExpiredTokens();
    const expiresAt = Date.now() + ttlMs;
    this.activeTokens.set(jti, {
      jti,
      family,
      userId,
      expiresAt,
    });

    if (this.cacheService) {
      const ttlSec = Math.max(1, Math.ceil(ttlMs / 1000));
      await this.cacheService.setJson(`token:active:${jti}`, { jti, family, userId, expiresAt }, ttlSec);
    }
  }

  /**
   * Validates and rotates a refresh token.
   * If the token was already rotated, reuse is detected and the entire family is revoked.
   */
  async rotateRefreshToken(
    oldJti: string,
    newJti: string,
    family: string,
    userId: string,
    ttlMs: number,
  ): Promise<boolean> {
    this.cleanExpiredTokens();

    // 1. Check if the entire family has been revoked (locally or in distributed cache)
    if (this.revokedFamilies.has(family)) {
      this.logger.warn(`Rejected refresh: family ${family} has been revoked.`);
      return false;
    }
    if (this.cacheService) {
      const isRevokedInCache = await this.cacheService.get(`token:revoked_family:${family}`);
      if (isRevokedInCache) {
        this.revokedFamilies.add(family);
        this.logger.warn(`Rejected refresh: family ${family} has been revoked in distributed cache.`);
        return false;
      }
    }

    // 2. Check if the token was already used (Reuse Detection)
    if (this.rotatedTokens.has(oldJti)) {
      this.logger.error(`REUSE DETECTED: token ${oldJti} was already rotated. Revoking family ${family} for user ${userId}.`);
      await this.revokeFamily(family);
      return false;
    }
    if (this.cacheService) {
      const isRotatedInCache = await this.cacheService.get(`token:rotated:${oldJti}`);
      if (isRotatedInCache) {
        this.rotatedTokens.add(oldJti);
        this.logger.error(`REUSE DETECTED: token ${oldJti} was already rotated in distributed cache. Revoking family ${family} for user ${userId}.`);
        await this.revokeFamily(family);
        return false;
      }
    }

    // 3. Check if the old token is currently active
    let activeInfo = this.activeTokens.get(oldJti);
    if (!activeInfo && this.cacheService) {
      activeInfo = (await this.cacheService.getJson<ActiveTokenInfo>(`token:active:${oldJti}`)) || undefined;
    }

    if (!activeInfo || activeInfo.family !== family || activeInfo.userId !== userId) {
      this.logger.warn(`Rejected refresh: token ${oldJti} not found or mismatch.`);
      return false;
    }

    // Check expiration
    if (Date.now() > activeInfo.expiresAt) {
      this.activeTokens.delete(oldJti);
      if (this.cacheService) {
        await this.cacheService.del(`token:active:${oldJti}`);
      }
      return false;
    }

    // Rotate: remove old active token, mark as rotated
    this.activeTokens.delete(oldJti);
    this.rotatedTokens.add(oldJti);

    if (this.cacheService) {
      const ttlSec = Math.max(1, Math.ceil(ttlMs / 1000));
      await this.cacheService.del(`token:active:${oldJti}`);
      await this.cacheService.set(`token:rotated:${oldJti}`, '1', ttlSec);
    }

    // Register new active token in the same family
    await this.registerRefreshToken(newJti, family, userId, ttlMs);
    return true;
  }

  /**
   * Revokes an entire token family (e.g. upon logout or detected attack).
   */
  async revokeFamily(family: string): Promise<void> {
    this.revokedFamilies.add(family);

    // Remove any active tokens belonging to this family locally
    for (const [jti, info] of this.activeTokens.entries()) {
      if (info.family === family) {
        this.activeTokens.delete(jti);
      }
    }

    if (this.cacheService) {
      // Retain family revocation tombstone for 7 days in distributed cache
      await this.cacheService.set(`token:revoked_family:${family}`, '1', 7 * 24 * 3600);
    }
  }

  /**
   * Revokes all active refresh tokens for a user (e.g. global logout / password change).
   */
  async revokeAllForUser(userId: string): Promise<void> {
    for (const [jti, info] of this.activeTokens.entries()) {
      if (info.userId === userId) {
        this.revokedFamilies.add(info.family);
        this.activeTokens.delete(jti);
        if (this.cacheService) {
          await this.cacheService.set(`token:revoked_family:${info.family}`, '1', 7 * 24 * 3600);
        }
      }
    }
  }

  private cleanExpiredTokens(): void {
    const now = Date.now();
    for (const [jti, info] of this.activeTokens.entries()) {
      if (now > info.expiresAt) {
        this.activeTokens.delete(jti);
      }
    }
  }
}
