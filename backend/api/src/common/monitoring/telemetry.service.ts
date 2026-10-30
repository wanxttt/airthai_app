import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as https from 'https';
import { SanitizerUtil } from '../utils/sanitizer.util';

export interface HttpMetricsSummary {
  totalRequests: number;
  activeRequests: number;
  statusCodes: {
    '2xx': number;
    '3xx': number;
    '4xx': number;
    '5xx': number;
  };
  errorRatePercentage: number;
  averageLatencyMs: number;
  p95LatencyMs: number;
}

export interface CacheMetricsSummary {
  hits: number;
  misses: number;
  fallbacks: number;
  errors: number;
  hitRatioPercentage: number;
}

export interface WorkerMetricsSummary {
  enqueued: number;
  completed: number;
  failed: number;
  inFlight: number;
}

export interface DatabaseMetricsSummary {
  status: 'up' | 'down';
  latencyMs: number;
  lastChecked: string;
}

export interface SystemAlert {
  level: 'INFO' | 'WARNING' | 'CRITICAL';
  code: string;
  message: string;
  timestamp: string;
}

export interface MetricsSnapshot {
  service: string;
  uptimeSeconds: number;
  timestamp: string;
  http: HttpMetricsSummary;
  cache: CacheMetricsSummary;
  workerQueue: WorkerMetricsSummary;
  database: DatabaseMetricsSummary;
  alerts: SystemAlert[];
}

@Injectable()
export class TelemetryService {
  private readonly logger = new Logger(TelemetryService.name);
  private readonly sentryDsn?: string;

  // HTTP Metrics State
  private totalRequests = 0;
  private activeRequests = 0;
  private status2xx = 0;
  private status3xx = 0;
  private status4xx = 0;
  private status5xx = 0;
  private readonly latencies: number[] = [];
  private static readonly MAX_LATENCY_SAMPLES = 500;

  // Cache Metrics State
  private cacheHits = 0;
  private cacheMisses = 0;
  private cacheFallbacks = 0;
  private cacheErrors = 0;

  // Worker Queue State
  private jobsEnqueued = 0;
  private jobsCompleted = 0;
  private jobsFailed = 0;

  // Database State
  private dbStatus: 'up' | 'down' = 'up';
  private dbLatencyMs = 0;
  private dbLastChecked = new Date().toISOString();

  constructor(private readonly configService: ConfigService) {
    this.sentryDsn = this.configService.get<string>('SENTRY_DSN');
    if (this.sentryDsn) {
      this.logger.log('Telemetry initialized with Sentry APM integration.');
    } else {
      this.logger.log('Telemetry initialized with high-performance in-memory metrics.');
    }
  }

  // --- HTTP METRICS ---

  requestStarted(): void {
    this.totalRequests++;
    this.activeRequests++;
  }

  recordHttpRequest(statusCode: number, durationMs: number): void {
    if (this.activeRequests > 0) this.activeRequests--;

    if (statusCode >= 200 && statusCode < 300) {
      this.status2xx++;
    } else if (statusCode >= 300 && statusCode < 400) {
      this.status3xx++;
    } else if (statusCode >= 400 && statusCode < 500) {
      this.status4xx++;
    } else if (statusCode >= 500) {
      this.status5xx++;
    }

    if (this.latencies.length >= TelemetryService.MAX_LATENCY_SAMPLES) {
      this.latencies.shift();
    }
    this.latencies.push(durationMs);
  }

  // --- CACHE METRICS ---

  recordCacheHit(): void {
    this.cacheHits++;
  }

  recordCacheMiss(): void {
    this.cacheMisses++;
  }

  recordCacheFallback(): void {
    this.cacheFallbacks++;
  }

  recordCacheError(): void {
    this.cacheErrors++;
  }

  // --- WORKER QUEUE METRICS ---

  recordJobEnqueued(): void {
    this.jobsEnqueued++;
  }

  recordJobCompleted(): void {
    this.jobsCompleted++;
  }

  recordJobFailed(): void {
    this.jobsFailed++;
  }

  // --- DATABASE METRICS ---

  setDatabaseHealth(status: 'up' | 'down', latencyMs: number): void {
    this.dbStatus = status;
    this.dbLatencyMs = latencyMs;
    this.dbLastChecked = new Date().toISOString();
  }

  // --- SENTRY / APM EXCEPTION TRACKING ---

  async captureException(error: Error, context?: Record<string, unknown>): Promise<void> {
    const cleanMessage = SanitizerUtil.sanitizeString(error.message);
    const cleanStack = SanitizerUtil.sanitizeString(error.stack || '');
    const cleanContext = context ? SanitizerUtil.sanitizeObject(context) : {};

    // Emit structured JSON telemetry event
    this.logger.error(
      JSON.stringify({
        event: 'APPLICATION_EXCEPTION',
        timestamp: new Date().toISOString(),
        errorName: error.name,
        message: cleanMessage,
        context: cleanContext,
        stack: cleanStack.split('\n').slice(0, 5),
      }),
    );

    // If Sentry DSN configured, deliver sanitized event
    if (this.sentryDsn) {
      await this.dispatchToSentry(cleanMessage, error.name, cleanContext, cleanStack);
    }
  }

  private async dispatchToSentry(
    message: string,
    name: string,
    context: Record<string, unknown>,
    stack: string,
  ): Promise<void> {
    try {
      if (!this.sentryDsn) return;
      const url = new URL(this.sentryDsn);
      const projectId = url.pathname.replace(/^\//, '');
      const publicKey = url.username;

      const eventPayload = JSON.stringify({
        event_id: Math.random().toString(36).substring(2, 18),
        timestamp: new Date().toISOString(),
        platform: 'node',
        level: 'error',
        logger: 'airthai-backend',
        exception: {
          values: [
            {
              type: name,
              value: message,
              stacktrace: { frames: [] },
            },
          ],
        },
        extra: context,
      });

      const options = {
        hostname: url.hostname,
        port: url.port || 443,
        path: `/api/${projectId}/store/`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Sentry-Auth': `Sentry sentry_version=7, sentry_client=airthai/1.0.0, sentry_key=${publicKey}`,
          'Content-Length': Buffer.byteLength(eventPayload),
        },
        timeout: 3000,
      };

      const req = https.request(options);
      req.on('error', () => {
        // Silently tolerate upstream Sentry network issues
      });
      req.write(eventPayload);
      req.end();
    } catch {
      // Never throw from telemetry dispatch
    }
  }

  // --- SNAPSHOT & ALERTS ---

  getMetricsSnapshot(): MetricsSnapshot {
    const totalRequests = Math.max(1, this.totalRequests);
    const errorCount = this.status5xx;
    const errorRatePercentage = Number(((errorCount / totalRequests) * 100).toFixed(2));

    const avgLatency =
      this.latencies.length > 0
        ? Math.round(this.latencies.reduce((a, b) => a + b, 0) / this.latencies.length)
        : 0;

    const sortedLatencies = [...this.latencies].sort((a, b) => a - b);
    const p95Index = Math.floor(sortedLatencies.length * 0.95);
    const p95Latency = sortedLatencies.length > 0 ? sortedLatencies[p95Index] : 0;

    const totalCacheOps = this.cacheHits + this.cacheMisses;
    const hitRatio =
      totalCacheOps > 0 ? Number(((this.cacheHits / totalCacheOps) * 100).toFixed(1)) : 100.0;

    const alerts: SystemAlert[] = [];
    const now = new Date().toISOString();

    if (this.dbStatus === 'down') {
      alerts.push({
        level: 'CRITICAL',
        code: 'DATABASE_UNREACHABLE',
        message: 'Primary PostgreSQL database connection is down or failing readiness check.',
        timestamp: now,
      });
    }

    if (errorRatePercentage > 5.0) {
      alerts.push({
        level: 'WARNING',
        code: 'HIGH_HTTP_5XX_RATE',
        message: `HTTP 5xx error rate is elevated at ${errorRatePercentage}%.`,
        timestamp: now,
      });
    }

    if (this.cacheFallbacks > 0 || this.cacheErrors > 0) {
      alerts.push({
        level: 'WARNING',
        code: 'CACHE_DEGRADATION',
        message: `Cache operations encountered ${this.cacheFallbacks} fallbacks and ${this.cacheErrors} errors.`,
        timestamp: now,
      });
    }

    if (this.jobsFailed > 5) {
      alerts.push({
        level: 'WARNING',
        code: 'WORKER_FAILURES_ELEVATED',
        message: `Worker queue has recorded ${this.jobsFailed} failed background jobs.`,
        timestamp: now,
      });
    }

    return {
      service: 'airthai-backend-api',
      uptimeSeconds: Math.floor(process.uptime()),
      timestamp: now,
      http: {
        totalRequests: this.totalRequests,
        activeRequests: this.activeRequests,
        statusCodes: {
          '2xx': this.status2xx,
          '3xx': this.status3xx,
          '4xx': this.status4xx,
          '5xx': this.status5xx,
        },
        errorRatePercentage,
        averageLatencyMs: avgLatency,
        p95LatencyMs: p95Latency,
      },
      cache: {
        hits: this.cacheHits,
        misses: this.cacheMisses,
        fallbacks: this.cacheFallbacks,
        errors: this.cacheErrors,
        hitRatioPercentage: hitRatio,
      },
      workerQueue: {
        enqueued: this.jobsEnqueued,
        completed: this.jobsCompleted,
        failed: this.jobsFailed,
        inFlight: Math.max(0, this.jobsEnqueued - this.jobsCompleted - this.jobsFailed),
      },
      database: {
        status: this.dbStatus,
        latencyMs: this.dbLatencyMs,
        lastChecked: this.dbLastChecked,
      },
      alerts,
    };
  }
}

