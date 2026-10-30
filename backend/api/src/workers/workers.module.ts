import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PdfGeneratorService } from './pdf-generator.service';
import { WorkerQueueService } from './worker-queue.service';

@Global()
@Module({
  imports: [ConfigModule],
  providers: [PdfGeneratorService, WorkerQueueService],
  exports: [PdfGeneratorService, WorkerQueueService],
})
export class WorkersModule {}

