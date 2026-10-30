import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  Optional,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { RATE_LIMIT_KEY, RateLimitOptions } from '../decorators/rate-limit.decorator';
import { CacheService } from '../../common/cache/cache.service';

interface RequestBucket {
  count: number;
  resetTime: number;
}

@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly logger = new Logger(RateLimitGuard.name);
  private readonly clients = new Map<string, RequestBucket>();

  constructor(
    private readonly reflector: Reflector,
    @Optional() private readonly cacheService?: CacheService,
  ) {}

  canActivate(context: ExecutionContext): boolean | Promise<boolean> {
    const options = this.reflector.getAllAndOverride<RateLimitOptions>(RATE_LIMIT_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!options) {
      return true; // No rate limit specified
    }

    const request = context.switchToHttp().getRequest<Request>();
    const rawForwarded = request.headers['x-forwarded-for'];
    const clientIp =
      (typeof rawForwarded === 'string' ? rawForwarded.split(',')[0].trim() : undefined) ||
      request.ip ||
      request.socket.remoteAddress ||
      'unknown';

    // Normalize path by stripping query strings to prevent cache-busting rate limit bypass
    const cleanPath = request.path || (request.url ? request.url.split('?')[0] : '');
    const key = `ratelimit:${clientIp}:${cleanPath}`;

    if (this.cacheService) {
      return this.handleAsync(key, clientIp, cleanPath, options);
    }

    return this.handleSync(key, clientIp, cleanPath, options);
  }

  private handleSync(key: string, clientIp: string, cleanPath: string, options: RateLimitOptions): boolean {
    const now = Date.now();

    // Memory leak protection: periodically prune expired buckets if map exceeds threshold
    if (this.clients.size > 1000) {
      for (const [k, b] of this.clients.entries()) {
        if (now > b.resetTime) {
          this.clients.delete(k);
        }
      }
    }

    const bucket = this.clients.get(key);

    if (!bucket || now > bucket.resetTime) {
      this.clients.set(key, {
        count: 1,
        resetTime: now + options.ttlMs,
      });
      return true;
    }

    bucket.count += 1;
    if (bucket.count > options.limit) {
      const waitSeconds = Math.ceil((bucket.resetTime - now) / 1000);
      this.logger.warn(`Rate limit exceeded for IP ${clientIp} on ${cleanPath}`);
      throw new HttpException(
        {
          statusCode: HttpStatus.TOO_MANY_REQUESTS,
          error: 'Too Many Requests',
          message: `Too many attempts. Please try again in ${waitSeconds} seconds.`,
          retryAfter: waitSeconds,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    return true;
  }

  private async handleAsync(
    key: string,
    clientIp: string,
    cleanPath: string,
    options: RateLimitOptions,
  ): Promise<boolean> {
    const entry = await this.cacheService!.increment(key, options.ttlMs);
    if (entry.count > options.limit) {
      const waitSeconds = Math.max(1, Math.ceil((entry.resetTime - Date.now()) / 1000));
      this.logger.warn(`Rate limit exceeded for IP ${clientIp} on ${cleanPath}`);
      throw new HttpException(
        {
          statusCode: HttpStatus.TOO_MANY_REQUESTS,
          error: 'Too Many Requests',
          message: `Too many attempts. Please try again in ${waitSeconds} seconds.`,
          retryAfter: waitSeconds,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    return true;
  }
}
