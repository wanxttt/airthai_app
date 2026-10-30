import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { CopilotController } from './copilot.controller';
import { CopilotService } from './copilot.service';
import { AiProviderService } from './ai-provider.service';

@Module({
  imports: [DatabaseModule],
  controllers: [CopilotController],
  providers: [CopilotService, AiProviderService],
  exports: [CopilotService, AiProviderService],
})
export class CopilotModule {}

