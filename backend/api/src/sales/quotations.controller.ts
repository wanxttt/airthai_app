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
import { QuotationsService } from './quotations.service';
import { CreateQuotationDto } from './dto/create-quotation.dto';

@Controller('quotations')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class QuotationsController {
  constructor(private readonly quotationsService: QuotationsService) {}

  @Get()
  async findAll(
    @CurrentUser('businessId') businessId: string,
    @Query('search') search?: string,
    @Query('status') status?: string,
  ) {
    return this.quotationsService.findAll(businessId, search, status);
  }

  @Get(':id')
  async findOne(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
  ) {
    return this.quotationsService.findOne(businessId, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async create(
    @CurrentUser('businessId') businessId: string,
    @Body() dto: CreateQuotationDto,
  ) {
    return this.quotationsService.create(businessId, dto);
  }

  @Post(':id/convert-to-invoice')
  @HttpCode(HttpStatus.CREATED)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async convertToInvoice(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return this.quotationsService.convertToInvoice(user.businessId, id, user.id);
  }
}
