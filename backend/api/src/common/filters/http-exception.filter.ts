import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
  Optional,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { SanitizerUtil } from '../utils/sanitizer.util';
import { TelemetryService } from '../monitoring/telemetry.service';

export interface StructuredErrorResponse {
  statusCode: number;
  error: string;
  message: string | string[];
  timestamp: string;
  path: string;
  requestId?: string;
  details?: unknown;
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('HTTP');
  private readonly isJsonLogging =
    process.env.LOG_FORMAT === 'json' || process.env.NODE_ENV === 'production';

  constructor(@Optional() private readonly telemetry?: TelemetryService) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const requestId = (request as any)?.requestId || (request.headers?.['x-request-id'] as string) || undefined;

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let error = 'Internal Server Error';
    let message: string | string[] = 'An unexpected error occurred';
    let details: unknown = undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();

      if (typeof res === 'string') {
        message = SanitizerUtil.sanitizeString(res);
        error = exception.name;
      } else if (typeof res === 'object' && res !== null) {
        const resObj = res as Record<string, unknown>;
        const rawMsg = (resObj['message'] as string | string[]) || exception.message;
        message = Array.isArray(rawMsg)
          ? rawMsg.map((m) => SanitizerUtil.sanitizeString(m))
          : SanitizerUtil.sanitizeString(rawMsg);
        error = (resObj['error'] as string) || exception.name;
        details = resObj['details'] ? SanitizerUtil.sanitizeObject(resObj['details']) : undefined;
      }
    } else if (exception instanceof Error) {
      const cleanErrorMsg = SanitizerUtil.sanitizeString(exception.message);
      const reqPrefix = requestId ? `[${requestId}] ` : '';
      this.logger.error(`${reqPrefix}Unhandled Exception at ${request.method} ${request.url}: ${cleanErrorMsg}`, exception.stack);

      if (this.telemetry) {
        this.telemetry.captureException(exception, {
          requestId,
          path: request.url,
          method: request.method,
        });
      }

      if (process.env.NODE_ENV === 'production') {
        message = 'Internal server error';
      } else {
        message = cleanErrorMsg;
      }
    }

    const payload: StructuredErrorResponse = {
      statusCode: status,
      error,
      message,
      timestamp: new Date().toISOString(),
      path: request.url,
      ...(requestId ? { requestId } : {}),
      ...(details ? { details } : {}),
    };

    if (this.isJsonLogging) {
      const logPayload = JSON.stringify({
        timestamp: new Date().toISOString(),
        level: status >= 500 ? 'error' : 'warn',
        requestId,
        method: request.method,
        url: request.url,
        statusCode: status,
        error,
        message,
      });
      if (status >= 500) {
        this.logger.error(logPayload);
      } else {
        this.logger.warn(logPayload);
      }
    } else {
      const reqIdPrefix = requestId ? `[${requestId}] ` : '';
      if (status >= 500) {
        this.logger.error(`${reqIdPrefix}[${request.method}] ${request.url} - ${status} - ${JSON.stringify(message)}`);
      } else {
        this.logger.warn(`${reqIdPrefix}[${request.method}] ${request.url} - ${status} - ${JSON.stringify(message)}`);
      }
    }

    response.status(status).json(payload);
  }
}
