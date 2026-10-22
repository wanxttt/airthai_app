import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';
import { DatabaseHealthService } from './database-health.service';
import { TransactionService } from './transaction.service';

@Global()
@Module({
  providers: [PrismaService, DatabaseHealthService, TransactionService],
  exports: [PrismaService, DatabaseHealthService, TransactionService],
})
export class DatabaseModule {}

