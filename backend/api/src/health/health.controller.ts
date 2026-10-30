import { Controller, Get, HttpStatus, Optional, Res } from '@nestjs/common';
import { Response } from 'express';
import { DatabaseHealthService } from '../database/database-health.service';
import { TelemetryService, MetricsSnapshot } from '../common/monitoring/telemetry.service';

@Controller('health')
export class HealthController {
  constructor(
    private readonly dbHealth: DatabaseHealthService,
    @Optional() private readonly telemetry?: TelemetryService,
  ) {}

  @Get()
  getLiveness(): Record<string, unknown> {
    return {
      status: 'ok',
      service: 'airthai-backend-api',
      version: '0.1.0',
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
    };
  }

  @Get('ready')
  async getReadiness(@Res() res: Response): Promise<void> {
    const dbResult = await this.dbHealth.checkHealth();
    const isReady = dbResult.status === 'up';

    if (this.telemetry) {
      this.telemetry.setDatabaseHealth(dbResult.status, dbResult.latencyMs || 0);
    }

    const statusCode = isReady ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE;
    res.status(statusCode).json({
      status: isReady ? 'ready' : 'degraded',
      timestamp: new Date().toISOString(),
      services: {
        database: dbResult,
      },
    });
  }

  @Get('metrics')
  getMetrics(): MetricsSnapshot | Record<string, unknown> {
    if (this.telemetry) {
      return this.telemetry.getMetricsSnapshot();
    }
    return {
      status: 'ok',
      service: 'airthai-backend-api',
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }
}

