import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser, CurrentUserPayload } from '../common/decorators/current-user.decorator';
import { InventoryService } from './inventory.service';
import { CreateStockAdjustmentDto } from './dto/stock-adjustment.dto';
import { QueryInventoryDto } from './dto/query-inventory.dto';

@Controller('api/v1/inventory')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Get('summary')
  async getSummary(@CurrentUser('businessId') businessId: string) {
    return this.inventoryService.getSummary(businessId);
  }

  @Get('products')
  async getProducts(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryInventoryDto,
  ) {
    return this.inventoryService.getProducts(businessId, query);
  }

  @Get('products/:id/movements')
  async getProductMovements(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.inventoryService.getProductMovements(businessId, id, page, limit);
  }

  @Post('adjustments')
  @HttpCode(HttpStatus.CREATED)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async createAdjustment(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateStockAdjustmentDto,
  ) {
    return this.inventoryService.createAdjustment(user.businessId, dto, user.id);
  }
}
