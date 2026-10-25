import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { AccountingService } from './accounting.service';
import { GstService } from './gst.service';
import { AccountingController } from './accounting.controller';
import { GstController } from './gst.controller';
import { SequenceService } from '../sales/sequence.service';

@Module({
  imports: [DatabaseModule],
  controllers: [AccountingController, GstController],
  providers: [AccountingService, GstService, SequenceService],
  exports: [AccountingService, GstService],
})
export class AccountingModule {}
