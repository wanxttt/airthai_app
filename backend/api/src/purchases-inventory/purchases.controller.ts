import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser, CurrentUserPayload } from '../common/decorators/current-user.decorator';
import { PurchasesService } from './purchases.service';
import { CreatePurchaseDto } from './dto/create-purchase.dto';
import { QueryPurchasesDto } from './dto/query-purchases.dto';
import { CancelPurchaseDto } from './dto/cancel-purchase.dto';

@Controller('api/v1/purchases')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class PurchasesController {
  constructor(private readonly purchasesService: PurchasesService) {}

  @Get()
  async findAll(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryPurchasesDto,
  ) {
    return this.purchasesService.findAll(businessId, query);
  }

  @Get(':id')
  async findOne(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
  ) {
    return this.purchasesService.findOne(businessId, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async create(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreatePurchaseDto,
  ) {
    return this.purchasesService.create(user.businessId, dto, user.id);
  }

  @Patch(':id/receive')
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async receive(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return this.purchasesService.receive(user.businessId, id, user.id);
  }

  @Patch(':id/cancel')
  @Roles('OWNER', 'ADMIN')
  async cancel(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
    @Body() dto: CancelPurchaseDto,
  ) {
    return this.purchasesService.cancel(user.businessId, id, dto, user.id);
  }
}
