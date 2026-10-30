import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  HttpStatus,
  HttpCode,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { CopilotService } from './copilot.service';
import { AiProviderService } from './ai-provider.service';
import { QueryCopilotDto } from './dto/query-copilot.dto';

@Controller('copilot')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class CopilotController {
  constructor(
    private readonly copilotService: CopilotService,
    private readonly aiProvider: AiProviderService,
  ) {}

  @Get('status')
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  getStatus() {
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: {
        isAvailable: this.copilotService.isAvailable(),
        model: this.aiProvider.getModelName(),
        mode: 'READ_ONLY',
      },
    };
  }

  @Get('suggestions')
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  getSuggestions() {
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: this.copilotService.getSuggestions(),
    };
  }

  @Post('query')
  @HttpCode(HttpStatus.OK)
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async query(
    @CurrentUser('businessId') businessId: string,
    @Body() queryDto: QueryCopilotDto,
  ) {
    const result = await this.copilotService.query(businessId, queryDto);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: result,
    };
  }
}
