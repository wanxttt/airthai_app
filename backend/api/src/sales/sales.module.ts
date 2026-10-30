import { Module } from '@nestjs/common';
import { InvoicesController } from './invoices.controller';
import { InvoicesService } from './invoices.service';
import { QuotationsController } from './quotations.controller';
import { QuotationsService } from './quotations.service';
import { SequenceService } from './sequence.service';

import { SubscriptionsModule } from '../subscriptions/subscriptions.module';

@Module({
  imports: [SubscriptionsModule],
  controllers: [InvoicesController, QuotationsController],
  providers: [InvoicesService, QuotationsService, SequenceService],
  exports: [InvoicesService, QuotationsService, SequenceService],
})
export class SalesModule {}
