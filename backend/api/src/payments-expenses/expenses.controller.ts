import {
  Body,
  Controller,
  Delete,
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
import { ExpensesService } from './expenses.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { CreateExpenseCategoryDto } from './dto/create-expense-category.dto';
import { QueryExpensesDto } from './dto/query-expenses.dto';

@Controller('expenses')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Get('categories')
  async getCategories(@CurrentUser('businessId') businessId: string) {
    return this.expensesService.getCategories(businessId);
  }

  @Post('categories')
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  @HttpCode(HttpStatus.CREATED)
  async createCategory(
    @CurrentUser('businessId') businessId: string,
    @Body() dto: CreateExpenseCategoryDto,
  ) {
    return this.expensesService.createCategory(businessId, dto);
  }

  @Get('summary')
  async getExpenseSummary(
    @CurrentUser('businessId') businessId: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.expensesService.getExpenseSummary(businessId, { startDate, endDate });
  }

  @Post()
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  @HttpCode(HttpStatus.CREATED)
  async createExpense(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateExpenseDto,
  ) {
    return this.expensesService.createExpense(businessId, dto, userId);
  }

  @Get()
  async getExpenses(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryExpensesDto,
  ) {
    return this.expensesService.getExpenses(businessId, query);
  }

  @Get(':id')
  async getExpenseById(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
  ) {
    return this.expensesService.getExpenseById(businessId, id);
  }

  @Delete(':id')
  @Roles('OWNER', 'ADMIN')
  @HttpCode(HttpStatus.OK)
  async deleteExpense(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
  ) {
    return this.expensesService.deleteExpense(businessId, id, userId);
  }
}
