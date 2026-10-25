import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { ProductsService } from './products.service';
import { PrismaService } from '../../database/prisma.service';

describe('ProductsService', () => {
  let service: ProductsService;
  let mockPrisma: any;

  beforeEach(async () => {
    mockPrisma = {
      product: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        count: jest.fn(),
      },
      category: {
        findUnique: jest.fn(),
      },
      unit: {
        findUnique: jest.fn(),
      },
      warehouse: {
        findFirst: jest.fn(),
        create: jest.fn(),
      },
      stock: {
        create: jest.fn(),
        deleteMany: jest.fn(),
      },
      stockMovement: {
        create: jest.fn(),
        deleteMany: jest.fn(),
      },
      productVariant: {
        deleteMany: jest.fn(),
      },
      invoiceItem: {
        count: jest.fn(),
      },
      purchaseItem: {
        count: jest.fn(),
      },
      quotationItem: {
        count: jest.fn(),
      },
      salesOrderItem: {
        count: jest.fn(),
      },
      $transaction: jest.fn((callback) => callback(mockPrisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProductsService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
      ],
    }).compile();

    service = module.get<ProductsService>(ProductsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('should create product with category, unit, pricing, and initial stock', async () => {
      mockPrisma.category.findUnique.mockResolvedValueOnce({ id: 'cat_1', businessId: 'biz_1' });
      mockPrisma.unit.findUnique.mockResolvedValueOnce({ id: 'unit_1', businessId: 'biz_1' });
      mockPrisma.product.findFirst.mockResolvedValueOnce(null); // SKU check
      mockPrisma.warehouse.findFirst.mockResolvedValueOnce({ id: 'wh_1', businessId: 'biz_1' });
      mockPrisma.product.create.mockResolvedValueOnce({
        id: 'prod_1',
        name: 'Wireless Mouse',
        sku: 'MS-001',
        salePrice: 450,
        currentStock: 10,
        trackStock: true,
      });

      const result = await service.create('biz_1', {
        name: 'Wireless Mouse',
        sku: 'MS-001',
        categoryId: 'cat_1',
        unitId: 'unit_1',
        salePrice: 450,
        purchasePrice: 250,
        openingStock: 10,
        trackStock: true,
      });

      expect(result).toHaveProperty('id', 'prod_1');
      expect(mockPrisma.stock.create).toHaveBeenCalled();
      expect(mockPrisma.stockMovement.create).toHaveBeenCalled();
    });

    it('should reject creation if category does not belong to business (cross-tenant)', async () => {
      mockPrisma.category.findUnique.mockResolvedValueOnce(null);

      await expect(
        service.create('biz_1', {
          name: 'Hacked Product',
          categoryId: 'foreign_cat_id',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject creation if unit does not belong to business (cross-tenant)', async () => {
      mockPrisma.unit.findUnique.mockResolvedValueOnce(null);

      await expect(
        service.create('biz_1', {
          name: 'Hacked Product',
          unitId: 'foreign_unit_id',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject creation if duplicate SKU exists in same business', async () => {
      mockPrisma.product.findFirst.mockResolvedValueOnce({
        id: 'prod_other',
        sku: 'EXISTING-SKU',
      });

      await expect(
        service.create('biz_1', {
          name: 'Duplicate Item',
          sku: 'EXISTING-SKU',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('findAll', () => {
    it('should filter products by search term and return paginated list', async () => {
      mockPrisma.product.count.mockResolvedValueOnce(1);
      mockPrisma.product.findMany.mockResolvedValueOnce([
        { id: 'prod_1', name: 'Logitech Mouse', sku: 'LOGI-01' },
      ]);

      const result = await service.findAll('biz_1', { search: 'mouse', page: 1, limit: 10 });
      expect(result.data.length).toBe(1);
      expect(result.pagination.total).toBe(1);
    });
  });

  describe('toggleArchive', () => {
    it('should toggle status from ACTIVE to ARCHIVED', async () => {
      mockPrisma.product.findUnique.mockResolvedValueOnce({
        id: 'prod_1',
        status: 'ACTIVE',
      });
      mockPrisma.product.update.mockResolvedValueOnce({
        id: 'prod_1',
        status: 'ARCHIVED',
      });

      const result = await service.toggleArchive('biz_1', 'prod_1');
      expect(result.status).toBe('ARCHIVED');
    });
  });

  describe('delete', () => {
    it('should reject deletion if product is referenced by invoices or purchases', async () => {
      mockPrisma.product.findUnique.mockResolvedValueOnce({ id: 'prod_1', businessId: 'biz_1' });
      mockPrisma.invoiceItem.count.mockResolvedValueOnce(3); // 3 invoice items
      mockPrisma.purchaseItem.count.mockResolvedValueOnce(0);
      mockPrisma.quotationItem.count.mockResolvedValueOnce(0);
      mockPrisma.salesOrderItem.count.mockResolvedValueOnce(0);

      await expect(
        service.delete('biz_1', 'prod_1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should delete product when unreferenced by transactions', async () => {
      mockPrisma.product.findUnique.mockResolvedValueOnce({ id: 'prod_1', businessId: 'biz_1' });
      mockPrisma.invoiceItem.count.mockResolvedValueOnce(0);
      mockPrisma.purchaseItem.count.mockResolvedValueOnce(0);
      mockPrisma.quotationItem.count.mockResolvedValueOnce(0);
      mockPrisma.salesOrderItem.count.mockResolvedValueOnce(0);
      mockPrisma.product.delete.mockResolvedValueOnce({ id: 'prod_1' });

      const result = await service.delete('biz_1', 'prod_1');
      expect(result.success).toBe(true);
    });
  });
});

