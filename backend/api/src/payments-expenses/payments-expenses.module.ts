import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { SalesModule } from '../sales/sales.module';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { ExpensesService } from './expenses.service';
import { ExpensesController } from './expenses.controller';

@Module({
  imports: [DatabaseModule, SalesModule],
  controllers: [PaymentsController, ExpensesController],
  providers: [PaymentsService, ExpensesService],
  exports: [PaymentsService, ExpensesService],
})
export class PaymentsExpensesModule {}
