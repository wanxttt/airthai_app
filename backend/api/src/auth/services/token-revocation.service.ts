import { Injectable, Logger } from '@nestjs/common';

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

  /**
   * Registers a newly issued refresh token.
   */
  registerRefreshToken(jti: string, family: string, userId: string, ttlMs: number): void {
    this.cleanExpiredTokens();
    this.activeTokens.set(jti, {
      jti,
      family,
      userId,
      expiresAt: Date.now() + ttlMs,
    });
  }

  /**
   * Validates and rotates a refresh token.
   * If the token was already rotated, reuse is detected and the entire family is revoked.
   */
  rotateRefreshToken(
    oldJti: string,
    newJti: string,
    family: string,
    userId: string,
    ttlMs: number,
  ): boolean {
    this.cleanExpiredTokens();

    // Check if the entire family has been revoked
    if (this.revokedFamilies.has(family)) {
      this.logger.warn(`Rejected refresh: family ${family} has been revoked.`);
      return false;
    }

    // Check if the token was already used (Reuse Detection)
    if (this.rotatedTokens.has(oldJti)) {
      this.logger.error(`REUSE DETECTED: token ${oldJti} was already rotated. Revoking family ${family} for user ${userId}.`);
      this.revokeFamily(family);
      return false;
    }

    // Check if the old token is currently active
    const activeInfo = this.activeTokens.get(oldJti);
    if (!activeInfo || activeInfo.family !== family || activeInfo.userId !== userId) {
      this.logger.warn(`Rejected refresh: token ${oldJti} not found or mismatch.`);
      return false;
    }

    // Check expiration
    if (Date.now() > activeInfo.expiresAt) {
      this.activeTokens.delete(oldJti);
      return false;
    }

    // Rotate: remove old active token, mark as rotated
    this.activeTokens.delete(oldJti);
    this.rotatedTokens.add(oldJti);

    // Register new active token in the same family
    this.registerRefreshToken(newJti, family, userId, ttlMs);
    return true;
  }

  /**
   * Revokes an entire token family (e.g. upon logout or detected attack).
   */
  revokeFamily(family: string): void {
    this.revokedFamilies.add(family);

    // Remove any active tokens belonging to this family
    for (const [jti, info] of this.activeTokens.entries()) {
      if (info.family === family) {
        this.activeTokens.delete(jti);
      }
    }
  }

  /**
   * Revokes all active refresh tokens for a user (e.g. global logout / password change).
   */
  revokeAllForUser(userId: string): void {
    for (const [jti, info] of this.activeTokens.entries()) {
      if (info.userId === userId) {
        this.revokedFamilies.add(info.family);
        this.activeTokens.delete(jti);
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

