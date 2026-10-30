import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { SalesModule } from '../sales/sales.module';
import { PurchasesInventoryModule } from '../purchases-inventory/purchases-inventory.module';
import { PaymentsExpensesModule } from '../payments-expenses/payments-expenses.module';
import { MasterDataModule } from '../master-data/master-data.module';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';

@Module({
  imports: [
    DatabaseModule,
    SalesModule,
    PurchasesInventoryModule,
    PaymentsExpensesModule,
    MasterDataModule,
  ],
  controllers: [SyncController],
  providers: [SyncService],
  exports: [SyncService],
})
export class SyncModule {}

