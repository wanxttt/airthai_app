import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import appConfig from './config/app.config';
import databaseConfig from './config/database.config';
import redisConfig from './config/redis.config';
import storageConfig from './config/storage.config';
import aiConfig from './config/ai.config';
import { DatabaseModule } from './database/database.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { MasterDataModule } from './master-data/master-data.module';
import { SalesModule } from './sales/sales.module';
import { PurchasesInventoryModule } from './purchases-inventory/purchases-inventory.module';
import { PaymentsExpensesModule } from './payments-expenses/payments-expenses.module';
import { AccountingModule } from './accounting/accounting.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig, databaseConfig, redisConfig, storageConfig, aiConfig],
    }),
    DatabaseModule,
    HealthModule,
    AuthModule,
    MasterDataModule,
    SalesModule,
    PurchasesInventoryModule,
    PaymentsExpensesModule,
    AccountingModule,
  ],
})
export class AppModule {}
