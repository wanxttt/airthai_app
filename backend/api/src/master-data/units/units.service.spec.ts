import { BadRequestException, ConflictException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { UnitsService } from './units.service';
import { PrismaService } from '../../database/prisma.service';

describe('UnitsService', () => {
  let service: UnitsService;
  let mockPrisma: any;

  beforeEach(async () => {
    mockPrisma = {
      unit: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      product: {
        count: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UnitsService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
      ],
    }).compile();

    service = module.get<UnitsService>(UnitsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('should create a unit successfully', async () => {
      mockPrisma.unit.findUnique.mockResolvedValueOnce(null);
      mockPrisma.unit.create.mockResolvedValueOnce({
        id: 'unit_1',
        businessId: 'biz_1',
        name: 'Kilogram',
        symbol: 'kg',
      });

      const result = await service.create('biz_1', { name: 'Kilogram', symbol: 'kg' });
      expect(result).toHaveProperty('id', 'unit_1');
      expect(result.symbol).toBe('kg');
    });

    it('should throw ConflictException if unit symbol already exists in business', async () => {
      mockPrisma.unit.findUnique.mockResolvedValueOnce({
        id: 'unit_existing',
        symbol: 'kg',
      });

      await expect(
        service.create('biz_1', { name: 'Kilogram', symbol: 'kg' }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('delete', () => {
    it('should reject deletion if unit is referenced by products', async () => {
      mockPrisma.unit.findUnique.mockResolvedValueOnce({
        id: 'unit_1',
        businessId: 'biz_1',
        name: 'Piece',
        symbol: 'pcs',
      });
      mockPrisma.product.count.mockResolvedValueOnce(12); // 12 products reference it

      await expect(
        service.delete('biz_1', 'unit_1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should successfully delete unit if not referenced by products', async () => {
      mockPrisma.unit.findUnique.mockResolvedValueOnce({
        id: 'unit_1',
        businessId: 'biz_1',
        name: 'Unused Unit',
        symbol: 'xyz',
      });
      mockPrisma.product.count.mockResolvedValueOnce(0);
      mockPrisma.unit.delete.mockResolvedValueOnce({ id: 'unit_1' });

      const result = await service.delete('biz_1', 'unit_1');
      expect(result.success).toBe(true);
    });
  });
});

