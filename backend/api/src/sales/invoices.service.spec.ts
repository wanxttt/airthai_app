import { Test, TestingModule } from '@nestjs/testing';
import { InvoicesService } from './invoices.service';
import { SequenceService } from './sequence.service';
import { PrismaService } from '../database/prisma.service';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { InvoiceStatus, Prisma, StockMovementType } from '@prisma/client';

describe('InvoicesService', () => {
  let service: InvoicesService;
  let prisma: any;
  let sequenceService: any;
  let mockSubscriptionsService: any;

  const mockBusinessId = 'biz_test_123';
  const mockUserId = 'usr_test_123';

  beforeEach(async () => {
    mockSubscriptionsService = {
      enforceInvoiceLimit: jest.fn().mockResolvedValue(undefined),
      enforceUserLimit: jest.fn().mockResolvedValue(undefined),
    };

    prisma = {
      $executeRaw: jest.fn().mockResolvedValue(1),
      invoice: {
        findMany: jest.fn(),
        count: jest.fn(),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      customer: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      product: {
        findMany: jest.fn(),
      },
      branch: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
      },
      warehouse: {
        findFirst: jest.fn(),
        create: jest.fn(),
      },
      stockMovement: {
        create: jest.fn(),
      },
      gstRecord: {
        create: jest.fn(),
        updateMany: jest.fn(),
      },
      auditLog: {
        create: jest.fn(),
      },
      business: {
        findUnique: jest.fn(),
      },
      $transaction: jest.fn((callback) => callback(prisma)),
    };

    sequenceService = {
      getNextNumber: jest.fn().mockResolvedValue('INV-2026-27-0001'),
      getFiscalYear: jest.fn().mockReturnValue('2026-27'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InvoicesService,
        { provide: PrismaService, useValue: prisma },
        { provide: SequenceService, useValue: sequenceService },
        { provide: SubscriptionsService, useValue: mockSubscriptionsService },
      ],
    }).compile();

    service = module.get<InvoicesService>(InvoicesService);
  });

  describe('create', () => {
    it('successfully creates an invoice, reduces stock, increments customer balance, and creates GST/audit records', async () => {
      prisma.business.findUnique.mockResolvedValue({
        id: mockBusinessId,
        stateCode: '27',
        settings: { enableGst: true, allowNegativeStock: false },
      });

      prisma.branch.findFirst.mockResolvedValue({ id: 'branch_1', isMain: true });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'warehouse_1' });

      prisma.customer.findUnique.mockResolvedValue({
        id: 'cust_1',
        businessId: mockBusinessId,
        name: 'A-1 Enterprises',
        state: '27',
        status: 'ACTIVE',
      });

      prisma.product.findMany.mockResolvedValue([
        {
          id: 'prod_1',
          name: 'Steel Rods',
          trackStock: true,
          purchasePrice: new Prisma.Decimal(200),
          stockMovements: [
            { movementType: StockMovementType.PURCHASE, quantity: new Prisma.Decimal(50) },
          ],
        },
      ]);

      prisma.invoice.create.mockImplementation(({ data }) => ({
        id: 'inv_new_1',
        ...data,
      }));

      const result = await service.create(
        mockBusinessId,
        {
          customerId: 'cust_1',
          placeOfSupply: '27',
          items: [
            {
              productId: 'prod_1',
              description: 'Steel Rods 10mm',
              quantity: 10,
              unitPrice: 300,
              gstRate: 18,
            },
          ],
        },
        mockUserId,
      );

      expect(result.success).toBe(true);
      expect(result.statusCode).toBe(201);
      expect(sequenceService.getNextNumber).toHaveBeenCalledWith(
        mockBusinessId,
        'INVOICE',
        'INV',
        expect.any(Date),
        expect.anything(),
      );

      // Verify stock movement created with SALE type
      expect(prisma.stockMovement.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          businessId: mockBusinessId,
          productId: 'prod_1',
          movementType: StockMovementType.SALE,
          quantity: expect.any(Prisma.Decimal),
        }),
      });

      // Verify customer balance updated
      expect(prisma.customer.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'cust_1' } },
        data: {
          currentBalance: {
            increment: expect.any(Prisma.Decimal),
          },
        },
      });

      // Verify GST record created
      expect(prisma.gstRecord.create).toHaveBeenCalled();

      // Verify AuditLog created
      expect(prisma.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          action: 'INVOICE_CREATED',
          entityName: 'Invoice',
        }),
      });
    });

    it('rejects invoice when negative stock is disallowed and stock is insufficient', async () => {
      prisma.business.findUnique.mockResolvedValue({
        id: mockBusinessId,
        stateCode: '27',
        settings: { enableGst: true, allowNegativeStock: false },
      });
      prisma.branch.findFirst.mockResolvedValue({ id: 'branch_1', isMain: true });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'warehouse_1' });

      prisma.product.findMany.mockResolvedValue([
        {
          id: 'prod_2',
          name: 'Limited Widget',
          trackStock: true,
          stockMovements: [
            { movementType: StockMovementType.PURCHASE, quantity: new Prisma.Decimal(5) },
          ],
        },
      ]);

      await expect(
        service.create(mockBusinessId, {
          placeOfSupply: '27',
          items: [
            {
              productId: 'prod_2',
              description: 'Limited Widget',
              quantity: 20, // requested 20, only 5 in stock!
              unitPrice: 100,
              gstRate: 18,
            },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('returns existing invoice when idempotency clientOperationId already exists', async () => {
      const existingInvoice = {
        id: 'inv_existing_123',
        clientOperationId: 'client-op-999',
        invoiceNumber: 'INV-2026-27-0001',
      };
      prisma.invoice.findFirst.mockResolvedValue(existingInvoice);

      const result = await service.create(mockBusinessId, {
        clientOperationId: 'client-op-999',
        placeOfSupply: '27',
        items: [
          {
            description: 'Item',
            quantity: 1,
            unitPrice: 100,
            gstRate: 18,
          },
        ],
      });

      expect(result.success).toBe(true);
      expect((result as any).idempotentReplay).toBe(true);
      expect(prisma.invoice.create).not.toHaveBeenCalled();
    });

    it('SEC-AI-08: rejects invoice creation when monthly subscription invoice limit is exceeded', async () => {
      mockSubscriptionsService.enforceInvoiceLimit.mockRejectedValueOnce(
        new ForbiddenException('Monthly invoice quota exceeded (100/100). Please upgrade your plan.'),
      );

      await expect(
        service.create(mockBusinessId, {
          placeOfSupply: '27',
          items: [{ description: 'Test', quantity: 1, unitPrice: 100, gstRate: 18 }],
        }),
      ).rejects.toThrow(ForbiddenException);

      expect(prisma.invoice.create).not.toHaveBeenCalled();
    });

    it('SEC-AI-11: locks products for update in deterministic order to prevent concurrent overselling races', async () => {
      prisma.business.findUnique.mockResolvedValue({
        id: mockBusinessId,
        stateCode: '27',
        settings: { enableGst: true, allowNegativeStock: false },
      });
      prisma.branch.findFirst.mockResolvedValue({ id: 'branch_1', isMain: true });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'warehouse_1' });

      prisma.product.findMany.mockResolvedValue([
        {
          id: 'prod_B',
          businessId: mockBusinessId,
          name: 'Product B',
          trackStock: true,
          purchasePrice: new Prisma.Decimal(100),
          stockMovements: [{ movementType: 'PURCHASE', quantity: new Prisma.Decimal(50) }],
        },
        {
          id: 'prod_A',
          businessId: mockBusinessId,
          name: 'Product A',
          trackStock: true,
          purchasePrice: new Prisma.Decimal(100),
          stockMovements: [{ movementType: 'PURCHASE', quantity: new Prisma.Decimal(50) }],
        },
      ]);
      prisma.invoice.create.mockResolvedValue({ id: 'inv_locked', invoiceNumber: 'INV-2026-27-0002', totalAmount: new Prisma.Decimal(200), balanceAmount: new Prisma.Decimal(200) });

      await service.create(mockBusinessId, {
        placeOfSupply: '27',
        items: [
          { productId: 'prod_B', description: 'Product B', quantity: 2, unitPrice: 100, gstRate: 18 },
          { productId: 'prod_A', description: 'Product A', quantity: 1, unitPrice: 100, gstRate: 18 },
        ],
      });

      expect(prisma.$executeRaw).toHaveBeenCalled();
      expect(prisma.$executeRaw.mock.calls[0][0][0]).toContain('"products"');
    });

    it('SEC-AI-11: aggregates quantities of identical items to prevent intra-order stock bypass', async () => {
      prisma.business.findUnique.mockResolvedValue({
        id: mockBusinessId,
        stateCode: '27',
        settings: { enableGst: true, allowNegativeStock: false },
      });
      prisma.branch.findFirst.mockResolvedValue({ id: 'branch_1', isMain: true });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'warehouse_1' });

      // Available stock is only 5
      prisma.product.findMany.mockResolvedValue([
        {
          id: 'prod_aggregate',
          businessId: mockBusinessId,
          name: 'Widget',
          trackStock: true,
          purchasePrice: new Prisma.Decimal(100),
          stockMovements: [{ movementType: 'PURCHASE', quantity: new Prisma.Decimal(5) }],
        },
      ]);

      // Two line items for 3 units each = 6 total (exceeds available 5)
      await expect(
        service.create(mockBusinessId, {
          placeOfSupply: '27',
          items: [
            { productId: 'prod_aggregate', description: 'Widget Batch 1', quantity: 3, unitPrice: 100, gstRate: 18 },
            { productId: 'prod_aggregate', description: 'Widget Batch 2', quantity: 3, unitPrice: 100, gstRate: 18 },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('SEC-AI-11: permits sale exceeding available stock when allowNegativeStock is true', async () => {
      prisma.business.findUnique.mockResolvedValue({
        id: mockBusinessId,
        stateCode: '27',
        settings: { enableGst: true, allowNegativeStock: true },
      });
      prisma.branch.findFirst.mockResolvedValue({ id: 'branch_1', isMain: true });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'warehouse_1' });

      // Available stock is 0
      prisma.product.findMany.mockResolvedValue([
        {
          id: 'prod_neg',
          businessId: mockBusinessId,
          name: 'Widget Zero',
          trackStock: true,
          purchasePrice: new Prisma.Decimal(100),
          stockMovements: [],
        },
      ]);
      prisma.invoice.create.mockResolvedValue({ id: 'inv_neg', invoiceNumber: 'INV-2026-27-0003', totalAmount: new Prisma.Decimal(118), balanceAmount: new Prisma.Decimal(118) });

      const result = await service.create(mockBusinessId, {
        placeOfSupply: '27',
        items: [
          { productId: 'prod_neg', description: 'Widget Zero', quantity: 5, unitPrice: 100, gstRate: 18 },
        ],
      });

      expect(result.success).toBe(true);
      expect(prisma.stockMovement.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          productId: 'prod_neg',
          movementType: StockMovementType.SALE,
        }),
      });
    });

    it('rejects product ID that belongs to another tenant', async () => {
      prisma.business.findUnique.mockResolvedValue({
        id: mockBusinessId,
        settings: {},
      });
      prisma.branch.findFirst.mockResolvedValue({ id: 'branch_1' });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'wh_1' });
      // product not found in tenant
      prisma.product.findMany.mockResolvedValue([]);

      await expect(
        service.create(mockBusinessId, {
          placeOfSupply: '27',
          items: [
            {
              productId: 'foreign_prod_id',
              description: 'Hacked Product',
              quantity: 1,
              unitPrice: 100,
              gstRate: 18,
            },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('cancel', () => {
    it('cancels invoice and reverses customer balance and stock movements', async () => {
      const existing = {
        id: 'inv_to_cancel',
        businessId: mockBusinessId,
        customerId: 'cust_1',
        branchId: 'branch_1',
        balanceAmount: new Prisma.Decimal(1180),
        status: InvoiceStatus.ISSUED,
        items: [
          {
            productId: 'prod_1',
            quantity: new Prisma.Decimal(5),
          },
        ],
      };

      prisma.invoice.findUnique.mockResolvedValue(existing);
      prisma.invoice.update.mockResolvedValue({
        ...existing,
        status: InvoiceStatus.CANCELLED,
      });
      prisma.product.findMany.mockResolvedValue([
        { id: 'prod_1', trackStock: true, purchasePrice: new Prisma.Decimal(150) },
      ]);
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'warehouse_1' });

      const result = await service.cancel(
        mockBusinessId,
        'inv_to_cancel',
        { reason: 'Customer requested cancellation' },
        mockUserId,
      );

      expect(result.success).toBe(true);
      expect(result.data.status).toBe(InvoiceStatus.CANCELLED);

      // Verify customer balance decremented
      expect(prisma.customer.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'cust_1' } },
        data: {
          currentBalance: {
            decrement: existing.balanceAmount,
          },
        },
      });

      // Verify stock reversed with SALE_RETURN
      expect(prisma.stockMovement.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          productId: 'prod_1',
          movementType: StockMovementType.SALE_RETURN,
          quantity: existing.items[0].quantity,
          referenceType: 'INVOICE_CANCEL',
        }),
      });

      // Verify GST record cancelled
      expect(prisma.gstRecord.updateMany).toHaveBeenCalledWith({
        where: { businessId: mockBusinessId, invoiceId: 'inv_to_cancel' },
        data: { isCancelled: true },
      });

      // Verify Audit log
      expect(prisma.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          action: 'INVOICE_CANCELLED',
        }),
      });
    });

    it('rejects cancellation if invoice is already cancelled', async () => {
      prisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_already_cancelled',
        businessId: mockBusinessId,
        status: InvoiceStatus.CANCELLED,
      });

      await expect(
        service.cancel(mockBusinessId, 'inv_already_cancelled', { reason: 'Test' }),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
