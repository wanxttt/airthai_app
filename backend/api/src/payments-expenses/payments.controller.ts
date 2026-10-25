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
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PaymentsService } from './payments.service';
import { CreatePaymentDto, VoidPaymentDto } from './dto/create-payment.dto';
import { QueryPaymentsDto } from './dto/query-payments.dto';

@Controller('api/v1/payments')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('receipts')
  @HttpCode(HttpStatus.CREATED)
  async recordCustomerReceipt(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreatePaymentDto,
  ) {
    return this.paymentsService.recordCustomerReceipt(businessId, dto, userId);
  }

  @Post('supplier-payments')
  @HttpCode(HttpStatus.CREATED)
  async recordSupplierPayment(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreatePaymentDto,
  ) {
    return this.paymentsService.recordSupplierPayment(businessId, dto, userId);
  }

  @Get()
  async getPayments(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryPaymentsDto,
  ) {
    return this.paymentsService.getPayments(businessId, query);
  }

  @Get('outstanding/customer/:customerId')
  async getCustomerOutstanding(
    @CurrentUser('businessId') businessId: string,
    @Param('customerId') customerId: string,
  ) {
    return this.paymentsService.getCustomerOutstanding(businessId, customerId);
  }

  @Get('outstanding/supplier/:supplierId')
  async getSupplierOutstanding(
    @CurrentUser('businessId') businessId: string,
    @Param('supplierId') supplierId: string,
  ) {
    return this.paymentsService.getSupplierOutstanding(businessId, supplierId);
  }

  @Get(':id')
  async getPaymentById(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
  ) {
    return this.paymentsService.getPaymentById(businessId, id);
  }

  @Post(':id/void')
  @HttpCode(HttpStatus.OK)
  async voidPayment(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: VoidPaymentDto,
  ) {
    return this.paymentsService.voidPayment(businessId, id, dto, userId);
  }
}
