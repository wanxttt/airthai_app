import { Test, TestingModule } from '@nestjs/testing';
import { DashboardService } from './dashboard.service';
import { PrismaService } from '../database/prisma.service';
import { CacheService } from '../common/cache/cache.service';
import { Prisma } from '@prisma/client';
import { DashboardPeriod } from './dto/query-dashboard.dto';

describe('DashboardService', () => {
  let service: DashboardService;
  let prisma: any;

  const mockBusinessId = 'biz_dashboard_test_01';

  beforeEach(async () => {
    prisma = {
      invoice: {
        aggregate: jest.fn(),
        findMany: jest.fn(),
      },
      purchase: {
        aggregate: jest.fn(),
        findMany: jest.fn(),
      },
      expense: {
        aggregate: jest.fn(),
        findMany: jest.fn(),
      },
      payment: {
        aggregate: jest.fn(),
      },
      customer: {
        aggregate: jest.fn(),
      },
      supplier: {
        aggregate: jest.fn(),
      },
      product: {
        findMany: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DashboardService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<DashboardService>(DashboardService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should aggregate authoritative dashboard metrics from database', async () => {
    // Current sales: 15,000 total, 12,000 subtotal, 3,000 GST
    prisma.invoice.aggregate
      .mockResolvedValueOnce({
        _sum: {
          totalAmount: new Prisma.Decimal(15000),
          subtotal: new Prisma.Decimal(12000),
          cgstAmount: new Prisma.Decimal(1500),
          sgstAmount: new Prisma.Decimal(1500),
          igstAmount: new Prisma.Decimal(0),
        },
        _count: { id: 3 },
      })
      // Previous sales: 10,000 total (for growth calculation)
      .mockResolvedValueOnce({
        _sum: { totalAmount: new Prisma.Decimal(10000) },
      })
      // Overdue invoices: 1 overdue invoice of 5,000
      .mockResolvedValueOnce({
        _sum: { balanceAmount: new Prisma.Decimal(5000) },
        _count: { id: 1 },
      });

    // Current purchases: 8,000 total, 7,000 subtotal, 1,000 tax
    prisma.purchase.aggregate
      .mockResolvedValueOnce({
        _sum: {
          totalAmount: new Prisma.Decimal(8000),
          subtotal: new Prisma.Decimal(7000),
          taxAmount: new Prisma.Decimal(1000),
        },
        _count: { id: 2 },
      })
      // Previous purchases: 6,000 total
      .mockResolvedValueOnce({
        _sum: { totalAmount: new Prisma.Decimal(6000) },
      });

    // Expenses: 2,500 total, 300 GST
    prisma.expense.aggregate
      .mockResolvedValueOnce({
        _sum: {
          amount: new Prisma.Decimal(2500),
          gstAmount: new Prisma.Decimal(300),
        },
        _count: { id: 5 },
      })
      // Previous expenses: 2,000
      .mockResolvedValueOnce({
        _sum: { amount: new Prisma.Decimal(2000) },
      });

    // Payments: Collections 12,000, Disbursements 6,000
    prisma.payment.aggregate
      .mockResolvedValueOnce({ _sum: { amount: new Prisma.Decimal(12000) } })
      .mockResolvedValueOnce({ _sum: { amount: new Prisma.Decimal(6000) } });

    // Customer receivables: 3,000
    prisma.customer.aggregate.mockResolvedValueOnce({
      _sum: { currentBalance: new Prisma.Decimal(3000) },
    });

    // Supplier payables: 2,000
    prisma.supplier.aggregate.mockResolvedValueOnce({
      _sum: { currentBalance: new Prisma.Decimal(2000) },
    });

    // Products: 1 product with 3 units in stock (min stock 5) -> Low stock
    prisma.product.findMany.mockResolvedValueOnce([
      {
        id: 'prod_1',
        minStockLevel: 5,
        purchasePrice: new Prisma.Decimal(500),
        trackStock: true,
        stockMovements: [
          {
            movementType: 'PURCHASE',
            quantity: new Prisma.Decimal(10),
            unitCost: new Prisma.Decimal(500),
          },
          {
            movementType: 'SALE',
            quantity: new Prisma.Decimal(7),
            unitCost: new Prisma.Decimal(500),
          },
        ],
      },
    ]);

    // Recent Invoices
    prisma.invoice.findMany.mockResolvedValueOnce([
      {
        id: 'inv_1',
        invoiceNumber: 'INV-001',
        invoiceDate: new Date('2026-10-25'),
        totalAmount: new Prisma.Decimal(5000),
        balanceAmount: new Prisma.Decimal(0),
        status: 'PAID',
        customer: { name: 'Acme Corp' },
      },
    ]);

    // Recent Purchases
    prisma.purchase.findMany.mockResolvedValueOnce([
      {
        id: 'pur_1',
        billNumber: 'BILL-001',
        billDate: new Date('2026-10-20'),
        totalAmount: new Prisma.Decimal(4000),
        balanceAmount: new Prisma.Decimal(1000),
        status: 'RECEIVED',
        supplier: { name: 'Supplier One' },
      },
    ]);

    // Recent Expenses
    prisma.expense.findMany.mockResolvedValueOnce([
      {
        id: 'exp_1',
        expenseNumber: 'EXP-001',
        date: new Date('2026-10-22'),
        amount: new Prisma.Decimal(800),
        vendor: 'Stationery World',
        category: { name: 'Office Supplies' },
      },
    ]);

    const result = await service.getMetrics(mockBusinessId, {
      period: DashboardPeriod.THIS_MONTH,
    });

    // Verify Sales
    expect(result.sales.totalSales).toBe(15000);
    expect(result.sales.subtotal).toBe(12000);
    expect(result.sales.taxAmount).toBe(3000);
    expect(result.sales.invoiceCount).toBe(3);
    expect(result.sales.averageInvoiceValue).toBe(5000);
    expect(result.sales.growthPercentage).toBe(50); // (15000-10000)/10000 * 100

    // Verify Purchases
    expect(result.purchases.totalPurchases).toBe(8000);
    expect(result.purchases.purchaseCount).toBe(2);

    // Verify Expenses
    expect(result.expenses.totalExpenses).toBe(2500);
    expect(result.expenses.netExpenses).toBe(2200);

    // Verify Cash Flow: 12000 - 6000 = 6000
    expect(result.cashFlow.totalCollections).toBe(12000);
    expect(result.cashFlow.totalDisbursements).toBe(6000);
    expect(result.cashFlow.netCashFlow).toBe(6000);

    // Verify Profitability (Accrual definitions)
    // Revenue Subtotal (12,000) - COGS/Purchases Subtotal (7,000) = Gross Profit (5,000)
    // Net Profit = Gross Profit (5,000) - Net Expenses (2,200) = 2,800
    expect(result.profitability.grossProfit).toBe(5000);
    expect(result.profitability.operatingExpenses).toBe(2200);
    expect(result.profitability.netProfit).toBe(2800);
    expect(result.profitability.calculationAssumptions).toContain('Accrual Basis');

    // Verify Inventory: 3 units left at 500 = 1500 valuation, 1 low stock
    expect(result.inventory.totalProducts).toBe(1);
    expect(result.inventory.lowStockCount).toBe(1);
    expect(result.inventory.totalValuation).toBe(1500);

    // Verify Alerts
    expect(result.alerts.length).toBeGreaterThanOrEqual(2);
    expect(result.alerts.some((a) => a.type === 'LOW_STOCK')).toBe(true);
    expect(result.alerts.some((a) => a.type === 'OVERDUE_INVOICES')).toBe(true);

    // Verify Tenant Isolation in Queries
    expect(prisma.invoice.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ businessId: mockBusinessId }),
      }),
    );
  });

  it('serves dashboard metrics from cache on subsequent calls and supports invalidation', async () => {
    const mockCache: any = {
      store: new Map<string, string>(),
      getJson: jest.fn(async (key: string) => {
        const val = mockCache.store.get(key);
        return val ? JSON.parse(val) : null;
      }),
      setJson: jest.fn(async (key: string, val: any) => {
        mockCache.store.set(key, JSON.stringify(val));
      }),
      delByPrefix: jest.fn(async (prefix: string) => {
        for (const k of mockCache.store.keys()) {
          if (k.startsWith(prefix)) mockCache.store.delete(k);
        }
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DashboardService,
        { provide: PrismaService, useValue: prisma },
        { provide: CacheService, useValue: mockCache },
      ],
    }).compile();

    const cachedService = module.get<DashboardService>(DashboardService);

    // Seed mock database returns
    prisma.invoice.aggregate.mockResolvedValue({ _sum: { totalAmount: new Prisma.Decimal(1000) }, _count: { id: 1 } });
    prisma.purchase.aggregate.mockResolvedValue({ _sum: { totalAmount: new Prisma.Decimal(500) }, _count: { id: 1 } });
    prisma.expense.aggregate.mockResolvedValue({ _sum: { amount: new Prisma.Decimal(100), gstAmount: new Prisma.Decimal(0) }, _count: { id: 1 } });
    prisma.payment.aggregate.mockResolvedValue({ _sum: { amount: new Prisma.Decimal(1000) } });
    prisma.customer.aggregate.mockResolvedValue({ _sum: { outstandingBalance: new Prisma.Decimal(0) } });
    prisma.supplier.aggregate.mockResolvedValue({ _sum: { outstandingBalance: new Prisma.Decimal(0) } });
    prisma.product.findMany.mockResolvedValue([]);
    prisma.invoice.findMany.mockResolvedValue([]);
    prisma.purchase.findMany.mockResolvedValue([]);
    prisma.expense.findMany.mockResolvedValue([]);

    // Call 1: Miss -> queries db and caches
    const res1 = await cachedService.getMetrics(mockBusinessId, { period: DashboardPeriod.THIS_MONTH });
    expect(res1).toBeDefined();
    expect(mockCache.setJson).toHaveBeenCalledTimes(1);

    // Call 2: Hit -> returns cached object without calling prisma.invoice.aggregate again
    const callCountBefore = prisma.invoice.aggregate.mock.calls.length;
    const res2 = await cachedService.getMetrics(mockBusinessId, { period: DashboardPeriod.THIS_MONTH });
    expect(res2).toEqual(res1);
    expect(prisma.invoice.aggregate.mock.calls.length).toBe(callCountBefore);

    // Invalidation
    await cachedService.invalidateDashboardCache(mockBusinessId);
    expect(mockCache.delByPrefix).toHaveBeenCalledWith(`dashboard:${mockBusinessId}`);
  });
});

