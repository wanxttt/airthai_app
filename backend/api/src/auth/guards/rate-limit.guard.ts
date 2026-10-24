import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { RATE_LIMIT_KEY, RateLimitOptions } from '../decorators/rate-limit.decorator';

interface RequestBucket {
  count: number;
  resetTime: number;
}

@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly logger = new Logger(RateLimitGuard.name);
  private readonly clients = new Map<string, RequestBucket>();

  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const options = this.reflector.getAllAndOverride<RateLimitOptions>(RATE_LIMIT_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!options) {
      return true; // No rate limit specified
    }

    const request = context.switchToHttp().getRequest<Request>();
    const clientIp = request.ip || request.socket.remoteAddress || 'unknown';
    const key = `${clientIp}:${request.url}`;
    const now = Date.now();

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
      this.logger.warn(`Rate limit exceeded for IP ${clientIp} on ${request.url}`);
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
