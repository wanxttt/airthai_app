import { Test, TestingModule } from '@nestjs/testing';
import { QuotationsService } from './quotations.service';
import { InvoicesService } from './invoices.service';
import { SequenceService } from './sequence.service';
import { PrismaService } from '../database/prisma.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

describe('QuotationsService', () => {
  let service: QuotationsService;
  let prisma: any;
  let sequenceService: any;
  let invoicesService: any;

  const mockBusinessId = 'biz_test_123';
  const mockUserId = 'usr_test_123';

  beforeEach(async () => {
    prisma = {
      quotation: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
    };

    sequenceService = {
      getNextNumber: jest.fn().mockResolvedValue('QUO-2026-27-0001'),
      getFiscalYear: jest.fn().mockReturnValue('2026-27'),
    };

    invoicesService = {
      create: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        QuotationsService,
        { provide: PrismaService, useValue: prisma },
        { provide: SequenceService, useValue: sequenceService },
        { provide: InvoicesService, useValue: invoicesService },
      ],
    }).compile();

    service = module.get<QuotationsService>(QuotationsService);
  });

  describe('create', () => {
    it('creates a quotation with sequential numbering and line items', async () => {
      prisma.quotation.create.mockImplementation(({ data }) => ({
        id: 'quo_1',
        ...data,
      }));

      const result = await service.create(mockBusinessId, {
        customerId: 'cust_1',
        items: [
          {
            description: 'Consulting & Setup',
            quantity: 1,
            unitPrice: 5000,
            gstRate: 18,
          },
        ],
      });

      expect(result.success).toBe(true);
      expect(sequenceService.getNextNumber).toHaveBeenCalledWith(
        mockBusinessId,
        'QUOTATION',
        'QUO',
        expect.any(Date),
      );
      expect(prisma.quotation.create).toHaveBeenCalled();
    });

    it('rejects quotation without items', async () => {
      await expect(
        service.create(mockBusinessId, { items: [] }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('convertToInvoice', () => {
    it('converts quotation to invoice and marks quotation status CONVERTED', async () => {
      const mockQuotation = {
        id: 'quo_100',
        businessId: mockBusinessId,
        customerId: 'cust_1',
        quotationNumber: 'QUO-2026-27-0010',
        status: 'DRAFT',
        discountAmount: new Prisma.Decimal(0),
        taxAmount: new Prisma.Decimal(900),
        customer: { state: '27' },
        items: [
          {
            productId: 'prod_1',
            description: 'Item 1',
            quantity: new Prisma.Decimal(2),
            unitPrice: new Prisma.Decimal(2500),
            discountAmount: new Prisma.Decimal(0),
            taxAmount: new Prisma.Decimal(900),
          },
        ],
      };

      prisma.quotation.findUnique.mockResolvedValue(mockQuotation);
      invoicesService.create.mockResolvedValue({
        success: true,
        statusCode: 201,
        data: { id: 'inv_from_quo_1' },
      });
      prisma.quotation.update.mockResolvedValue({
        ...mockQuotation,
        status: 'CONVERTED',
      });

      const result = await service.convertToInvoice(mockBusinessId, 'quo_100', mockUserId);

      expect(result.success).toBe(true);
      expect(invoicesService.create).toHaveBeenCalledWith(
        mockBusinessId,
        expect.objectContaining({
          customerId: 'cust_1',
          items: expect.arrayContaining([
            expect.objectContaining({ description: 'Item 1', quantity: 2, unitPrice: 2500 }),
          ]),
        }),
        mockUserId,
      );
      expect(prisma.quotation.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'quo_100' } },
        data: { status: 'CONVERTED' },
      });
    });

    it('rejects conversion if quotation is already CONVERTED', async () => {
      prisma.quotation.findUnique.mockResolvedValue({
        id: 'quo_already_converted',
        businessId: mockBusinessId,
        status: 'CONVERTED',
      });

      await expect(
        service.convertToInvoice(mockBusinessId, 'quo_already_converted', mockUserId),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
