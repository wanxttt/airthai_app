import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { AccountingModule } from '../accounting/accounting.module';
import { DashboardController } from './dashboard.controller';
import { DashboardService } from './dashboard.service';
import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';

@Module({
  imports: [DatabaseModule, AccountingModule],
  controllers: [DashboardController, ReportsController],
  providers: [DashboardService, ReportsService],
  exports: [DashboardService, ReportsService],
})
export class ReportsModule {}

