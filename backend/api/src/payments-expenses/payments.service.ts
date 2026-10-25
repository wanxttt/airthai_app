import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  Logger,
  Optional,
} from '@nestjs/common';
import { AccountingService } from '../accounting/accounting.service';
import { PrismaService } from '../database/prisma.service';
import { SequenceService } from '../sales/sequence.service';
import { CreatePaymentDto, VoidPaymentDto } from './dto/create-payment.dto';
import { QueryPaymentsDto } from './dto/query-payments.dto';
import { PaymentType, PaymentMethod, Prisma } from '@prisma/client';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
    @Optional() private readonly accountingService?: AccountingService,
  ) {}

  /**
   * Record Customer Receipt (Cash Inflow).
   * Validates customer, allocations against invoices, ensures no over-allocation,
   * updates invoice balances & status, updates customer current balance atomically.
   */
  async recordCustomerReceipt(businessId: string, dto: CreatePaymentDto, userId?: string) {
    if (dto.paymentType !== PaymentType.CUSTOMER_RECEIPT) {
      throw new BadRequestException('Payment type must be CUSTOMER_RECEIPT.');
    }
    if (!dto.customerId) {
      throw new BadRequestException('customerId is required for customer receipts.');
    }

    const paymentAmount = new Prisma.Decimal(dto.amount);
    if (paymentAmount.lte(0)) {
      throw new BadRequestException('Payment amount must be greater than zero.');
    }

    // Idempotency check
    if (dto.clientOperationId) {
      const existing = await this.prisma.payment.findFirst({
        where: { businessId, clientOperationId: dto.clientOperationId },
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          allocations: {
            include: {
              invoice: { select: { id: true, invoiceNumber: true, totalAmount: true, balanceAmount: true } },
            },
          },
        },
      });
      if (existing) {
        return existing;
      }
    }

    return this.prisma.$transaction(async (tx) => {
      // 1. Verify Customer
      const customer = await tx.customer.findUnique({
        where: { businessId_id: { businessId, id: dto.customerId! } },
      });
      if (!customer) {
        throw new NotFoundException(`Customer with ID ${dto.customerId} not found.`);
      }
      if (customer.status === 'ARCHIVED') {
        throw new BadRequestException('Cannot record receipt for an archived customer.');
      }

      // 2. Validate Allocations
      let totalAllocated = new Prisma.Decimal(0);
      const allocationData: { invoiceId: string; amount: Prisma.Decimal }[] = [];

      if (dto.allocations && dto.allocations.length > 0) {
        const seenInvoices = new Set<string>();

        for (const alloc of dto.allocations) {
          if (!alloc.invoiceId) {
            throw new BadRequestException('Each allocation for a customer receipt must specify an invoiceId.');
          }
          if (seenInvoices.has(alloc.invoiceId)) {
            throw new BadRequestException(`Duplicate allocation for invoice ${alloc.invoiceId} in the same receipt.`);
          }
          seenInvoices.add(alloc.invoiceId);

          const allocAmount = new Prisma.Decimal(alloc.amount);
          if (allocAmount.lte(0)) {
            throw new BadRequestException('Allocation amount must be greater than zero.');
          }

          // Fetch Invoice to validate ownership, customer match, and available balance
          const invoice = await tx.invoice.findUnique({
            where: { businessId_id: { businessId, id: alloc.invoiceId } },
          });

          if (!invoice) {
            throw new NotFoundException(`Invoice with ID ${alloc.invoiceId} not found in this business.`);
          }
          if (invoice.customerId !== dto.customerId) {
            throw new BadRequestException(
              `Invoice ${invoice.invoiceNumber} belongs to a different customer than the receipt customer.`,
            );
          }
          if (invoice.status === 'CANCELLED' || invoice.status === 'DRAFT') {
            throw new BadRequestException(
              `Cannot allocate payment to invoice ${invoice.invoiceNumber} with status ${invoice.status}.`,
            );
          }
          if (allocAmount.gt(invoice.balanceAmount)) {
            throw new BadRequestException(
              `Allocation of ₹${allocAmount.toFixed(2)} exceeds invoice ${invoice.invoiceNumber} outstanding balance of ₹${invoice.balanceAmount.toFixed(2)}.`,
            );
          }

          totalAllocated = totalAllocated.plus(allocAmount);
          allocationData.push({ invoiceId: alloc.invoiceId, amount: allocAmount });
        }

        if (totalAllocated.gt(paymentAmount)) {
          throw new BadRequestException(
            `Total allocated amount (₹${totalAllocated.toFixed(2)}) cannot exceed total receipt amount (₹${paymentAmount.toFixed(2)}).`,
          );
        }
      }

      // 3. Generate Sequence Number
      const paymentDate = dto.paymentDate ? new Date(dto.paymentDate) : new Date();
      const paymentNumber = await this.sequenceService.getNextNumber(
        businessId,
        'RECEIPT',
        'REC',
        paymentDate,
        tx,
      );

      // 4. Create Payment Record
      const payment = await tx.payment.create({
        data: {
          businessId,
          paymentNumber,
          paymentType: PaymentType.CUSTOMER_RECEIPT,
          customerId: dto.customerId,
          paymentDate,
          amount: paymentAmount,
          paymentMethod: dto.paymentMethod,
          referenceNumber: dto.referenceNumber?.trim() || null,
          notes: dto.notes?.trim() || null,
          clientOperationId: dto.clientOperationId || null,
        },
      });

      // 5. Create Allocations & Update Invoices
      for (const alloc of allocationData) {
        await tx.paymentAllocation.create({
          data: {
            businessId,
            paymentId: payment.id,
            invoiceId: alloc.invoiceId,
            amount: alloc.amount,
          },
        });

        const currentInv = await tx.invoice.findUnique({
          where: { businessId_id: { businessId, id: alloc.invoiceId } },
        });

        if (currentInv) {
          const newReceived = currentInv.receivedAmount.plus(alloc.amount);
          const newBalance = currentInv.balanceAmount.minus(alloc.amount);
          const newStatus = newBalance.isZero() ? 'PAID' : 'PARTIALLY_PAID';

          await tx.invoice.update({
            where: { businessId_id: { businessId, id: alloc.invoiceId } },
            data: {
              receivedAmount: newReceived,
              balanceAmount: newBalance,
              status: newStatus,
            },
          });
        }
      }

      // 6. Update Customer Outstanding Balance
      await tx.customer.update({
        where: { businessId_id: { businessId, id: dto.customerId! } },
        data: {
          currentBalance: {
            decrement: paymentAmount,
          },
        },
      });

      // 7. Audit Log
      if (this.accountingService && !payment.amount.isZero()) {
        await this.accountingService.postReceiptJournal(businessId, payment, tx);
      }

      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'CREATE_CUSTOMER_RECEIPT',
          entityName: 'Payment',
          entityId: payment.id,
          newValues: {
            paymentNumber,
            customerId: dto.customerId,
            amount: paymentAmount.toNumber(),
            paymentMethod: dto.paymentMethod,
            allocationsCount: allocationData.length,
          },
        },
      });

      return tx.payment.findUnique({
        where: { businessId_id: { businessId, id: payment.id } },
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          allocations: {
            include: {
              invoice: { select: { id: true, invoiceNumber: true, totalAmount: true, balanceAmount: true } },
            },
          },
        },
      });
    });
  }

  /**
   * Record Supplier Payment (Cash Outflow).
   * Validates supplier, allocations against purchase bills, ensures no over-allocation,
   * updates bill balances & paymentStatus, updates supplier payable balance atomically.
   */
  async recordSupplierPayment(businessId: string, dto: CreatePaymentDto, userId?: string) {
    if (dto.paymentType !== PaymentType.SUPPLIER_PAYMENT) {
      throw new BadRequestException('Payment type must be SUPPLIER_PAYMENT.');
    }
    if (!dto.supplierId) {
      throw new BadRequestException('supplierId is required for supplier payments.');
    }

    const paymentAmount = new Prisma.Decimal(dto.amount);
    if (paymentAmount.lte(0)) {
      throw new BadRequestException('Payment amount must be greater than zero.');
    }

    // Idempotency check
    if (dto.clientOperationId) {
      const existing = await this.prisma.payment.findFirst({
        where: { businessId, clientOperationId: dto.clientOperationId },
        include: {
          supplier: { select: { id: true, name: true, phone: true } },
          allocations: {
            include: {
              purchase: { select: { id: true, billNumber: true, totalAmount: true, balanceAmount: true } },
            },
          },
        },
      });
      if (existing) {
        return existing;
      }
    }

    return this.prisma.$transaction(async (tx) => {
      // 1. Verify Supplier
      const supplier = await tx.supplier.findUnique({
        where: { businessId_id: { businessId, id: dto.supplierId! } },
      });
      if (!supplier) {
        throw new NotFoundException(`Supplier with ID ${dto.supplierId} not found.`);
      }
      if (supplier.status === 'ARCHIVED') {
        throw new BadRequestException('Cannot record payment for an archived supplier.');
      }

      // 2. Validate Allocations
      let totalAllocated = new Prisma.Decimal(0);
      const allocationData: { purchaseId: string; amount: Prisma.Decimal }[] = [];

      if (dto.allocations && dto.allocations.length > 0) {
        const seenPurchases = new Set<string>();

        for (const alloc of dto.allocations) {
          if (!alloc.purchaseId) {
            throw new BadRequestException('Each allocation for a supplier payment must specify a purchaseId.');
          }
          if (seenPurchases.has(alloc.purchaseId)) {
            throw new BadRequestException(`Duplicate allocation for purchase bill ${alloc.purchaseId}.`);
          }
          seenPurchases.add(alloc.purchaseId);

          const allocAmount = new Prisma.Decimal(alloc.amount);
          if (allocAmount.lte(0)) {
            throw new BadRequestException('Allocation amount must be greater than zero.');
          }

          // Fetch Purchase to validate ownership, supplier match, and available balance
          const purchase = await tx.purchase.findUnique({
            where: { businessId_id: { businessId, id: alloc.purchaseId } },
          });

          if (!purchase) {
            throw new NotFoundException(`Purchase bill with ID ${alloc.purchaseId} not found in this business.`);
          }
          if (purchase.supplierId !== dto.supplierId) {
            throw new BadRequestException(
              `Purchase bill ${purchase.billNumber} belongs to a different supplier than the payment recipient.`,
            );
          }
          if (purchase.status === 'CANCELLED') {
            throw new BadRequestException(`Cannot allocate payment to cancelled purchase bill ${purchase.billNumber}.`);
          }
          if (allocAmount.gt(purchase.balanceAmount)) {
            throw new BadRequestException(
              `Allocation of ₹${allocAmount.toFixed(2)} exceeds purchase bill ${purchase.billNumber} outstanding balance of ₹${purchase.balanceAmount.toFixed(2)}.`,
            );
          }

          totalAllocated = totalAllocated.plus(allocAmount);
          allocationData.push({ purchaseId: alloc.purchaseId, amount: allocAmount });
        }

        if (totalAllocated.gt(paymentAmount)) {
          throw new BadRequestException(
            `Total allocated amount (₹${totalAllocated.toFixed(2)}) cannot exceed total payment amount (₹${paymentAmount.toFixed(2)}).`,
          );
        }
      }

      // 3. Generate Sequence Number
      const paymentDate = dto.paymentDate ? new Date(dto.paymentDate) : new Date();
      const paymentNumber = await this.sequenceService.getNextNumber(
        businessId,
        'PAYMENT',
        'PAY',
        paymentDate,
        tx,
      );

      // 4. Create Payment Record
      const payment = await tx.payment.create({
        data: {
          businessId,
          paymentNumber,
          paymentType: PaymentType.SUPPLIER_PAYMENT,
          supplierId: dto.supplierId,
          paymentDate,
          amount: paymentAmount,
          paymentMethod: dto.paymentMethod,
          referenceNumber: dto.referenceNumber?.trim() || null,
          notes: dto.notes?.trim() || null,
          clientOperationId: dto.clientOperationId || null,
        },
      });

      // 5. Create Allocations & Update Purchase Bills
      for (const alloc of allocationData) {
        await tx.paymentAllocation.create({
          data: {
            businessId,
            paymentId: payment.id,
            purchaseId: alloc.purchaseId,
            amount: alloc.amount,
          },
        });

        const currentPur = await tx.purchase.findUnique({
          where: { businessId_id: { businessId, id: alloc.purchaseId } },
        });

        if (currentPur) {
          const newPaid = currentPur.paidAmount.plus(alloc.amount);
          const newBalance = currentPur.balanceAmount.minus(alloc.amount);
          const newPaymentStatus = newBalance.isZero() ? 'PAID' : 'PARTIALLY_PAID';

          await tx.purchase.update({
            where: { businessId_id: { businessId, id: alloc.purchaseId } },
            data: {
              paidAmount: newPaid,
              balanceAmount: newBalance,
              paymentStatus: newPaymentStatus,
            },
          });
        }
      }

      // 6. Update Supplier Outstanding Payable Balance
      await tx.supplier.update({
        where: { businessId_id: { businessId, id: dto.supplierId! } },
        data: {
          currentBalance: {
            decrement: paymentAmount,
          },
        },
      });

      // 7. Audit Log
      if (this.accountingService && !payment.amount.isZero()) {
        await this.accountingService.postDisbursementJournal(businessId, payment, tx);
      }

      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'CREATE_SUPPLIER_PAYMENT',
          entityName: 'Payment',
          entityId: payment.id,
          newValues: {
            paymentNumber,
            supplierId: dto.supplierId,
            amount: paymentAmount.toNumber(),
            paymentMethod: dto.paymentMethod,
            allocationsCount: allocationData.length,
          },
        },
      });

      return tx.payment.findUnique({
        where: { businessId_id: { businessId, id: payment.id } },
        include: {
          supplier: { select: { id: true, name: true, phone: true } },
          allocations: {
            include: {
              purchase: { select: { id: true, billNumber: true, totalAmount: true, balanceAmount: true } },
            },
          },
        },
      });
    });
  }

  /**
   * List payments with filtering, search, pagination, and tenant isolation.
   */
  async getPayments(businessId: string, query: QueryPaymentsDto) {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.PaymentWhereInput = { businessId };

    if (query.paymentType) {
      where.paymentType = query.paymentType;
    }
    if (query.customerId) {
      where.customerId = query.customerId;
    }
    if (query.supplierId) {
      where.supplierId = query.supplierId;
    }
    if (query.paymentMethod) {
      where.paymentMethod = query.paymentMethod;
    }
    if (query.startDate || query.endDate) {
      where.paymentDate = {};
      if (query.startDate) {
        where.paymentDate.gte = new Date(query.startDate);
      }
      if (query.endDate) {
        where.paymentDate.lte = new Date(query.endDate);
      }
    }
    if (query.search && query.search.trim().length > 0) {
      const s = query.search.trim();
      where.OR = [
        { paymentNumber: { contains: s, mode: 'insensitive' } },
        { referenceNumber: { contains: s, mode: 'insensitive' } },
        { notes: { contains: s, mode: 'insensitive' } },
        { customer: { name: { contains: s, mode: 'insensitive' } } },
        { supplier: { name: { contains: s, mode: 'insensitive' } } },
      ];
    }

    const [total, items] = await Promise.all([
      this.prisma.payment.count({ where }),
      this.prisma.payment.findMany({
        where,
        skip,
        take: limit,
        orderBy: { paymentDate: 'desc' },
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          supplier: { select: { id: true, name: true, phone: true } },
          allocations: {
            include: {
              invoice: { select: { id: true, invoiceNumber: true, totalAmount: true } },
              purchase: { select: { id: true, billNumber: true, totalAmount: true } },
            },
          },
        },
      }),
    ]);

    return {
      data: items,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get single payment by ID with full allocations and party details.
   */
  async getPaymentById(businessId: string, id: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { businessId_id: { businessId, id } },
      include: {
        customer: { select: { id: true, name: true, phone: true, email: true, currentBalance: true } },
        supplier: { select: { id: true, name: true, phone: true, email: true, currentBalance: true } },
        allocations: {
          include: {
            invoice: {
              select: {
                id: true,
                invoiceNumber: true,
                invoiceDate: true,
                totalAmount: true,
                receivedAmount: true,
                balanceAmount: true,
                status: true,
              },
            },
            purchase: {
              select: {
                id: true,
                billNumber: true,
                billDate: true,
                totalAmount: true,
                paidAmount: true,
                balanceAmount: true,
                paymentStatus: true,
              },
            },
          },
        },
      },
    });

    if (!payment) {
      throw new NotFoundException(`Payment with ID ${id} not found.`);
    }

    return payment;
  }

  /**
   * Void / Reverse a payment and all its allocations atomically.
   * Restores invoice/bill balances and party outstanding balance.
   */
  async voidPayment(businessId: string, paymentId: string, dto: VoidPaymentDto, userId?: string) {
    return this.prisma.$transaction(async (tx) => {
      const payment = await tx.payment.findUnique({
        where: { businessId_id: { businessId, id: paymentId } },
        include: {
          allocations: true,
        },
      });

      if (!payment) {
        throw new NotFoundException(`Payment with ID ${paymentId} not found.`);
      }

      // Reversal for Customer Receipt
      if (payment.paymentType === PaymentType.CUSTOMER_RECEIPT) {
        for (const alloc of payment.allocations) {
          if (alloc.invoiceId) {
            const inv = await tx.invoice.findUnique({
              where: { businessId_id: { businessId, id: alloc.invoiceId } },
            });
            if (inv && inv.status !== 'CANCELLED') {
              const newReceived = inv.receivedAmount.minus(alloc.amount);
              const newBalance = inv.balanceAmount.plus(alloc.amount);
              const newStatus = newBalance.gte(inv.totalAmount) ? 'ISSUED' : 'PARTIALLY_PAID';

              await tx.invoice.update({
                where: { businessId_id: { businessId, id: alloc.invoiceId } },
                data: {
                  receivedAmount: Prisma.Decimal.max(0, newReceived),
                  balanceAmount: newBalance,
                  status: newStatus,
                },
              });
            }
          }
        }

        if (payment.customerId) {
          await tx.customer.update({
            where: { businessId_id: { businessId, id: payment.customerId } },
            data: {
              currentBalance: {
                increment: payment.amount,
              },
            },
          });
        }
      }

      // Reversal for Supplier Payment
      if (payment.paymentType === PaymentType.SUPPLIER_PAYMENT) {
        for (const alloc of payment.allocations) {
          if (alloc.purchaseId) {
            const pur = await tx.purchase.findUnique({
              where: { businessId_id: { businessId, id: alloc.purchaseId } },
            });
            if (pur && pur.status !== 'CANCELLED') {
              const newPaid = pur.paidAmount.minus(alloc.amount);
              const newBalance = pur.balanceAmount.plus(alloc.amount);
              const newPaymentStatus = newBalance.gte(pur.totalAmount) ? 'UNPAID' : 'PARTIALLY_PAID';

              await tx.purchase.update({
                where: { businessId_id: { businessId, id: alloc.purchaseId } },
                data: {
                  paidAmount: Prisma.Decimal.max(0, newPaid),
                  balanceAmount: newBalance,
                  paymentStatus: newPaymentStatus,
                },
              });
            }
          }
        }

        if (payment.supplierId) {
          await tx.supplier.update({
            where: { businessId_id: { businessId, id: payment.supplierId } },
            data: {
              currentBalance: {
                increment: payment.amount,
              },
            },
          });
        }
      }

      // Delete allocations and payment record
      await tx.paymentAllocation.deleteMany({
        where: { businessId, paymentId: payment.id },
      });

      await tx.payment.delete({
        where: { businessId_id: { businessId, id: payment.id } },
      });

      // Audit Log for the reversal
      if (this.accountingService && !payment.amount.isZero()) {
        await this.accountingService.postPaymentVoidedJournal(businessId, payment, tx);
      }

      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'VOID_PAYMENT',
          entityName: 'Payment',
          entityId: payment.id,
          oldValues: {
            paymentNumber: payment.paymentNumber,
            paymentType: payment.paymentType,
            amount: payment.amount.toNumber(),
            customerId: payment.customerId,
            supplierId: payment.supplierId,
            reason: dto.reason,
          },
        },
      });

      return {
        success: true,
        message: `Payment ${payment.paymentNumber} voided and balances reversed successfully.`,
      };
    });
  }

  /**
   * Get outstanding invoices for a customer (for receipt allocation UI).
   */
  async getCustomerOutstanding(businessId: string, customerId: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { businessId_id: { businessId, id: customerId } },
      select: { id: true, name: true, phone: true, currentBalance: true },
    });
    if (!customer) {
      throw new NotFoundException(`Customer with ID ${customerId} not found.`);
    }

    const invoices = await this.prisma.invoice.findMany({
      where: {
        businessId,
        customerId,
        status: { in: ['ISSUED', 'PARTIALLY_PAID'] },
        balanceAmount: { gt: 0 },
      },
      orderBy: { invoiceDate: 'asc' },
      select: {
        id: true,
        invoiceNumber: true,
        invoiceDate: true,
        totalAmount: true,
        receivedAmount: true,
        balanceAmount: true,
        status: true,
      },
    });

    return {
      customer,
      outstandingInvoices: invoices,
    };
  }

  /**
   * Get outstanding purchase bills for a supplier (for payment allocation UI).
   */
  async getSupplierOutstanding(businessId: string, supplierId: string) {
    const supplier = await this.prisma.supplier.findUnique({
      where: { businessId_id: { businessId, id: supplierId } },
      select: { id: true, name: true, phone: true, currentBalance: true },
    });
    if (!supplier) {
      throw new NotFoundException(`Supplier with ID ${supplierId} not found.`);
    }

    const purchases = await this.prisma.purchase.findMany({
      where: {
        businessId,
        supplierId,
        status: 'RECEIVED',
        paymentStatus: { in: ['UNPAID', 'PARTIALLY_PAID'] },
        balanceAmount: { gt: 0 },
      },
      orderBy: { billDate: 'asc' },
      select: {
        id: true,
        billNumber: true,
        billDate: true,
        totalAmount: true,
        paidAmount: true,
        balanceAmount: true,
        paymentStatus: true,
      },
    });

    return {
      supplier,
      outstandingBills: purchases,
    };
  }
}

