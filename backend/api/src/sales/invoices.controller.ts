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
import { InvoicesService } from './invoices.service';
import { CreateInvoiceDto } from './dto/create-invoice.dto';
import { QueryInvoicesDto } from './dto/query-invoices.dto';
import { CancelInvoiceDto } from './dto/cancel-invoice.dto';

@Controller('api/v1/invoices')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class InvoicesController {
  constructor(private readonly invoicesService: InvoicesService) {}

  @Get()
  async findAll(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryInvoicesDto,
  ) {
    return this.invoicesService.findAll(businessId, query);
  }

  @Get(':id')
  async findOne(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
  ) {
    return this.invoicesService.findOne(businessId, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async create(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateInvoiceDto,
  ) {
    return this.invoicesService.create(user.businessId, dto, user.id);
  }

  @Patch(':id/cancel')
  @Roles('OWNER', 'ADMIN')
  async cancel(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
    @Body() dto: CancelInvoiceDto,
  ) {
    return this.invoicesService.cancel(user.businessId, id, dto, user.id);
  }
}
