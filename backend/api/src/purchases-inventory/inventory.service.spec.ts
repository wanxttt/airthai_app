import { Test, TestingModule } from '@nestjs/testing';
import { InventoryService } from './inventory.service';
import { PrismaService } from '../database/prisma.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma, StockMovementType } from '@prisma/client';

describe('InventoryService', () => {
  let service: InventoryService;
  let prisma: any;

  const mockBusinessId = 'biz_test_123';
  const mockUserId = 'usr_test_123';

  beforeEach(async () => {
    prisma = {
      product: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
      },
      business: {
        findUnique: jest.fn(),
      },
      warehouse: {
        findFirst: jest.fn(),
      },
      stockMovement: {
        create: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
      },
      stock: {
        upsert: jest.fn(),
      },
      auditLog: {
        create: jest.fn(),
      },
      $transaction: jest.fn((callback) => callback(prisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InventoryService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<InventoryService>(InventoryService);
  });

  describe('getSummary', () => {
    it('calculates total stock, low stock, and inventory valuation using Weighted Average Cost', async () => {
      prisma.product.findMany.mockResolvedValue([
        {
          id: 'prod_1',
          trackStock: true,
          minStockLevel: new Prisma.Decimal(10),
          purchasePrice: new Prisma.Decimal(100),
          stockMovements: [
            {
              movementType: StockMovementType.PURCHASE,
              quantity: new Prisma.Decimal(20),
              unitCost: new Prisma.Decimal(100),
            },
            {
              movementType: StockMovementType.PURCHASE,
              quantity: new Prisma.Decimal(10),
              unitCost: new Prisma.Decimal(130), // total 30 purchased, total cost = 2000 + 1300 = 3300 -> WAC = 110
            },
            {
              movementType: StockMovementType.SALE,
              quantity: new Prisma.Decimal(5),
              unitCost: new Prisma.Decimal(100),
            },
          ],
        },
        {
          id: 'prod_2',
          trackStock: true,
          minStockLevel: new Prisma.Decimal(5),
          purchasePrice: new Prisma.Decimal(50),
          stockMovements: [
            // Out of stock
            {
              movementType: StockMovementType.PURCHASE,
              quantity: new Prisma.Decimal(2),
              unitCost: new Prisma.Decimal(50),
            },
            {
              movementType: StockMovementType.SALE,
              quantity: new Prisma.Decimal(2),
              unitCost: new Prisma.Decimal(50),
            },
          ],
        },
      ]);

      const res = await service.getSummary(mockBusinessId);

      expect(res.success).toBe(true);
      // prod_1: currentStock = 25, WAC = 110 -> valuation = 2750
      // prod_2: currentStock = 0 -> valuation = 0, outOfStockCount = 1
      expect(res.data.totalStockQuantity).toBe(25);
      expect(res.data.outOfStockCount).toBe(1);
      expect(res.data.totalValuation).toBe(2750);
      expect(res.data.valuationMethod).toBe('WEIGHTED_AVERAGE_COST');
    });
  });

  describe('createAdjustment', () => {
    it('creates an ADJUSTMENT_ADD stock movement and updates stock table', async () => {
      prisma.product.findUnique.mockResolvedValue({
        id: 'prod_1',
        purchasePrice: new Prisma.Decimal(100),
        stockMovements: [],
      });
      prisma.business.findUnique.mockResolvedValue({
        id: mockBusinessId,
        settings: { allowNegativeStock: false },
      });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'wh_1' });
      prisma.stockMovement.create.mockImplementation(({ data }) => ({
        id: 'mov_1',
        ...data,
      }));

      const result = await service.createAdjustment(
        mockBusinessId,
        {
          productId: 'prod_1',
          movementType: StockMovementType.ADJUSTMENT_ADD,
          quantity: 15,
          reason: 'Physical inventory surplus',
        },
        mockUserId,
      );

      expect(result.success).toBe(true);
      expect(prisma.stockMovement.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          productId: 'prod_1',
          movementType: StockMovementType.ADJUSTMENT_ADD,
          quantity: expect.any(Prisma.Decimal),
          referenceType: 'MANUAL_ADJUSTMENT',
        }),
      });
      expect(prisma.stock.upsert).toHaveBeenCalled();
      expect(prisma.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          action: 'STOCK_ADJUSTED',
          entityName: 'Product',
        }),
      });
    });

    it('rejects stock reduction when negative stock is disallowed and stock is insufficient', async () => {
      prisma.product.findUnique.mockResolvedValue({
        id: 'prod_1',
        stockMovements: [
          // only 5 available
          { movementType: StockMovementType.PURCHASE, quantity: new Prisma.Decimal(5) },
        ],
      });
      prisma.business.findUnique.mockResolvedValue({
        id: mockBusinessId,
        settings: { allowNegativeStock: false },
      });

      await expect(
        service.createAdjustment(mockBusinessId, {
          productId: 'prod_1',
          movementType: StockMovementType.DAMAGE,
          quantity: 10, // requested 10 reduction, only 5 available!
          reason: 'Broken in warehouse',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('allows stock reduction when stock is sufficient', async () => {
      prisma.product.findUnique.mockResolvedValue({
        id: 'prod_1',
        purchasePrice: new Prisma.Decimal(100),
        stockMovements: [
          { movementType: StockMovementType.PURCHASE, quantity: new Prisma.Decimal(20) },
        ],
      });
      prisma.business.findUnique.mockResolvedValue({
        id: mockBusinessId,
        settings: { allowNegativeStock: false },
      });
      prisma.warehouse.findFirst.mockResolvedValue({ id: 'wh_1' });

      const result = await service.createAdjustment(mockBusinessId, {
        productId: 'prod_1',
        movementType: StockMovementType.DAMAGE,
        quantity: 3,
        reason: 'Water damage',
      });

      expect(result.success).toBe(true);
      expect(prisma.stockMovement.create).toHaveBeenCalled();
    });
  });
});
