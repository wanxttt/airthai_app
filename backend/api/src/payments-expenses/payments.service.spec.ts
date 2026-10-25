import { Test, TestingModule } from '@nestjs/testing';
import { PaymentsService } from './payments.service';
import { PrismaService } from '../database/prisma.service';
import { SequenceService } from '../sales/sequence.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PaymentType, PaymentMethod, Prisma } from '@prisma/client';

describe('PaymentsService', () => {
  let service: PaymentsService;
  let mockPrisma: any;
  let mockSequenceService: any;

  const mockBusinessId = 'biz_test_123';
  const mockUserId = 'usr_test_123';
  const mockCustomerId = 'cust_001';
  const mockSupplierId = 'supp_001';

  beforeEach(async () => {
    mockSequenceService = {
      getNextNumber: jest.fn().mockImplementation((bizId, type, prefix) => {
        if (type === 'RECEIPT') return Promise.resolve('REC-2026-27-0001');
        if (type === 'PAYMENT') return Promise.resolve('PAY-2026-27-0001');
        return Promise.resolve('DOC-0001');
      }),
    };

    mockPrisma = {
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return callback(mockPrisma);
      }),
      customer: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      supplier: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      invoice: {
        findUnique: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn(),
      },
      purchase: {
        findUnique: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn(),
      },
      payment: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        delete: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
      },
      paymentAllocation: {
        create: jest.fn(),
        deleteMany: jest.fn(),
      },
      auditLog: {
        create: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: SequenceService, useValue: mockSequenceService },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
  });

  describe('recordCustomerReceipt', () => {
    it('successfully records full customer receipt allocated to an invoice', async () => {
      mockPrisma.customer.findUnique.mockResolvedValue({
        id: mockCustomerId,
        businessId: mockBusinessId,
        name: 'Alpha Traders',
        currentBalance: new Prisma.Decimal(5000),
        status: 'ACTIVE',
      });

      mockPrisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_001',
        businessId: mockBusinessId,
        customerId: mockCustomerId,
        invoiceNumber: 'INV-2026-27-0001',
        totalAmount: new Prisma.Decimal(5000),
        receivedAmount: new Prisma.Decimal(0),
        balanceAmount: new Prisma.Decimal(5000),
        status: 'ISSUED',
      });

      mockPrisma.payment.create.mockResolvedValue({
        id: 'pay_rec_001',
        businessId: mockBusinessId,
        paymentNumber: 'REC-2026-27-0001',
        amount: new Prisma.Decimal(5000),
      });

      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_001',
        paymentNumber: 'REC-2026-27-0001',
        amount: new Prisma.Decimal(5000),
      });

      const result = await service.recordCustomerReceipt(
        mockBusinessId,
        {
          paymentType: PaymentType.CUSTOMER_RECEIPT,
          customerId: mockCustomerId,
          amount: 5000,
          paymentMethod: PaymentMethod.UPI,
          referenceNumber: 'UPI/20261025/12345',
          allocations: [{ invoiceId: 'inv_001', amount: 5000 }],
        },
        mockUserId,
      );

      expect(result).toBeDefined();
      expect(mockSequenceService.getNextNumber).toHaveBeenCalledWith(
        mockBusinessId,
        'RECEIPT',
        'REC',
        expect.any(Date),
        expect.anything(),
      );

      // Verify invoice updated to PAID with 0 balance
      expect(mockPrisma.invoice.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'inv_001' } },
        data: {
          receivedAmount: new Prisma.Decimal(5000),
          balanceAmount: new Prisma.Decimal(0),
          status: 'PAID',
        },
      });

      // Verify customer current balance decremented by payment amount
      expect(mockPrisma.customer.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: mockCustomerId } },
        data: {
          currentBalance: {
            decrement: new Prisma.Decimal(5000),
          },
        },
      });
    });

    it('successfully records partial customer payment and sets status to PARTIALLY_PAID', async () => {
      mockPrisma.customer.findUnique.mockResolvedValue({
        id: mockCustomerId,
        businessId: mockBusinessId,
        status: 'ACTIVE',
      });

      mockPrisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_002',
        businessId: mockBusinessId,
        customerId: mockCustomerId,
        invoiceNumber: 'INV-2026-27-0002',
        totalAmount: new Prisma.Decimal(10000),
        receivedAmount: new Prisma.Decimal(0),
        balanceAmount: new Prisma.Decimal(10000),
        status: 'ISSUED',
      });

      mockPrisma.payment.create.mockResolvedValue({ id: 'pay_002' });
      mockPrisma.payment.findUnique.mockResolvedValue({ id: 'pay_002' });

      await service.recordCustomerReceipt(
        mockBusinessId,
        {
          paymentType: PaymentType.CUSTOMER_RECEIPT,
          customerId: mockCustomerId,
          amount: 4000,
          paymentMethod: PaymentMethod.BANK_TRANSFER,
          allocations: [{ invoiceId: 'inv_002', amount: 4000 }],
        },
        mockUserId,
      );

      expect(mockPrisma.invoice.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'inv_002' } },
        data: {
          receivedAmount: new Prisma.Decimal(4000),
          balanceAmount: new Prisma.Decimal(6000),
          status: 'PARTIALLY_PAID',
        },
      });
    });

    it('rejects over-allocation where allocated amount exceeds invoice balance', async () => {
      mockPrisma.customer.findUnique.mockResolvedValue({
        id: mockCustomerId,
        businessId: mockBusinessId,
        status: 'ACTIVE',
      });

      mockPrisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_003',
        businessId: mockBusinessId,
        customerId: mockCustomerId,
        invoiceNumber: 'INV-003',
        balanceAmount: new Prisma.Decimal(2000),
        status: 'ISSUED',
      });

      await expect(
        service.recordCustomerReceipt(
          mockBusinessId,
          {
            paymentType: PaymentType.CUSTOMER_RECEIPT,
            customerId: mockCustomerId,
            amount: 3000,
            paymentMethod: PaymentMethod.CASH,
            allocations: [{ invoiceId: 'inv_003', amount: 3000 }], // 3000 > 2000 balance!
          },
          mockUserId,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects allocation when invoice belongs to a different customer', async () => {
      mockPrisma.customer.findUnique.mockResolvedValue({
        id: mockCustomerId,
        businessId: mockBusinessId,
        status: 'ACTIVE',
      });

      mockPrisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_other',
        businessId: mockBusinessId,
        customerId: 'different_cust_999', // Mismatched customer!
        invoiceNumber: 'INV-OTHER',
        balanceAmount: new Prisma.Decimal(1000),
        status: 'ISSUED',
      });

      await expect(
        service.recordCustomerReceipt(
          mockBusinessId,
          {
            paymentType: PaymentType.CUSTOMER_RECEIPT,
            customerId: mockCustomerId,
            amount: 1000,
            paymentMethod: PaymentMethod.CASH,
            allocations: [{ invoiceId: 'inv_other', amount: 1000 }],
          },
          mockUserId,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('returns existing payment for duplicate clientOperationId idempotency check', async () => {
      const existing = {
        id: 'pay_existing',
        paymentNumber: 'REC-2026-27-0001',
        clientOperationId: 'idem_rec_123',
      };
      mockPrisma.payment.findFirst.mockResolvedValue(existing);

      const result = await service.recordCustomerReceipt(mockBusinessId, {
        paymentType: PaymentType.CUSTOMER_RECEIPT,
        customerId: mockCustomerId,
        amount: 5000,
        paymentMethod: PaymentMethod.UPI,
        clientOperationId: 'idem_rec_123',
      });

      expect(result).toBe(existing);
      expect(mockPrisma.payment.create).not.toHaveBeenCalled();
    });
  });

  describe('recordSupplierPayment', () => {
    it('successfully records supplier payment and updates purchase status to PAID', async () => {
      mockPrisma.supplier.findUnique.mockResolvedValue({
        id: mockSupplierId,
        businessId: mockBusinessId,
        name: 'Apex Industrial Parts',
        currentBalance: new Prisma.Decimal(12000),
        status: 'ACTIVE',
      });

      mockPrisma.purchase.findUnique.mockResolvedValue({
        id: 'pur_001',
        businessId: mockBusinessId,
        supplierId: mockSupplierId,
        billNumber: 'BILL-8899',
        totalAmount: new Prisma.Decimal(12000),
        paidAmount: new Prisma.Decimal(0),
        balanceAmount: new Prisma.Decimal(12000),
        status: 'RECEIVED',
        paymentStatus: 'UNPAID',
      });

      mockPrisma.payment.create.mockResolvedValue({ id: 'pay_supp_001' });
      mockPrisma.payment.findUnique.mockResolvedValue({ id: 'pay_supp_001' });

      const result = await service.recordSupplierPayment(
        mockBusinessId,
        {
          paymentType: PaymentType.SUPPLIER_PAYMENT,
          supplierId: mockSupplierId,
          amount: 12000,
          paymentMethod: PaymentMethod.BANK_TRANSFER,
          referenceNumber: 'NEFT/AXIS/998877',
          allocations: [{ purchaseId: 'pur_001', amount: 12000 }],
        },
        mockUserId,
      );

      expect(result).toBeDefined();
      expect(mockSequenceService.getNextNumber).toHaveBeenCalledWith(
        mockBusinessId,
        'PAYMENT',
        'PAY',
        expect.any(Date),
        expect.anything(),
      );

      // Verify purchase updated to PAID
      expect(mockPrisma.purchase.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'pur_001' } },
        data: {
          paidAmount: new Prisma.Decimal(12000),
          balanceAmount: new Prisma.Decimal(0),
          paymentStatus: 'PAID',
        },
      });

      // Verify supplier payable balance decremented
      expect(mockPrisma.supplier.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: mockSupplierId } },
        data: {
          currentBalance: {
            decrement: new Prisma.Decimal(12000),
          },
        },
      });
    });

    it('rejects over-allocation where allocated amount exceeds bill balance', async () => {
      mockPrisma.supplier.findUnique.mockResolvedValue({
        id: mockSupplierId,
        businessId: mockBusinessId,
        status: 'ACTIVE',
      });

      mockPrisma.purchase.findUnique.mockResolvedValue({
        id: 'pur_002',
        businessId: mockBusinessId,
        supplierId: mockSupplierId,
        billNumber: 'BILL-777',
        balanceAmount: new Prisma.Decimal(1000),
        status: 'RECEIVED',
      });

      await expect(
        service.recordSupplierPayment(
          mockBusinessId,
          {
            paymentType: PaymentType.SUPPLIER_PAYMENT,
            supplierId: mockSupplierId,
            amount: 2000,
            paymentMethod: PaymentMethod.CHEQUE,
            allocations: [{ purchaseId: 'pur_002', amount: 2000 }],
          },
          mockUserId,
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('voidPayment', () => {
    it('successfully voids customer receipt, restores invoice balances and customer balance', async () => {
      const mockPayment = {
        id: 'pay_void_01',
        paymentNumber: 'REC-2026-27-0001',
        businessId: mockBusinessId,
        paymentType: PaymentType.CUSTOMER_RECEIPT,
        customerId: mockCustomerId,
        amount: new Prisma.Decimal(3000),
        allocations: [
          {
            id: 'alloc_01',
            invoiceId: 'inv_void_01',
            amount: new Prisma.Decimal(3000),
          },
        ],
      };

      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);

      mockPrisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_void_01',
        businessId: mockBusinessId,
        totalAmount: new Prisma.Decimal(3000),
        receivedAmount: new Prisma.Decimal(3000),
        balanceAmount: new Prisma.Decimal(0),
        status: 'PAID',
      });

      const result = await service.voidPayment(
        mockBusinessId,
        'pay_void_01',
        { reason: 'Cheque bounced' },
        mockUserId,
      );

      expect(result.success).toBe(true);

      // Verify invoice balance restored and status reset to ISSUED
      expect(mockPrisma.invoice.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'inv_void_01' } },
        data: {
          receivedAmount: new Prisma.Decimal(0),
          balanceAmount: new Prisma.Decimal(3000),
          status: 'ISSUED',
        },
      });

      // Verify customer balance incremented back
      expect(mockPrisma.customer.update).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: mockCustomerId } },
        data: {
          currentBalance: {
            increment: new Prisma.Decimal(3000),
          },
        },
      });

      // Verify payment deleted
      expect(mockPrisma.payment.delete).toHaveBeenCalledWith({
        where: { businessId_id: { businessId: mockBusinessId, id: 'pay_void_01' } },
      });
    });
  });

  describe('Outstanding Balance Queries', () => {
    it('returns customer balance and outstanding invoices', async () => {
      mockPrisma.customer.findUnique.mockResolvedValue({
        id: mockCustomerId,
        name: 'Tech Corp',
        phone: '9988776655',
        currentBalance: new Prisma.Decimal(4500),
      });

      mockPrisma.invoice.findMany.mockResolvedValue([
        {
          id: 'inv_open_1',
          invoiceNumber: 'INV-001',
          totalAmount: new Prisma.Decimal(5000),
          balanceAmount: new Prisma.Decimal(4500),
          status: 'PARTIALLY_PAID',
        },
      ]);

      const res = await service.getCustomerOutstanding(mockBusinessId, mockCustomerId);
      expect(res.customer.name).toBe('Tech Corp');
      expect(res.outstandingInvoices.length).toBe(1);
    });
  });
});
