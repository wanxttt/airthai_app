import { Injectable, Logger } from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaService } from './prisma.service';

@Injectable()
export class TransactionService {
  private readonly logger = new Logger(TransactionService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Executes an operation inside an interactive Prisma database transaction.
   * If any step throws an error, all mutations within the transaction are rolled back.
   */
  async runInTransaction<T>(
    fn: (tx: Prisma.TransactionClient) => Promise<T>,
    options?: { maxWait?: number; timeout?: number },
  ): Promise<T> {
    try {
      return await this.prisma.$transaction(
        async (tx) => {
          return await fn(tx);
        },
        {
          maxWait: options?.maxWait ?? 5000,
          timeout: options?.timeout ?? 10000,
        },
      );
    } catch (error) {
      this.logger.error(`Transaction failed and was rolled back: ${(error as Error).message}`);
      throw error;
    }
  }
}

