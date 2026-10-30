import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
  Optional,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { Request, Response } from 'express';
import { TelemetryService } from '../monitoring/telemetry.service';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');
  private readonly isJsonLogging =
    process.env.LOG_FORMAT === 'json' || process.env.NODE_ENV === 'production';

  constructor(@Optional() private readonly telemetry?: TelemetryService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const req = http.getRequest<Request>();
    const res = http.getResponse<Response>();

    const method = req.method;
    const url = req.url;
    const requestId = (req as any).requestId || req.headers?.['x-request-id'] || 'no-req-id';
    const startTime = Date.now();

    if (this.telemetry) {
      this.telemetry.requestStarted();
    }

    return next.handle().pipe(
      tap({
        next: () => {
          const duration = Date.now() - startTime;
          const statusCode = res.statusCode;

          if (this.telemetry) {
            this.telemetry.recordHttpRequest(statusCode, duration);
          }

          if (this.isJsonLogging) {
            this.logger.log(
              JSON.stringify({
                timestamp: new Date().toISOString(),
                level: 'info',
                requestId,
                method,
                url,
                statusCode,
                durationMs: duration,
              }),
            );
          } else {
            this.logger.log(`[${requestId}] [${method}] ${url} ${statusCode} +${duration}ms`);
          }
        },
        error: (err: any) => {
          const duration = Date.now() - startTime;
          const statusCode = err?.status || 500;

          if (this.telemetry) {
            this.telemetry.recordHttpRequest(statusCode, duration);
          }

          if (this.isJsonLogging) {
            this.logger.warn(
              JSON.stringify({
                timestamp: new Date().toISOString(),
                level: 'warn',
                requestId,
                method,
                url,
                statusCode,
                durationMs: duration,
                error: err?.message || 'Request failed',
              }),
            );
          } else {
            this.logger.warn(`[${requestId}] [${method}] ${url} failed after +${duration}ms`);
          }
        },
      }),
    );
  }
}

