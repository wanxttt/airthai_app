import { Test, TestingModule } from '@nestjs/testing';
import { ReportsService } from './reports.service';
import { PrismaService } from '../database/prisma.service';
import { Prisma } from '@prisma/client';

describe('ReportsService', () => {
  let service: ReportsService;
  let prisma: any;

  const mockBusinessId = 'biz_reports_test_001';

  beforeEach(async () => {
    prisma = {
      invoice: {
        aggregate: jest.fn(),
        count: jest.fn(),
        findMany: jest.fn(),
      },
      purchase: {
        aggregate: jest.fn(),
        count: jest.fn(),
        findMany: jest.fn(),
      },
      expense: {
        aggregate: jest.fn(),
        count: jest.fn(),
        findMany: jest.fn(),
        groupBy: jest.fn(),
      },
      expenseCategory: {
        findMany: jest.fn(),
      },
      payment: {
        aggregate: jest.fn(),
        count: jest.fn(),
        findMany: jest.fn(),
        groupBy: jest.fn(),
      },
      customer: {
        findMany: jest.fn(),
      },
      supplier: {
        findMany: jest.fn(),
      },
      product: {
        findMany: jest.fn(),
      },
      stockMovement: {
        count: jest.fn(),
        findMany: jest.fn(),
      },
      invoiceItem: {
        findMany: jest.fn(),
      },
      account: {
        findFirst: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [ReportsService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get<ReportsService>(ReportsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getSalesReport', () => {
    it('should aggregate sales totals accurately with tenant isolation', async () => {
      prisma.invoice.aggregate.mockResolvedValueOnce({
        _sum: {
          subtotal: new Prisma.Decimal(10000),
          discountAmount: new Prisma.Decimal(500),
          taxableAmount: new Prisma.Decimal(9500),
          cgstAmount: new Prisma.Decimal(855),
          sgstAmount: new Prisma.Decimal(855),
          igstAmount: new Prisma.Decimal(0),
          roundOff: new Prisma.Decimal(0),
          totalAmount: new Prisma.Decimal(11210),
          receivedAmount: new Prisma.Decimal(6000),
          balanceAmount: new Prisma.Decimal(5210),
        },
        _count: { id: 2 },
      });
      prisma.invoice.count.mockResolvedValueOnce(2);
      prisma.invoice.findMany.mockResolvedValueOnce([
        {
          id: 'inv_1',
          invoiceNumber: 'INV-001',
          invoiceDate: new Date('2026-10-01'),
          dueDate: new Date('2026-10-15'),
          customerId: 'cust_1',
          customer: { id: 'cust_1', name: 'Customer A', phone: '9999999999' },
          _count: { items: 3 },
          subtotal: new Prisma.Decimal(5000),
          discountAmount: new Prisma.Decimal(0),
          taxableAmount: new Prisma.Decimal(5000),
          cgstAmount: new Prisma.Decimal(450),
          sgstAmount: new Prisma.Decimal(450),
          igstAmount: new Prisma.Decimal(0),
          totalAmount: new Prisma.Decimal(5900),
          receivedAmount: new Prisma.Decimal(5900),
          balanceAmount: new Prisma.Decimal(0),
          status: 'PAID',
        },
      ]);

      const res = await service.getSalesReport(mockBusinessId, { page: 1, limit: 10 });

      expect(res.statusCode).toBe(200);
      expect(res.summary.totalInvoiced).toBe(11210);
      expect(res.summary.totalOutstanding).toBe(5210);
      expect(res.summary.totalReceived).toBe(6000);
      expect(res.summary.totalTax).toBe(1710);
      expect(res.data.length).toBe(1);
      expect(prisma.invoice.aggregate).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ businessId: mockBusinessId }),
        }),
      );
    });
  });

  describe('getReceivablesAgeingReport', () => {
    it('should calculate ageing buckets (0-30, 31-60, 61-90, 90+) and verify reconciliation with GL', async () => {
      const fixedAsOfDate = new Date('2026-10-30');

      prisma.customer.findMany.mockResolvedValueOnce([
        {
          id: 'cust_1',
          name: 'Acme Traders',
          phone: '9876543210',
          currentBalance: new Prisma.Decimal(15000),
        },
      ]);

      // Unpaid invoices at different ages:
      // Invoice 1: 10 days old (2026-10-20) -> 0-30 bucket (5,000)
      // Invoice 2: 40 days old (2026-09-20) -> 31-60 bucket (4,000)
      // Invoice 3: 75 days old (2026-08-16) -> 61-90 bucket (3,000)
      // Invoice 4: 100 days old (2026-07-22) -> 90+ bucket (3,000)
      prisma.invoice.findMany.mockResolvedValueOnce([
        {
          id: 'inv_1',
          invoiceNumber: 'INV-01',
          customerId: 'cust_1',
          invoiceDate: new Date('2026-10-20'),
          dueDate: new Date('2026-10-30'),
          balanceAmount: new Prisma.Decimal(5000),
          totalAmount: new Prisma.Decimal(5000),
        },
        {
          id: 'inv_2',
          invoiceNumber: 'INV-02',
          customerId: 'cust_1',
          invoiceDate: new Date('2026-09-20'),
          dueDate: new Date('2026-09-30'),
          balanceAmount: new Prisma.Decimal(4000),
          totalAmount: new Prisma.Decimal(4000),
        },
        {
          id: 'inv_3',
          invoiceNumber: 'INV-03',
          customerId: 'cust_1',
          invoiceDate: new Date('2026-08-16'),
          dueDate: new Date('2026-08-26'),
          balanceAmount: new Prisma.Decimal(3000),
          totalAmount: new Prisma.Decimal(3000),
        },
        {
          id: 'inv_4',
          invoiceNumber: 'INV-04',
          customerId: 'cust_1',
          invoiceDate: new Date('2026-07-22'),
          dueDate: new Date('2026-08-01'),
          balanceAmount: new Prisma.Decimal(3000),
          totalAmount: new Prisma.Decimal(3000),
        },
      ]);

      // Control account 1100 balance matches exactly: 15,000
      prisma.account.findFirst.mockResolvedValueOnce({
        id: 'acc_1100',
        code: '1100',
        balance: new Prisma.Decimal(15000),
      });

      const res = await service.getReceivablesAgeingReport(mockBusinessId, {
        asOfDate: fixedAsOfDate.toISOString(),
      });

      expect(res.statusCode).toBe(200);
      expect(res.summary.totalReceivables).toBe(15000);
      expect(res.summary.bucket0to30).toBe(5000);
      expect(res.summary.bucket31to60).toBe(4000);
      expect(res.summary.bucket61to90).toBe(3000);
      expect(res.summary.bucket90Plus).toBe(3000);
      expect(res.summary.isReconciled).toBe(true);
      expect(res.summary.discrepancy).toBe(0);

      const cust = res.customers[0];
      expect(cust.id).toBe('cust_1');
      expect(cust.bucket0to30).toBe(5000);
      expect(cust.bucket31to60).toBe(4000);
      expect(cust.bucket61to90).toBe(3000);
      expect(cust.bucket90Plus).toBe(3000);
      expect(cust.totalAgeingBalance).toBe(15000);
    });
  });

  describe('getStockSummaryReport', () => {
    it('should compute product stock valuation and stock status accurately', async () => {
      prisma.product.findMany.mockResolvedValueOnce([
        {
          id: 'prod_1',
          name: 'Wireless Mouse',
          sku: 'WM-01',
          trackStock: true,
          minStockLevel: 5,
          salePrice: new Prisma.Decimal(450),
          purchasePrice: new Prisma.Decimal(250),
          category: { id: 'cat_1', name: 'Electronics' },
          unit: { id: 'unit_1', symbol: 'pcs' },
          stockMovements: [
            {
              movementType: 'PURCHASE',
              quantity: new Prisma.Decimal(20),
              unitCost: new Prisma.Decimal(250),
            },
            {
              movementType: 'SALE',
              quantity: new Prisma.Decimal(17),
              unitCost: new Prisma.Decimal(250),
            },
          ],
        },
      ]);

      const res = await service.getStockSummaryReport(mockBusinessId, {});

      expect(res.statusCode).toBe(200);
      expect(res.summary.totalProducts).toBe(1);
      // 20 - 17 = 3 left. 3 <= minStockLevel (5) -> LOW_STOCK
      expect(res.summary.lowStockCount).toBe(1);
      // Valuation = 3 * 250 = 750
      expect(res.summary.totalValuation).toBe(750);
      expect(res.data[0].stockStatus).toBe('LOW_STOCK');
      expect(res.data[0].currentStock).toBe(3);
    });
  });

  describe('getGstSummaryReport', () => {
    it('should calculate Outward GST liability vs Inward ITC and compute Net Tax Payable', async () => {
      // Outward invoices: Taxable 50,000, CGST 4,500, SGST 4,500, IGST 0 -> Total Outward: 9,000
      prisma.invoice.aggregate.mockResolvedValueOnce({
        _sum: {
          taxableAmount: new Prisma.Decimal(50000),
          cgstAmount: new Prisma.Decimal(4500),
          sgstAmount: new Prisma.Decimal(4500),
          igstAmount: new Prisma.Decimal(0),
          cessAmount: new Prisma.Decimal(0),
        },
      });

      // Purchases ITC: Tax 3,000
      prisma.purchase.aggregate.mockResolvedValueOnce({
        _sum: {
          subtotal: new Prisma.Decimal(30000),
          taxAmount: new Prisma.Decimal(3000),
        },
      });

      // Expenses ITC: Tax 600
      prisma.expense.aggregate.mockResolvedValueOnce({
        _sum: {
          gstAmount: new Prisma.Decimal(600),
        },
      });

      const res = await service.getGstSummaryReport(mockBusinessId);

      expect(res.statusCode).toBe(200);
      // Outward tax: 4500 + 4500 = 9000
      expect(res.data.outwardSupplies.totalOutwardTaxLiability).toBe(9000);
      // Total ITC: 3000 + 600 = 3600
      expect(res.data.inwardSupplies.totalEligibleItc).toBe(3600);
      // Net Tax Payable: 9000 - 3600 = 5400
      expect(res.data.netGstPayable).toBe(5400);
      expect(res.data.itcCarryForward).toBe(0);
    });
  });
});

