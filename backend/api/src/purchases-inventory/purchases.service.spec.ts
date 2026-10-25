import { Test, TestingModule } from '@nestjs/testing';
import { PurchasesService } from './purchases.service';
import { PrismaService } from '../database/prisma.service';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { PaymentStatus, Prisma, PurchaseStatus, StockMovementType } from '@prisma/client';

describe('PurchasesService', () => {
  let service: PurchasesService;
  let prisma: any;

  const mockBusinessId = 'biz_test_123';
  const mockUserId = 'usr_test_123';

  beforeEach(async () => {
    prisma = {
      purchase: {
        findMany: jest.fn(),
        count: jest.fn(),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      supplier: {
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
      stock: {
        upsert: jest.fn(),
      },
      gstRecord: {
        create: jest.fn(),
        updateMany: jest.fn(),
      },
      auditLog: {
        create: jest.fn(),
      },
      $transaction: jest.fn((callback) => callback(prisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PurchasesService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<PurchasesService>(PurchasesService);
  });

  describe('create', () => {
    it('creates a confirmed purchase bill, updates stock, increments supplier balance and writes audit event', async () => {
      prisma.supplier.findUnique.mockResolvedValue({
        id: 'supp_1',
        businessId: mockBusinessId,
        name: 'National Steel Corp',
        state: '27',
      });
      // no duplicate bill
      prisma.purchase.findUnique.mockResolvedValue(null);

      prisma.branch.findFirst.mockResolvedValue({ id: 'branch_1', isMain: true });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'warehouse_1', isDefault: true });

      prisma.product.findMany.mockResolvedValue([
        {
          id: 'prod_1',
          name: 'Steel Plates',
          purchasePrice: new Prisma.Decimal(100),
        },
      ]);

      prisma.purchase.create.mockImplementation(({ data }) => ({
        id: 'pur_1',
        ...data,
      }));

      const result = await service.create(
        mockBusinessId,
        {
          supplierId: 'supp_1',
          billNumber: 'BILL-8899',
          items: [
            {
              productId: 'prod_1',
              description: 'Steel Plates 5mm',
              quantity: 20,
              unitCost: 150,
              taxRate: 18,
            },
          ],
        },
        mockUserId,
      );

      expect(result.success).toBe(true);
      expect(result.statusCode).toBe(201);

      // Verify stock movement
      expect(prisma.stockMovement.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          businessId: mockBusinessId,
          productId: 'prod_1',
          movementType: StockMovementType.PURCHASE,
          quantity: expect.any(Prisma.Decimal),
        }),
      });

      // Verify stock table upsert
      expect(prisma.stock.upsert).toHaveBeenCalled();

      // Verify supplier payable balance incremented
      expect(prisma.supplier.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'supp_1' } },
        data: {
          currentBalance: {
            increment: expect.any(Prisma.Decimal),
          },
        },
      });

      // Verify audit log
      expect(prisma.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          action: 'PURCHASE_RECEIVED',
          entityName: 'Purchase',
        }),
      });
    });

    it('rejects duplicate billNumber for the same supplier', async () => {
      prisma.supplier.findUnique.mockResolvedValue({
        id: 'supp_1',
        name: 'Supplier A',
      });
      prisma.purchase.findUnique.mockResolvedValue({ id: 'existing_bill_id' });

      await expect(
        service.create(mockBusinessId, {
          supplierId: 'supp_1',
          billNumber: 'BILL-DUPLICATE',
          items: [{ productId: 'p1', description: 'Item', quantity: 1, unitCost: 100 }],
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('returns existing record when idempotency clientOperationId is replayed', async () => {
      const existing = {
        id: 'pur_existing_1',
        clientOperationId: 'client-op-pur-1',
        billNumber: 'BILL-123',
      };
      prisma.purchase.findFirst.mockResolvedValue(existing);

      const result = await service.create(mockBusinessId, {
        supplierId: 'supp_1',
        billNumber: 'BILL-123',
        clientOperationId: 'client-op-pur-1',
        items: [{ productId: 'p1', description: 'Item', quantity: 1, unitCost: 100 }],
      });

      expect(result.success).toBe(true);
      expect((result as any).idempotentReplay).toBe(true);
      expect(prisma.purchase.create).not.toHaveBeenCalled();
    });

    it('rejects product not belonging to tenant', async () => {
      prisma.supplier.findUnique.mockResolvedValue({ id: 'supp_1' });
      prisma.purchase.findUnique.mockResolvedValue(null);
      prisma.branch.findFirst.mockResolvedValue({ id: 'b1' });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'w1' });
      prisma.product.findMany.mockResolvedValue([]); // not found

      await expect(
        service.create(mockBusinessId, {
          supplierId: 'supp_1',
          billNumber: 'BILL-999',
          items: [{ productId: 'foreign_prod', description: 'Hacked', quantity: 1, unitCost: 100 }],
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('receive', () => {
    it('receives an ORDERED purchase and applies stock and payable balance', async () => {
      const orderedPurchase = {
        id: 'pur_ordered',
        businessId: mockBusinessId,
        supplierId: 'supp_1',
        branchId: 'branch_1',
        billNumber: 'PO-001',
        status: PurchaseStatus.ORDERED,
        billDate: new Date(),
        subtotal: new Prisma.Decimal(5000),
        taxAmount: new Prisma.Decimal(900),
        totalAmount: new Prisma.Decimal(5900),
        balanceAmount: new Prisma.Decimal(5900),
        supplier: { id: 'supp_1', gstin: '27AABCS1234A1Z5' },
        items: [
          {
            productId: 'prod_1',
            quantity: new Prisma.Decimal(10),
            unitCost: new Prisma.Decimal(500),
          },
        ],
      };

      prisma.purchase.findUnique.mockResolvedValue(orderedPurchase);
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'warehouse_1' });
      prisma.purchase.update.mockResolvedValue({
        ...orderedPurchase,
        status: PurchaseStatus.RECEIVED,
      });

      const result = await service.receive(mockBusinessId, 'pur_ordered', mockUserId);

      expect(result.success).toBe(true);
      expect(result.data.status).toBe(PurchaseStatus.RECEIVED);
      expect(prisma.stockMovement.create).toHaveBeenCalled();
      expect(prisma.supplier.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'supp_1' } },
        data: { currentBalance: { increment: orderedPurchase.balanceAmount } },
      });
    });

    it('rejects receiving an already RECEIVED purchase', async () => {
      prisma.purchase.findUnique.mockResolvedValue({
        id: 'pur_already_received',
        businessId: mockBusinessId,
        status: PurchaseStatus.RECEIVED,
      });

      await expect(
        service.receive(mockBusinessId, 'pur_already_received'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('cancel', () => {
    it('cancels a purchase and reverses supplier balance and inventory stock', async () => {
      const existing = {
        id: 'pur_to_cancel',
        businessId: mockBusinessId,
        supplierId: 'supp_1',
        branchId: 'branch_1',
        status: PurchaseStatus.RECEIVED,
        balanceAmount: new Prisma.Decimal(3000),
        notes: null,
        items: [
          {
            productId: 'prod_1',
            quantity: new Prisma.Decimal(5),
            unitCost: new Prisma.Decimal(600),
          },
        ],
      };

      prisma.purchase.findUnique.mockResolvedValue(existing);
      prisma.purchase.update.mockResolvedValue({
        ...existing,
        status: PurchaseStatus.CANCELLED,
      });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'warehouse_1' });

      const result = await service.cancel(
        mockBusinessId,
        'pur_to_cancel',
        { reason: 'Goods rejected due to defect' },
        mockUserId,
      );

      expect(result.success).toBe(true);
      expect(result.data.status).toBe(PurchaseStatus.CANCELLED);

      // Verify supplier payable reversed
      expect(prisma.supplier.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'supp_1' } },
        data: { currentBalance: { decrement: existing.balanceAmount } },
      });

      // Verify stock reversed with PURCHASE_RETURN
      expect(prisma.stockMovement.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          productId: 'prod_1',
          movementType: StockMovementType.PURCHASE_RETURN,
          quantity: existing.items[0].quantity,
          referenceType: 'PURCHASE_CANCEL',
        }),
      });

      // Verify GST record cancelled
      expect(prisma.gstRecord.updateMany).toHaveBeenCalledWith({
        where: { businessId: mockBusinessId, purchaseId: 'pur_to_cancel' },
        data: { isCancelled: true },
      });
    });

    it('rejects cancellation if purchase is already cancelled', async () => {
      prisma.purchase.findUnique.mockResolvedValue({
        id: 'pur_already_cancelled',
        businessId: mockBusinessId,
        status: PurchaseStatus.CANCELLED,
      });

      await expect(
        service.cancel(mockBusinessId, 'pur_already_cancelled', { reason: 'Test' }),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
