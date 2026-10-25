import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { CustomersService } from './customers.service';
import { PrismaService } from '../../database/prisma.service';

describe('CustomersService', () => {
  let service: CustomersService;
  let mockPrisma: any;

  beforeEach(async () => {
    mockPrisma = {
      customer: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        count: jest.fn(),
        aggregate: jest.fn(),
      },
      invoice: {
        count: jest.fn(),
      },
      payment: {
        count: jest.fn(),
      },
      salesOrder: {
        count: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CustomersService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
      ],
    }).compile();

    service = module.get<CustomersService>(CustomersService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('should create customer with opening balance and contact details', async () => {
      mockPrisma.customer.create.mockResolvedValueOnce({
        id: 'cust_1',
        businessId: 'biz_1',
        name: 'Gupta Traders',
        phone: '9876543210',
        openingBalance: 5000,
        currentBalance: 5000,
        status: 'ACTIVE',
      });

      const result = await service.create('biz_1', {
        name: 'Gupta Traders',
        phone: '9876543210',
        openingBalance: 5000,
      });

      expect(result).toHaveProperty('id', 'cust_1');
      expect(result.currentBalance).toBe(5000);
    });
  });

  describe('findAll', () => {
    it('should list customers and calculate total receivables', async () => {
      mockPrisma.customer.count.mockResolvedValueOnce(1);
      mockPrisma.customer.findMany.mockResolvedValueOnce([
        { id: 'cust_1', name: 'Gupta Traders', currentBalance: 5000 },
      ]);
      mockPrisma.customer.aggregate.mockResolvedValueOnce({
        _sum: { currentBalance: 5000 },
      });

      const result = await service.findAll('biz_1', { page: 1, limit: 10 });
      expect(result.data.length).toBe(1);
      expect(result.summary.totalReceivables).toBe(5000);
    });
  });

  describe('delete', () => {
    it('should reject deletion if customer has invoices', async () => {
      mockPrisma.customer.findUnique.mockResolvedValueOnce({ id: 'cust_1', businessId: 'biz_1' });
      mockPrisma.invoice.count.mockResolvedValueOnce(2);
      mockPrisma.payment.count.mockResolvedValueOnce(0);
      mockPrisma.salesOrder.count.mockResolvedValueOnce(0);

      await expect(
        service.delete('biz_1', 'cust_1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should delete customer if no transactions exist', async () => {
      mockPrisma.customer.findUnique.mockResolvedValueOnce({ id: 'cust_1', businessId: 'biz_1' });
      mockPrisma.invoice.count.mockResolvedValueOnce(0);
      mockPrisma.payment.count.mockResolvedValueOnce(0);
      mockPrisma.salesOrder.count.mockResolvedValueOnce(0);
      mockPrisma.customer.delete.mockResolvedValueOnce({ id: 'cust_1' });

      const result = await service.delete('biz_1', 'cust_1');
      expect(result.success).toBe(true);
    });
  });
});

