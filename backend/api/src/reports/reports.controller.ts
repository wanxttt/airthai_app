import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ReportsService } from './reports.service';
import { AccountingService } from '../accounting/accounting.service';
import {
  QueryAgeingReportDto,
  QueryExpensesReportDto,
  QueryPaymentsReportDto,
  QueryProductPerformanceDto,
  QueryPurchasesReportDto,
  QuerySalesReportDto,
  QueryStockMovementReportDto,
  QueryStockReportDto,
} from './dto/query-reports.dto';

@Controller('reports')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class ReportsController {
  constructor(
    private readonly reportsService: ReportsService,
    private readonly accountingService: AccountingService,
  ) {}

  @Get('sales')
  async getSalesReport(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QuerySalesReportDto,
  ) {
    return this.reportsService.getSalesReport(businessId, query);
  }

  @Get('purchases')
  async getPurchasesReport(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryPurchasesReportDto,
  ) {
    return this.reportsService.getPurchasesReport(businessId, query);
  }

  @Get('expenses')
  async getExpensesReport(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryExpensesReportDto,
  ) {
    return this.reportsService.getExpensesReport(businessId, query);
  }

  @Get('payments')
  async getPaymentsReport(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryPaymentsReportDto,
  ) {
    return this.reportsService.getPaymentsReport(businessId, query);
  }

  @Get('receivables-ageing')
  async getReceivablesAgeing(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryAgeingReportDto,
  ) {
    return this.reportsService.getReceivablesAgeingReport(businessId, query);
  }

  @Get('payables-ageing')
  async getPayablesAgeing(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryAgeingReportDto,
  ) {
    return this.reportsService.getPayablesAgeingReport(businessId, query);
  }

  @Get('stock-summary')
  async getStockSummary(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryStockReportDto,
  ) {
    return this.reportsService.getStockSummaryReport(businessId, query);
  }

  @Get('stock-movements')
  async getStockMovements(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryStockMovementReportDto,
  ) {
    return this.reportsService.getStockMovementReport(businessId, query);
  }

  @Get('product-performance')
  async getProductPerformance(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryProductPerformanceDto,
  ) {
    return this.reportsService.getProductPerformanceReport(businessId, query);
  }

  @Get('gst-summary')
  async getGstSummary(
    @CurrentUser('businessId') businessId: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.reportsService.getGstSummaryReport(businessId, startDate, endDate);
  }

  @Get('profit-and-loss')
  async getProfitAndLoss(
    @CurrentUser('businessId') businessId: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    const start = startDate ? new Date(startDate) : undefined;
    const end = endDate ? new Date(endDate) : undefined;
    return this.accountingService.getProfitAndLoss(businessId, start, end);
  }

  @Get('trial-balance')
  async getTrialBalance(
    @CurrentUser('businessId') businessId: string,
    @Query('asOfDate') asOfDate?: string,
  ) {
    const asOf = asOfDate ? new Date(asOfDate) : undefined;
    return this.accountingService.getTrialBalance(businessId, asOf);
  }
}

