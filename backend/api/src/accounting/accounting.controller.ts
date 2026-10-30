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
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AccountingService } from './accounting.service';
import { CreateAccountDto } from './dto/create-account.dto';
import { CreateJournalEntryDto } from './dto/create-journal-entry.dto';
import { QueryJournalDto } from './dto/query-journal.dto';
import { QueryReportDto } from './dto/query-report.dto';

@Controller('accounting')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class AccountingController {
  constructor(private readonly accountingService: AccountingService) {}

  @Get('accounts')
  async getAccounts(@CurrentUser('businessId') businessId: string) {
    return this.accountingService.getAccounts(businessId);
  }

  @Post('accounts')
  @Roles('OWNER', 'ADMIN')
  @HttpCode(HttpStatus.CREATED)
  async createAccount(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateAccountDto,
  ) {
    return this.accountingService.createAccount(businessId, dto, userId);
  }

  @Get('journals')
  async getJournalEntries(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryJournalDto,
  ) {
    return this.accountingService.getJournalEntries(businessId, query);
  }

  @Post('journals')
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  @HttpCode(HttpStatus.CREATED)
  async createJournalEntry(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateJournalEntryDto,
  ) {
    return this.accountingService.createJournalEntry(businessId, dto, userId);
  }

  @Get('journals/:id')
  async getJournalEntryById(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
  ) {
    return this.accountingService.getJournalEntryById(businessId, id);
  }

  @Get('reports/trial-balance')
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async getTrialBalance(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryReportDto,
  ) {
    const asOfDate = query.asOfDate ? new Date(query.asOfDate) : undefined;
    return this.accountingService.getTrialBalance(businessId, asOfDate);
  }

  @Get('reports/profit-and-loss')
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async getProfitAndLoss(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryReportDto,
  ) {
    const startDate = query.startDate ? new Date(query.startDate) : undefined;
    const endDate = query.endDate ? new Date(query.endDate) : undefined;
    return this.accountingService.getProfitAndLoss(businessId, startDate, endDate);
  }

  @Get('reports/receivables')
  async getCustomerReceivablesReport(@CurrentUser('businessId') businessId: string) {
    return this.accountingService.getCustomerReceivablesReport(businessId);
  }

  @Get('reports/payables')
  async getSupplierPayablesReport(@CurrentUser('businessId') businessId: string) {
    return this.accountingService.getSupplierPayablesReport(businessId);
  }
}
