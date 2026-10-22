import { Controller, Get, HttpStatus, Res } from '@nestjs/common';
import { Response } from 'express';
import { DatabaseHealthService } from '../database/database-health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly dbHealth: DatabaseHealthService) {}

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

    const statusCode = isReady ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE;
    res.status(statusCode).json({
      status: isReady ? 'ready' : 'degraded',
      timestamp: new Date().toISOString(),
      services: {
        database: dbResult,
      },
    });
  }
}

