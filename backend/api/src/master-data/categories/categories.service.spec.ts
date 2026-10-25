import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { CategoriesService } from './categories.service';
import { PrismaService } from '../../database/prisma.service';

describe('CategoriesService', () => {
  let service: CategoriesService;
  let mockPrisma: any;

  beforeEach(async () => {
    mockPrisma = {
      category: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        count: jest.fn(),
      },
      product: {
        count: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CategoriesService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
      ],
    }).compile();

    service = module.get<CategoriesService>(CategoriesService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('should create a category successfully', async () => {
      mockPrisma.category.findUnique.mockResolvedValueOnce(null);
      mockPrisma.category.create.mockResolvedValueOnce({
        id: 'cat_1',
        businessId: 'biz_1',
        name: 'Electronics',
        parentId: null,
      });

      const result = await service.create('biz_1', { name: 'Electronics' });
      expect(result).toHaveProperty('id', 'cat_1');
      expect(result.name).toBe('Electronics');
    });

    it('should throw ConflictException if category name already exists in same business', async () => {
      mockPrisma.category.findUnique.mockResolvedValueOnce({
        id: 'cat_existing',
        name: 'Electronics',
      });

      await expect(
        service.create('biz_1', { name: 'Electronics' }),
      ).rejects.toThrow(ConflictException);
    });

    it('should throw NotFoundException if parent category does not exist in business', async () => {
      mockPrisma.category.findUnique
        .mockResolvedValueOnce(null) // for duplicate check
        .mockResolvedValueOnce(null); // for parent check

      await expect(
        service.create('biz_1', { name: 'Mobile Phones', parentId: 'non_existent_parent' }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('delete', () => {
    it('should reject deletion if category is referenced by products', async () => {
      mockPrisma.category.findUnique.mockResolvedValueOnce({
        id: 'cat_1',
        businessId: 'biz_1',
        name: 'Groceries',
      });
      mockPrisma.product.count.mockResolvedValueOnce(5); // 5 products reference it

      await expect(
        service.delete('biz_1', 'cat_1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should successfully delete category if not referenced', async () => {
      mockPrisma.category.findUnique.mockResolvedValueOnce({
        id: 'cat_1',
        businessId: 'biz_1',
        name: 'Unused Category',
      });
      mockPrisma.product.count.mockResolvedValueOnce(0);
      mockPrisma.category.count.mockResolvedValueOnce(0); // child categories
      mockPrisma.category.delete.mockResolvedValueOnce({ id: 'cat_1' });

      const result = await service.delete('biz_1', 'cat_1');
      expect(result.success).toBe(true);
    });
  });
});

