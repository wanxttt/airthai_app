import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import * as crypto from 'crypto';

export interface CorrelatedRequest extends Request {
  requestId?: string;
}

@Injectable()
export class CorrelationIdMiddleware implements NestMiddleware {
  use(req: CorrelatedRequest, res: Response, next: NextFunction): void {
    const rawHeader = req.headers['x-request-id'] || req.headers['x-correlation-id'];
    let requestId: string;

    if (
      typeof rawHeader === 'string' &&
      rawHeader.trim().length > 0 &&
      /^[a-zA-Z0-9_\-.]{1,64}$/.test(rawHeader.trim())
    ) {
      requestId = rawHeader.trim();
    } else {
      requestId = `req_${crypto.randomUUID()}`;
    }

    req.requestId = requestId;
    req.headers['x-request-id'] = requestId;
    res.setHeader('X-Request-Id', requestId);

    next();
  }
}

