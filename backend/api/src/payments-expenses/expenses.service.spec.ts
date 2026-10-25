import { Test, TestingModule } from '@nestjs/testing';
import { ExpensesService } from './expenses.service';
import { PrismaService } from '../database/prisma.service';
import { SequenceService } from '../sales/sequence.service';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { PaymentMethod, Prisma } from '@prisma/client';

describe('ExpensesService', () => {
  let service: ExpensesService;
  let mockPrisma: any;
  let mockSequenceService: any;

  const mockBusinessId = 'biz_test_123';
  const mockUserId = 'usr_test_123';
  const mockCategoryId = 'cat_rent_01';

  beforeEach(async () => {
    mockSequenceService = {
      getNextNumber: jest.fn().mockResolvedValue('EXP-2026-27-0001'),
    };

    mockPrisma = {
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return callback(mockPrisma);
      }),
      expenseCategory: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        createMany: jest.fn(),
      },
      expense: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        count: jest.fn(),
        delete: jest.fn(),
      },
      auditLog: {
        create: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ExpensesService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: SequenceService, useValue: mockSequenceService },
      ],
    }).compile();

    service = module.get<ExpensesService>(ExpensesService);
  });

  describe('getCategories', () => {
    it('returns existing categories if present', async () => {
      mockPrisma.expenseCategory.findMany.mockResolvedValue([
        { id: 'c1', name: 'Rent' },
        { id: 'c2', name: 'Utilities' },
      ]);

      const res = await service.getCategories(mockBusinessId);
      expect(res.length).toBe(2);
      expect(mockPrisma.expenseCategory.createMany).not.toHaveBeenCalled();
    });

    it('auto-seeds default categories if none exist', async () => {
      mockPrisma.expenseCategory.findMany
        .mockResolvedValueOnce([]) // First check empty
        .mockResolvedValueOnce([
          { id: 'c1', name: 'Rent' },
          { id: 'c2', name: 'Salaries & Wages' },
        ]);

      const res = await service.getCategories(mockBusinessId);
      expect(mockPrisma.expenseCategory.createMany).toHaveBeenCalled();
      expect(res.length).toBe(2);
    });
  });

  describe('createCategory', () => {
    it('creates new custom expense category', async () => {
      mockPrisma.expenseCategory.findUnique.mockResolvedValue(null);
      mockPrisma.expenseCategory.create.mockResolvedValue({
        id: 'cat_custom',
        name: 'Warehouse Maintenance',
        businessId: mockBusinessId,
      });

      const res = await service.createCategory(mockBusinessId, {
        name: 'Warehouse Maintenance',
      });
      expect(res.name).toBe('Warehouse Maintenance');
    });

    it('rejects duplicate category name', async () => {
      mockPrisma.expenseCategory.findUnique.mockResolvedValue({
        id: 'cat_existing',
        name: 'Rent',
      });

      await expect(
        service.createCategory(mockBusinessId, { name: 'Rent' }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('createExpense', () => {
    it('creates an expense with sequential number and audit trail', async () => {
      mockPrisma.expenseCategory.findUnique.mockResolvedValue({
        id: mockCategoryId,
        name: 'Rent',
        businessId: mockBusinessId,
      });

      mockPrisma.expense.create.mockResolvedValue({
        id: 'exp_001',
        expenseNumber: 'EXP-2026-27-0001',
        amount: new Prisma.Decimal(25000),
        category: { id: mockCategoryId, name: 'Rent' },
      });

      const res = await service.createExpense(
        mockBusinessId,
        {
          categoryId: mockCategoryId,
          amount: 25000,
          date: '2026-10-25T10:00:00Z',
          paymentMethod: PaymentMethod.BANK_TRANSFER,
          vendor: 'Shree Real Estate',
          gstin: '27AABCS1234A1Z5',
          gstAmount: 4500,
          isTaxDeductible: true,
          notes: 'Office rent for October',
        },
        mockUserId,
      );

      expect(res.expenseNumber).toBe('EXP-2026-27-0001');
      expect(mockSequenceService.getNextNumber).toHaveBeenCalledWith(
        mockBusinessId,
        'EXPENSE',
        'EXP',
        expect.any(Date),
        expect.anything(),
      );
      expect(mockPrisma.auditLog.create).toHaveBeenCalled();
    });

    it('rejects zero or negative expense amount', async () => {
      await expect(
        service.createExpense(
          mockBusinessId,
          {
            categoryId: mockCategoryId,
            amount: 0,
            date: '2026-10-25T10:00:00Z',
            paymentMethod: PaymentMethod.CASH,
          },
          mockUserId,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects gstAmount greater than expense amount', async () => {
      await expect(
        service.createExpense(
          mockBusinessId,
          {
            categoryId: mockCategoryId,
            amount: 1000,
            gstAmount: 1500, // GST cannot exceed total amount!
            date: '2026-10-25T10:00:00Z',
            paymentMethod: PaymentMethod.UPI,
          },
          mockUserId,
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('getExpenseSummary', () => {
    it('aggregates total expenses, GST, tax deductible, and category breakdown accurately', async () => {
      mockPrisma.expense.findMany.mockResolvedValue([
        {
          amount: new Prisma.Decimal(20000),
          gstAmount: new Prisma.Decimal(3600),
          isTaxDeductible: true,
          categoryId: 'c_rent',
          category: { name: 'Rent' },
        },
        {
          amount: new Prisma.Decimal(5000),
          gstAmount: new Prisma.Decimal(0),
          isTaxDeductible: true,
          categoryId: 'c_util',
          category: { name: 'Utilities' },
        },
        {
          amount: new Prisma.Decimal(1000),
          gstAmount: new Prisma.Decimal(0),
          isTaxDeductible: false,
          categoryId: 'c_util',
          category: { name: 'Utilities' },
        },
      ]);

      const summary = await service.getExpenseSummary(mockBusinessId);
      expect(summary.totalExpenses).toBe(26000);
      expect(summary.totalGstAmount).toBe(3600);
      expect(summary.totalTaxDeductible).toBe(25000);
      expect(summary.count).toBe(3);
      expect(summary.categoryBreakdown.length).toBe(2);

      const rentCat = summary.categoryBreakdown.find((c) => c.categoryName === 'Rent');
      expect(rentCat?.amount).toBe(20000);
      expect(rentCat?.count).toBe(1);

      const utilCat = summary.categoryBreakdown.find((c) => c.categoryName === 'Utilities');
      expect(utilCat?.amount).toBe(6000);
      expect(utilCat?.count).toBe(2);
    });
  });

  describe('deleteExpense', () => {
    it('deletes expense with audit trail', async () => {
      mockPrisma.expense.findUnique.mockResolvedValue({
        id: 'exp_del_1',
        expenseNumber: 'EXP-2026-27-0001',
        amount: new Prisma.Decimal(5000),
        categoryId: 'c1',
        date: new Date(),
      });

      const res = await service.deleteExpense(mockBusinessId, 'exp_del_1', mockUserId);
      expect(res.success).toBe(true);
      expect(mockPrisma.expense.delete).toHaveBeenCalled();
      expect(mockPrisma.auditLog.create).toHaveBeenCalled();
    });
  });
});
