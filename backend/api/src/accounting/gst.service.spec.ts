import { Test, TestingModule } from '@nestjs/testing';
import { GstService, GST_STATUTORY_DISCLAIMER } from './gst.service';
import { PrismaService } from '../database/prisma.service';
import { Prisma } from '@prisma/client';

describe('GstService', () => {
  let service: GstService;
  let prisma: any;

  const mockBusinessId = 'biz_test_gst_001';

  beforeEach(async () => {
    prisma = {
      gstRecord: {
        findMany: jest.fn(),
      },
      expense: {
        findMany: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        GstService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<GstService>(GstService);
  });

  describe('getGstr1Summary', () => {
    it('should aggregate B2B, B2C and HSN summary correctly and include statutory disclaimer', async () => {
      const records = [
        // B2B Record
        {
          id: 'gst_1',
          transactionType: 'B2B',
          invoiceId: 'inv_1',
          gstin: '27AABCU9603R1ZM',
          placeOfSupply: '27',
          taxableValue: new Prisma.Decimal('10000.00'),
          cgstAmount: new Prisma.Decimal('900.00'),
          sgstAmount: new Prisma.Decimal('900.00'),
          igstAmount: new Prisma.Decimal(0),
          cessAmount: new Prisma.Decimal(0),
          invoice: {
            invoiceNumber: 'INV-001',
            invoiceDate: new Date('2026-10-15'),
            totalAmount: new Prisma.Decimal('11800.00'),
            customer: { name: 'Titan Industries' },
            items: [
              {
                hsnCode: '8471',
                description: 'Industrial Sensor',
                quantity: new Prisma.Decimal(10),
                taxableAmount: new Prisma.Decimal('10000.00'),
                cgstAmount: new Prisma.Decimal('900.00'),
                sgstAmount: new Prisma.Decimal('900.00'),
                igstAmount: new Prisma.Decimal(0),
              },
            ],
          },
        },
        // B2C Record
        {
          id: 'gst_2',
          transactionType: 'B2C',
          invoiceId: 'inv_2',
          gstin: null,
          placeOfSupply: '27',
          taxableValue: new Prisma.Decimal('2000.00'),
          cgstAmount: new Prisma.Decimal('180.00'),
          sgstAmount: new Prisma.Decimal('180.00'),
          igstAmount: new Prisma.Decimal(0),
          cessAmount: new Prisma.Decimal(0),
          invoice: {
            invoiceNumber: 'INV-002',
            invoiceDate: new Date('2026-10-18'),
            totalAmount: new Prisma.Decimal('2360.00'),
            customer: null,
            items: [
              {
                hsnCode: '8471',
                description: 'Industrial Sensor',
                quantity: new Prisma.Decimal(2),
                taxableAmount: new Prisma.Decimal('2000.00'),
                cgstAmount: new Prisma.Decimal('180.00'),
                sgstAmount: new Prisma.Decimal('180.00'),
                igstAmount: new Prisma.Decimal(0),
              },
            ],
          },
        },
      ];

      prisma.gstRecord.findMany.mockResolvedValue(records);

      const res = await service.getGstr1Summary(mockBusinessId, { returnPeriod: '2026-10' });

      expect(res.statusCode).toBe(200);
      expect(res.disclaimer).toBe(GST_STATUTORY_DISCLAIMER);
      expect(res.data.totalTaxableValue).toBe(12000);
      expect(res.data.totalCgst).toBe(1080);
      expect(res.data.totalSgst).toBe(1080);
      expect(res.data.totalTaxLiability).toBe(2160);

      // Check Table 4 B2B
      expect(res.data.table4B2B.count).toBe(1);
      expect(res.data.table4B2B.invoices[0].customerGstin).toBe('27AABCU9603R1ZM');

      // Check Table 7 B2C
      expect(res.data.table7B2C.count).toBe(1);

      // Check Table 12 HSN Summary (merged both lines under 8471)
      expect(res.data.table12HsnSummary.length).toBe(1);
      expect(res.data.table12HsnSummary[0].hsnCode).toBe('8471');
      expect(res.data.table12HsnSummary[0].quantity).toBe(12); // 10 + 2
      expect(res.data.table12HsnSummary[0].taxableValue).toBe(12000);
    });
  });

  describe('getGstr3bSummary', () => {
    it('should compute outward liability, inward ITC and net tax payable with offset', async () => {
      // Outward sales records
      prisma.gstRecord.findMany
        .mockResolvedValueOnce([
          {
            taxableValue: new Prisma.Decimal('50000.00'),
            cgstAmount: new Prisma.Decimal('4500.00'),
            sgstAmount: new Prisma.Decimal('4500.00'),
            igstAmount: new Prisma.Decimal(0),
            cessAmount: new Prisma.Decimal(0),
          },
        ])
        // Inward purchase records (ITC)
        .mockResolvedValueOnce([
          {
            taxableValue: new Prisma.Decimal('30000.00'),
            cgstAmount: new Prisma.Decimal('2700.00'),
            sgstAmount: new Prisma.Decimal('2700.00'),
            igstAmount: new Prisma.Decimal(0),
          },
        ]);

      // Eligible expenses
      prisma.expense.findMany.mockResolvedValueOnce([
        {
          amount: new Prisma.Decimal('590.00'),
          gstAmount: new Prisma.Decimal('90.00'),
        },
      ]);

      const res = await service.getGstr3bSummary(mockBusinessId, { returnPeriod: '2026-10' });

      expect(res.statusCode).toBe(200);
      expect(res.disclaimer).toBe(GST_STATUTORY_DISCLAIMER);

      // Table 3.1 Outward supplies
      expect(res.data.table31OutwardSupplies.taxableValue).toBe(50000);
      expect(res.data.table31OutwardSupplies.cgstAmount).toBe(4500);
      expect(res.data.table31OutwardSupplies.sgstAmount).toBe(4500);

      // Table 4 Eligible ITC: 2700 (purchase) + 45 (expense half) = 2745
      expect(res.data.table4EligibleItc.cgstAmount).toBe(2745);
      expect(res.data.table4EligibleItc.sgstAmount).toBe(2745);

      // Net Tax Payable: 4500 - 2745 = 1755 each
      expect(res.data.netTaxPayable.cgst).toBe(1755);
      expect(res.data.netTaxPayable.sgst).toBe(1755);
      expect(res.data.netTaxPayable.totalPayable).toBe(3510);
    });
  });
});
