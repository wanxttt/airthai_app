import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { CurrentUser, CurrentUserPayload } from '../common/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { SyncService } from './sync.service';
import { SyncBatchDto, SyncPullDto } from './dto/sync-batch.dto';

@Controller('sync')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Get('status')
  getStatus() {
    return {
      status: 'OK',
      timestamp: new Date().toISOString(),
      service: 'AirthAI Reliable Sync Protocol',
    };
  }

  @Post('batch')
  @HttpCode(HttpStatus.OK)
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async processBatch(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: SyncBatchDto,
  ) {
    const results = await this.syncService.processBatch(user.businessId, dto, user.id, user.role);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: results,
    };
  }

  @Post('pull')
  @HttpCode(HttpStatus.OK)
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async pullChanges(
    @CurrentUser('businessId') businessId: string,
    @Body() dto: SyncPullDto,
  ) {
    const changes = await this.syncService.pullChanges(businessId, dto);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: changes,
    };
  }
}
