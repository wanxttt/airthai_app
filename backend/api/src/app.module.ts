import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import appConfig from './config/app.config';
import databaseConfig from './config/database.config';
import redisConfig from './config/redis.config';
import storageConfig from './config/storage.config';
import aiConfig from './config/ai.config';
import paymentConfig from './config/payment.config';
import { DatabaseModule } from './database/database.module';
import { CacheModule } from './common/cache/cache.module';
import { MonitoringModule } from './common/monitoring/monitoring.module';
import { WorkersModule } from './workers/workers.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { MasterDataModule } from './master-data/master-data.module';
import { SalesModule } from './sales/sales.module';
import { PurchasesInventoryModule } from './purchases-inventory/purchases-inventory.module';
import { PaymentsExpensesModule } from './payments-expenses/payments-expenses.module';
import { AccountingModule } from './accounting/accounting.module';
import { ReportsModule } from './reports/reports.module';
import { SyncModule } from './sync/sync.module';
import { AuditModule } from './audit/audit.module';
import { NotificationsModule } from './notifications/notifications.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { CopilotModule } from './copilot/copilot.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig, databaseConfig, redisConfig, storageConfig, aiConfig, paymentConfig],
    }),
    DatabaseModule,
    CacheModule,
    MonitoringModule,
    WorkersModule,
    HealthModule,
    AuthModule,
    MasterDataModule,
    SalesModule,
    PurchasesInventoryModule,
    PaymentsExpensesModule,
    AccountingModule,
    ReportsModule,
    SyncModule,
    AuditModule,
    NotificationsModule,
    SubscriptionsModule,
    CopilotModule,
  ],
})
export class AppModule {}
