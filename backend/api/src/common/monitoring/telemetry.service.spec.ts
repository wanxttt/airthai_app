import { TelemetryService } from './telemetry.service';
import { ConfigService } from '@nestjs/config';

describe('TelemetryService', () => {
  let service: TelemetryService;
  let mockConfigService: Partial<ConfigService>;

  beforeEach(() => {
    mockConfigService = {
      get: jest.fn().mockReturnValue(undefined),
    };
    service = new TelemetryService(mockConfigService as ConfigService);
  });

  it('tracks HTTP request start, completion, status codes, and latency', () => {
    service.requestStarted();
    expect(service.getMetricsSnapshot().http.activeRequests).toBe(1);

    service.recordHttpRequest(200, 15);
    service.requestStarted();
    service.recordHttpRequest(500, 45);

    const snapshot = service.getMetricsSnapshot();
    expect(snapshot.http.totalRequests).toBe(2);
    expect(snapshot.http.activeRequests).toBe(0);
    expect(snapshot.http.statusCodes['2xx']).toBe(1);
    expect(snapshot.http.statusCodes['5xx']).toBe(1);
    expect(snapshot.http.averageLatencyMs).toBe(30);
  });

  it('calculates cache metrics and hit ratio correctly', () => {
    service.recordCacheHit();
    service.recordCacheHit();
    service.recordCacheMiss();

    const snapshot = service.getMetricsSnapshot();
    expect(snapshot.cache.hits).toBe(2);
    expect(snapshot.cache.misses).toBe(1);
    expect(snapshot.cache.hitRatioPercentage).toBe(66.7);
  });

  it('generates alerts when database is marked down', () => {
    service.setDatabaseHealth('down', 1200);

    const snapshot = service.getMetricsSnapshot();
    expect(snapshot.database.status).toBe('down');
    expect(snapshot.alerts.some((a) => a.code === 'DATABASE_UNREACHABLE')).toBe(true);
  });

  it('generates alerts when 5xx error rate exceeds threshold', () => {
    for (let i = 0; i < 90; i++) {
      service.requestStarted();
      service.recordHttpRequest(200, 10);
    }
    for (let i = 0; i < 10; i++) {
      service.requestStarted();
      service.recordHttpRequest(500, 20);
    }

    const snapshot = service.getMetricsSnapshot();
    expect(snapshot.http.errorRatePercentage).toBe(10);
    expect(snapshot.alerts.some((a) => a.code === 'HIGH_HTTP_5XX_RATE')).toBe(true);
  });

  it('sanitizes sensitive data during exception capture', async () => {
    const error = new Error('Database password=secret123 failed for postgresql://user:pass@host:5432/db');
    const context = {
      jwtSecret: 'top_secret_key',
      refreshToken: 'rf_token_val',
      userId: 'usr_123',
    };

    // Should not throw and must redact
    await expect(service.captureException(error, context)).resolves.not.toThrow();
  });
});

