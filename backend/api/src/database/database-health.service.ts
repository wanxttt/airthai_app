import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from './prisma.service';

export interface DatabaseHealthResult {
  status: 'up' | 'down';
  latencyMs?: number;
  message?: string;
  timestamp: string;
}

@Injectable()
export class DatabaseHealthService {
  private readonly logger = new Logger(DatabaseHealthService.name);

  constructor(private readonly prisma: PrismaService) {}

  async checkHealth(): Promise<DatabaseHealthResult> {
    const start = Date.now();
    try {
      // Execute a lightweight query to verify connectivity
      await this.prisma.$queryRawUnsafe('SELECT 1');
      const latencyMs = Date.now() - start;

      return {
        status: 'up',
        latencyMs,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      const latencyMs = Date.now() - start;
      const safeMessage = (error as Error).message || 'Database connection error';
      this.logger.error(`Database health check failed: ${safeMessage}`);

      return {
        status: 'down',
        latencyMs,
        message: 'Database service unreachable',
        timestamp: new Date().toISOString(),
      };
    }
  }
}

