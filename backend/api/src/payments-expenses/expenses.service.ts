import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  Logger,
  Optional,
} from '@nestjs/common';
import { AccountingService } from '../accounting/accounting.service';
import { PrismaService } from '../database/prisma.service';
import { SequenceService } from '../sales/sequence.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { CreateExpenseCategoryDto } from './dto/create-expense-category.dto';
import { QueryExpensesDto } from './dto/query-expenses.dto';
import { Prisma } from '@prisma/client';

const DEFAULT_CATEGORIES = [
  'Rent',
  'Utilities & Electricity',
  'Salaries & Wages',
  'Office Supplies',
  'Travel & Logistics',
  'Repairs & Maintenance',
  'Marketing & Advertising',
  'Professional Fees',
  'Miscellaneous',
];

@Injectable()
export class ExpensesService {
  private readonly logger = new Logger(ExpensesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
    @Optional() private readonly accountingService?: AccountingService,
  ) {}

  /**
   * Retrieve all expense categories for a business.
   * Auto-seeds standard default categories if none exist yet.
   */
  async getCategories(businessId: string) {
    const existing = await this.prisma.expenseCategory.findMany({
      where: { businessId },
      orderBy: { name: 'asc' },
    });

    if (existing.length === 0) {
      await this.prisma.expenseCategory.createMany({
        data: DEFAULT_CATEGORIES.map((name) => ({
          businessId,
          name,
        })),
        skipDuplicates: true,
      });

      return this.prisma.expenseCategory.findMany({
        where: { businessId },
        orderBy: { name: 'asc' },
      });
    }

    return existing;
  }

  /**
   * Create a new custom expense category.
   */
  async createCategory(businessId: string, dto: CreateExpenseCategoryDto) {
    const trimmedName = dto.name.trim();

    const existing = await this.prisma.expenseCategory.findUnique({
      where: { businessId_name: { businessId, name: trimmedName } },
    });
    if (existing) {
      throw new ConflictException(`Expense category '${trimmedName}' already exists.`);
    }

    return this.prisma.expenseCategory.create({
      data: {
        businessId,
        name: trimmedName,
      },
    });
  }

  /**
   * Record a new expense.
   * Generates sequential EXP number, validates category, and logs audit record.
   */
  async createExpense(businessId: string, dto: CreateExpenseDto, userId?: string) {
    const amount = new Prisma.Decimal(dto.amount);
    if (amount.lte(0)) {
      throw new BadRequestException('Expense amount must be greater than zero.');
    }

    const gstAmount = dto.gstAmount ? new Prisma.Decimal(dto.gstAmount) : new Prisma.Decimal(0);
    if (gstAmount.gt(amount)) {
      throw new BadRequestException('GST amount cannot exceed total expense amount.');
    }

    return this.prisma.$transaction(async (tx) => {
      // Validate Category
      const category = await tx.expenseCategory.findUnique({
        where: { businessId_id: { businessId, id: dto.categoryId } },
      });
      if (!category) {
        throw new NotFoundException(`Expense category with ID ${dto.categoryId} not found.`);
      }

      // Generate Sequence
      const expenseDate = new Date(dto.date);
      const expenseNumber = await this.sequenceService.getNextNumber(
        businessId,
        'EXPENSE',
        'EXP',
        expenseDate,
        tx,
      );

      // Create Expense
      const expense = await tx.expense.create({
        data: {
          businessId,
          categoryId: dto.categoryId,
          branchId: dto.branchId || null,
          expenseNumber,
          date: expenseDate,
          amount,
          paymentMethod: dto.paymentMethod,
          vendor: dto.vendor?.trim() || null,
          gstin: dto.gstin?.trim() || null,
          gstAmount,
          isTaxDeductible: dto.isTaxDeductible ?? true,
          receiptUrl: dto.receiptUrl?.trim() || null,
          notes: dto.notes?.trim() || null,
        },
        include: {
          category: { select: { id: true, name: true } },
        },
      });

      // Audit Log
      if (this.accountingService && !expense.amount.isZero()) {
        await this.accountingService.postExpenseJournal(businessId, expense, tx);
      }

      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'CREATE_EXPENSE',
          entityName: 'Expense',
          entityId: expense.id,
          newValues: {
            expenseNumber,
            categoryId: dto.categoryId,
            categoryName: category.name,
            amount: amount.toNumber(),
            paymentMethod: dto.paymentMethod,
            vendor: dto.vendor,
          },
        },
      });

      return expense;
    });
  }

  /**
   * List expenses with filters, search, and pagination.
   */
  async getExpenses(businessId: string, query: QueryExpensesDto) {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.ExpenseWhereInput = { businessId };

    if (query.categoryId) {
      where.categoryId = query.categoryId;
    }
    if (query.paymentMethod) {
      where.paymentMethod = query.paymentMethod;
    }
    if (query.isTaxDeductible !== undefined) {
      where.isTaxDeductible = query.isTaxDeductible;
    }
    if (query.vendor && query.vendor.trim().length > 0) {
      where.vendor = { contains: query.vendor.trim(), mode: 'insensitive' };
    }
    if (query.startDate || query.endDate) {
      where.date = {};
      if (query.startDate) {
        where.date.gte = new Date(query.startDate);
      }
      if (query.endDate) {
        where.date.lte = new Date(query.endDate);
      }
    }
    if (query.search && query.search.trim().length > 0) {
      const s = query.search.trim();
      where.OR = [
        { expenseNumber: { contains: s, mode: 'insensitive' } },
        { vendor: { contains: s, mode: 'insensitive' } },
        { notes: { contains: s, mode: 'insensitive' } },
        { category: { name: { contains: s, mode: 'insensitive' } } },
      ];
    }

    const [total, items] = await Promise.all([
      this.prisma.expense.count({ where }),
      this.prisma.expense.findMany({
        where,
        skip,
        take: limit,
        orderBy: { date: 'desc' },
        include: {
          category: { select: { id: true, name: true } },
        },
      }),
    ]);

    return {
      data: items,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Summary metrics for expenses (Total, monthly, tax deductible, and category breakdown).
   */
  async getExpenseSummary(businessId: string, query?: { startDate?: string; endDate?: string }) {
    const where: Prisma.ExpenseWhereInput = { businessId };

    if (query?.startDate || query?.endDate) {
      where.date = {};
      if (query.startDate) {
        where.date.gte = new Date(query.startDate);
      }
      if (query.endDate) {
        where.date.lte = new Date(query.endDate);
      }
    }

    const expenses = await this.prisma.expense.findMany({
      where,
      select: {
        amount: true,
        gstAmount: true,
        isTaxDeductible: true,
        categoryId: true,
        category: { select: { name: true } },
      },
    });

    let totalAmount = new Prisma.Decimal(0);
    let totalGstAmount = new Prisma.Decimal(0);
    let totalTaxDeductible = new Prisma.Decimal(0);
    const categoryTotals = new Map<string, { categoryId: string; name: string; amount: Prisma.Decimal; count: number }>();

    for (const exp of expenses) {
      totalAmount = totalAmount.plus(exp.amount);
      totalGstAmount = totalGstAmount.plus(exp.gstAmount);
      if (exp.isTaxDeductible) {
        totalTaxDeductible = totalTaxDeductible.plus(exp.amount);
      }

      const catName = exp.category?.name || 'Uncategorized';
      const existing = categoryTotals.get(exp.categoryId) || {
        categoryId: exp.categoryId,
        name: catName,
        amount: new Prisma.Decimal(0),
        count: 0,
      };
      existing.amount = existing.amount.plus(exp.amount);
      existing.count += 1;
      categoryTotals.set(exp.categoryId, existing);
    }

    return {
      totalExpenses: totalAmount.toNumber(),
      totalGstAmount: totalGstAmount.toNumber(),
      totalTaxDeductible: totalTaxDeductible.toNumber(),
      count: expenses.length,
      categoryBreakdown: Array.from(categoryTotals.values()).map((c) => ({
        categoryId: c.categoryId,
        categoryName: c.name,
        amount: c.amount.toNumber(),
        count: c.count,
      })),
    };
  }

  /**
   * Get single expense by ID.
   */
  async getExpenseById(businessId: string, id: string) {
    const expense = await this.prisma.expense.findUnique({
      where: { businessId_id: { businessId, id } },
      include: {
        category: { select: { id: true, name: true } },
      },
    });

    if (!expense) {
      throw new NotFoundException(`Expense with ID ${id} not found.`);
    }

    return expense;
  }

  /**
   * Delete an expense with audit logging to preserve financial trail.
   */
  async deleteExpense(businessId: string, id: string, userId?: string) {
    return this.prisma.$transaction(async (tx) => {
      const expense = await tx.expense.findUnique({
        where: { businessId_id: { businessId, id } },
      });

      if (!expense) {
        throw new NotFoundException(`Expense with ID ${id} not found.`);
      }

      await tx.expense.delete({
        where: { businessId_id: { businessId, id } },
      });

      if (this.accountingService && !expense.amount.isZero()) {
        await this.accountingService.postExpenseDeletedJournal(businessId, expense, tx);
      }

      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'DELETE_EXPENSE',
          entityName: 'Expense',
          entityId: expense.id,
          oldValues: {
            expenseNumber: expense.expenseNumber,
            amount: expense.amount.toNumber(),
            categoryId: expense.categoryId,
            date: expense.date,
          },
        },
      });

      return {
        success: true,
        message: `Expense ${expense.expenseNumber} deleted.`,
      };
    });
  }
}

