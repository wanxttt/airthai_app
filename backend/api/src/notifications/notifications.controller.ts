import {
  Controller,
  Get,
  Patch,
  Post,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { NotificationsService } from './notifications.service';
import { QueryNotificationsDto } from './dto/query-notifications.dto';

@Controller('notifications')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async getNotifications(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryNotificationsDto,
  ) {
    const result = await this.notificationsService.getNotifications(businessId, query);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: result,
    };
  }

  @Get('unread-count')
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async getUnreadCount(@CurrentUser('businessId') businessId: string) {
    const count = await this.notificationsService.getUnreadCount(businessId);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: { unreadCount: count },
    };
  }

  @Patch(':id/read')
  @HttpCode(HttpStatus.OK)
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async markAsRead(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
  ) {
    const updated = await this.notificationsService.markAsRead(businessId, id);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: updated,
    };
  }

  @Post('mark-all-read')
  @HttpCode(HttpStatus.OK)
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async markAllAsRead(@CurrentUser('businessId') businessId: string) {
    const result = await this.notificationsService.markAllAsRead(businessId);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: result,
    };
  }

  @Post('scan')
  @HttpCode(HttpStatus.OK)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async scanAlerts(@CurrentUser('businessId') businessId: string) {
    const [lowStock, overdue] = await Promise.all([
      this.notificationsService.scanLowStockAlerts(businessId),
      this.notificationsService.scanOverdueInvoices(businessId),
    ]);

    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: {
        lowStock,
        overdue,
      },
    };
  }
}

