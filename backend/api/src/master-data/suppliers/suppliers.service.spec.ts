import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { SuppliersService } from './suppliers.service';
import { PrismaService } from '../../database/prisma.service';

describe('SuppliersService', () => {
  let service: SuppliersService;
  let mockPrisma: any;

  beforeEach(async () => {
    mockPrisma = {
      supplier: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        count: jest.fn(),
        aggregate: jest.fn(),
      },
      purchase: {
        count: jest.fn(),
      },
      payment: {
        count: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SuppliersService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
      ],
    }).compile();

    service = module.get<SuppliersService>(SuppliersService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('should create supplier with bank details and opening balance', async () => {
      mockPrisma.supplier.create.mockResolvedValueOnce({
        id: 'supp_1',
        businessId: 'biz_1',
        name: 'Vikas Wholesalers',
        phone: '9876500000',
        openingBalance: 12000,
        currentBalance: 12000,
        status: 'ACTIVE',
      });

      const result = await service.create('biz_1', {
        name: 'Vikas Wholesalers',
        phone: '9876500000',
        openingBalance: 12000,
      });

      expect(result).toHaveProperty('id', 'supp_1');
      expect(result.currentBalance).toBe(12000);
    });
  });

  describe('findAll', () => {
    it('should list suppliers and calculate total payables', async () => {
      mockPrisma.supplier.count.mockResolvedValueOnce(1);
      mockPrisma.supplier.findMany.mockResolvedValueOnce([
        { id: 'supp_1', name: 'Vikas Wholesalers', currentBalance: 12000 },
      ]);
      mockPrisma.supplier.aggregate.mockResolvedValueOnce({
        _sum: { currentBalance: 12000 },
      });

      const result = await service.findAll('biz_1', { page: 1, limit: 10 });
      expect(result.data.length).toBe(1);
      expect(result.summary.totalPayables).toBe(12000);
    });
  });

  describe('delete', () => {
    it('should reject deletion if supplier has purchases', async () => {
      mockPrisma.supplier.findUnique.mockResolvedValueOnce({ id: 'supp_1', businessId: 'biz_1' });
      mockPrisma.purchase.count.mockResolvedValueOnce(4);
      mockPrisma.payment.count.mockResolvedValueOnce(0);

      await expect(
        service.delete('biz_1', 'supp_1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should delete supplier if no purchases exist', async () => {
      mockPrisma.supplier.findUnique.mockResolvedValueOnce({ id: 'supp_1', businessId: 'biz_1' });
      mockPrisma.purchase.count.mockResolvedValueOnce(0);
      mockPrisma.payment.count.mockResolvedValueOnce(0);
      mockPrisma.supplier.delete.mockResolvedValueOnce({ id: 'supp_1' });

      const result = await service.delete('biz_1', 'supp_1');
      expect(result.success).toBe(true);
    });
  });
});

