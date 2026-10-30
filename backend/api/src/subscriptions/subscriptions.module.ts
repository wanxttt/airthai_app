import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { AuditModule } from '../audit/audit.module';
import { SubscriptionsController } from './subscriptions.controller';
import { SubscriptionsService } from './subscriptions.service';
import { RazorpayPaymentProvider } from './payment-provider/razorpay-payment.provider';

@Module({
  imports: [DatabaseModule, AuditModule],
  controllers: [SubscriptionsController],
  providers: [SubscriptionsService, RazorpayPaymentProvider],
  exports: [SubscriptionsService, RazorpayPaymentProvider],
})
export class SubscriptionsModule {}
