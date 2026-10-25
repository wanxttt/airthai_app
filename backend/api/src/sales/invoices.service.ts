import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { SequenceService } from './sequence.service';
import { TaxCalculatorUtil } from './utils/tax-calculator.util';
import { CreateInvoiceDto } from './dto/create-invoice.dto';
import { QueryInvoicesDto } from './dto/query-invoices.dto';
import { CancelInvoiceDto } from './dto/cancel-invoice.dto';
import { InvoiceStatus, Prisma, StockMovementType } from '@prisma/client';

@Injectable()
export class InvoicesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
  ) {}

  /**
   * Find paginated and filtered invoices for the tenant.
   */
  async findAll(businessId: string, query: QueryInvoicesDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 50));
    const skip = (page - 1) * limit;

    const where: Prisma.InvoiceWhereInput = {
      businessId,
    };

    if (query.status && query.status !== 'ALL') {
      where.status = query.status as InvoiceStatus;
    }

    if (query.customerId) {
      where.customerId = query.customerId;
    }

    if (query.startDate || query.endDate) {
      where.invoiceDate = {};
      if (query.startDate) {
        where.invoiceDate.gte = new Date(query.startDate);
      }
      if (query.endDate) {
        where.invoiceDate.lte = new Date(query.endDate);
      }
    }

    if (query.search && query.search.trim()) {
      const term = query.search.trim();
      where.OR = [
        { invoiceNumber: { contains: term, mode: 'insensitive' } },
        { customer: { name: { contains: term, mode: 'insensitive' } } },
        { customer: { phone: { contains: term, mode: 'insensitive' } } },
      ];
    }

    const [invoices, total] = await Promise.all([
      this.prisma.invoice.findMany({
        where,
        skip,
        take: limit,
        orderBy: [{ invoiceDate: 'desc' }, { createdAt: 'desc' }],
        include: {
          customer: {
            select: {
              id: true,
              name: true,
              phone: true,
              gstin: true,
              city: true,
              state: true,
            },
          },
          items: true,
        },
      }),
      this.prisma.invoice.count({ where }),
    ]);

    return {
      success: true,
      statusCode: 200,
      data: invoices,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  }

  /**
   * Find a single invoice by ID with items, customer and branch.
   */
  async findOne(businessId: string, id: string) {
    const invoice = await this.prisma.invoice.findUnique({
      where: {
        businessId_id: { businessId, id },
      },
      include: {
        customer: true,
        branch: true,
        items: {
          include: {
            product: {
              select: {
                id: true,
                name: true,
                sku: true,
                unit: { select: { symbol: true } },
              },
            },
          },
        },
        gstRecords: true,
      },
    });

    if (!invoice) {
      throw new NotFoundException(`Invoice with ID ${id} not found.`);
    }

    return {
      success: true,
      statusCode: 200,
      data: invoice,
    };
  }

  /**
   * Atomic invoice creation with exact server-side calculations,
   * concurrency-safe sequence generation, stock reductions, customer balance updates,
   * GST record tracking, and audit logging.
   */
  async create(businessId: string, dto: CreateInvoiceDto, userId?: string) {
    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException('Invoice must contain at least one line item.');
    }

    // 1. Idempotency Check: if clientOperationId is present, check existing invoice
    if (dto.clientOperationId) {
      const existing = await this.prisma.invoice.findFirst({
        where: {
          businessId,
          clientOperationId: dto.clientOperationId,
        },
        include: {
          customer: true,
          items: true,
        },
      });

      if (existing) {
        return {
          success: true,
          statusCode: 200,
          data: existing,
          idempotentReplay: true,
        };
      }
    }

    // Run the entire creation process in a single atomic database transaction
    return await this.prisma.$transaction(async (tx) => {
      // 2. Validate Tenant & Business Settings
      const business = await tx.business.findUnique({
        where: { id: businessId },
        include: { settings: true },
      });

      if (!business) {
        throw new NotFoundException('Business tenant not found.');
      }

      // 3. Validate Branch & Warehouse
      let branchId = dto.branchId;
      if (branchId) {
        const branchExists = await tx.branch.findUnique({
          where: { businessId_id: { businessId, id: branchId } },
        });
        if (!branchExists) {
          throw new BadRequestException(`Branch ${branchId} does not belong to your business.`);
        }
      } else {
        let defaultBranch = await tx.branch.findFirst({
          where: { businessId, isMain: true },
        });
        if (!defaultBranch) {
          defaultBranch = await tx.branch.findFirst({ where: { businessId } });
        }
        if (!defaultBranch) {
          defaultBranch = await tx.branch.create({
            data: {
              businessId,
              name: 'Main Branch',
              isMain: true,
            },
          });
        }
        branchId = defaultBranch.id;
      }

      // Resolve default warehouse for inventory stock movements
      let warehouse = await tx.warehouse.findFirst({
        where: { businessId, branchId },
      });
      if (!warehouse) {
        warehouse = await tx.warehouse.findFirst({ where: { businessId } });
      }
      if (!warehouse) {
        warehouse = await tx.warehouse.create({
          data: {
            businessId,
            branchId,
            name: 'Main Warehouse',
            isDefault: true,
          },
        });
      }

      // 4. Validate Customer (if provided)
      let customer: any = null;
      if (dto.customerId) {
        customer = await tx.customer.findUnique({
          where: { businessId_id: { businessId, id: dto.customerId } },
        });
        if (!customer) {
          throw new BadRequestException(`Customer with ID ${dto.customerId} not found.`);
        }
        if (customer.status === 'ARCHIVED') {
          throw new BadRequestException('Cannot issue invoice to an archived customer.');
        }
      }

      // 5. Validate Products & Check Inventory Constraints
      const productIds = dto.items
        .map((item) => item.productId)
        .filter((id): id is string => Boolean(id));

      const products = productIds.length > 0
        ? await tx.product.findMany({
            where: {
              businessId,
              id: { in: productIds },
            },
            include: {
              stockMovements: {
                select: { movementType: true, quantity: true },
              },
            },
          })
        : [];

      const productMap = new Map<string, (typeof products)[0]>();
      for (const p of products) {
        productMap.set(p.id, p);
      }

      // Check for foreign product cross-tenant injection
      for (const item of dto.items) {
        if (item.productId && !productMap.has(item.productId)) {
          throw new BadRequestException(
            `Product with ID ${item.productId} was not found or belongs to another business.`,
          );
        }
      }

      // Check stock availability if negative stock is disallowed
      const allowNegativeStock = business.settings?.allowNegativeStock ?? false;
      if (!allowNegativeStock) {
        for (const item of dto.items) {
          if (item.productId) {
            const product = productMap.get(item.productId);
            if (product && product.trackStock) {
              // Calculate available current stock
              const currentStock = product.stockMovements.reduce((acc, mov) => {
                const qty = Number(mov.quantity);
                if (['PURCHASE', 'SALE_RETURN', 'ADJUSTMENT_ADD'].includes(mov.movementType)) {
                  return acc + qty;
                } else {
                  return acc - qty;
                }
              }, 0);

              if (currentStock < item.quantity) {
                throw new BadRequestException(
                  `Insufficient stock for product "${product.name}". Available stock: ${currentStock}, Requested: ${item.quantity}.`,
                );
              }
            }
          }
        }
      }

      // 6. Authoritative Tax & Grand Total Calculations
      const isGstEnabled = business.settings?.enableGst ?? true;
      const businessStateCode = business.stateCode || (business.gstin ? business.gstin.substring(0, 2) : null);
      const placeOfSupply = dto.placeOfSupply || customer?.state || businessStateCode || '27';

      const totals = TaxCalculatorUtil.calculateInvoice({
        items: dto.items,
        businessStateCode,
        placeOfSupply,
        enableGst: isGstEnabled,
        invoiceDiscountAmount: dto.discountAmount,
        isReverseCharge: dto.isReverseCharge,
      });

      // 7. Concurrency-Safe Invoice Number Generation
      const invoiceDate = dto.invoiceDate ? new Date(dto.invoiceDate) : new Date();
      const invoiceNumber = await this.sequenceService.getNextNumber(
        businessId,
        'INVOICE',
        'INV',
        invoiceDate,
        tx,
      );

      // 8. Create Invoice Header
      const invoice = await tx.invoice.create({
        data: {
          businessId,
          branchId,
          customerId: dto.customerId || null,
          invoiceNumber,
          invoiceDate,
          dueDate: dto.dueDate ? new Date(dto.dueDate) : null,
          status: InvoiceStatus.ISSUED,
          placeOfSupply: totals.placeOfSupply,
          isInterState: totals.isInterState,
          isReverseCharge: dto.isReverseCharge ?? false,
          subtotal: totals.subtotal,
          discountAmount: totals.discountAmount,
          taxableAmount: totals.taxableAmount,
          cgstAmount: totals.cgstAmount,
          sgstAmount: totals.sgstAmount,
          igstAmount: totals.igstAmount,
          cessAmount: totals.cessAmount,
          roundOff: totals.roundOff,
          totalAmount: totals.totalAmount,
          receivedAmount: new Prisma.Decimal(0),
          balanceAmount: totals.totalAmount,
          notes: dto.notes || null,
          terms: dto.terms || null,
          clientOperationId: dto.clientOperationId || null,
          items: {
            create: totals.items.map((it) => ({
              businessId,
              productId: it.productId || null,
              variantId: it.variantId || null,
              description: it.description,
              hsnCode: it.hsnCode || null,
              quantity: it.quantity,
              unitPrice: it.unitPrice,
              discountAmount: it.discountAmount,
              taxableAmount: it.taxableAmount,
              gstRate: it.gstRate,
              cgstAmount: it.cgstAmount,
              sgstAmount: it.sgstAmount,
              igstAmount: it.igstAmount,
              cessAmount: it.cessAmount,
              totalAmount: it.totalAmount,
            })),
          },
        },
        include: {
          items: true,
          customer: true,
        },
      });

      // 9. Process Inventory Effects (Stock Movements)
      for (const item of totals.items) {
        if (item.productId) {
          const product = productMap.get(item.productId);
          if (product && product.trackStock) {
            await tx.stockMovement.create({
              data: {
                businessId,
                warehouseId: warehouse.id,
                productId: item.productId,
                movementType: StockMovementType.SALE,
                quantity: item.quantity,
                unitCost: product.purchasePrice || new Prisma.Decimal(0),
                referenceType: 'INVOICE',
                referenceId: invoice.id,
                notes: `Sold via invoice ${invoice.invoiceNumber}`,
              },
            });
          }
        }
      }

      // 10. Update Customer Outstanding Balance
      if (dto.customerId) {
        await tx.customer.update({
          where: { businessId_id: { businessId, id: dto.customerId } },
          data: {
            currentBalance: {
              increment: invoice.balanceAmount,
            },
          },
        });
      }

      // 11. Record GST Entry for Reporting
      if (isGstEnabled && !totals.totalAmount.isZero()) {
        const fiscalPeriod = `${invoiceDate.getFullYear()}-${String(invoiceDate.getMonth() + 1).padStart(2, '0')}`;
        await tx.gstRecord.create({
          data: {
            businessId,
            returnPeriod: fiscalPeriod,
            transactionType: customer?.gstin ? 'B2B' : 'B2C',
            invoiceId: invoice.id,
            gstin: customer?.gstin || null,
            placeOfSupply: totals.placeOfSupply,
            taxableValue: totals.taxableAmount,
            cgstAmount: totals.cgstAmount,
            sgstAmount: totals.sgstAmount,
            igstAmount: totals.igstAmount,
            cessAmount: totals.cessAmount,
          },
        });
      }

      // 12. Write Audit Log Event
      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'INVOICE_CREATED',
          entityName: 'Invoice',
          entityId: invoice.id,
          newValues: {
            invoiceNumber: invoice.invoiceNumber,
            totalAmount: invoice.totalAmount.toString(),
            customerId: invoice.customerId,
            itemCount: totals.items.length,
          },
        },
      });

      return {
        success: true,
        statusCode: 201,
        data: invoice,
      };
    });
  }

  /**
   * Cancel an issued invoice with full financial and inventory reversal.
   * Never silently deletes an issued financial document.
   */
  async cancel(businessId: string, id: string, dto: CancelInvoiceDto, userId?: string) {
    const existing = await this.prisma.invoice.findUnique({
      where: { businessId_id: { businessId, id } },
      include: {
        items: true,
        customer: true,
      },
    });

    if (!existing) {
      throw new NotFoundException(`Invoice with ID ${id} not found.`);
    }

    if (existing.status === InvoiceStatus.CANCELLED) {
      throw new BadRequestException('Invoice is already cancelled.');
    }

    return await this.prisma.$transaction(async (tx) => {
      // 1. Mark invoice as CANCELLED
      const cancelledInvoice = await tx.invoice.update({
        where: { businessId_id: { businessId, id } },
        data: {
          status: InvoiceStatus.CANCELLED,
          cancelledAt: new Date(),
          cancellationReason: dto.reason,
        },
        include: {
          items: true,
          customer: true,
        },
      });

      // 2. Reverse customer receivable balance
      if (existing.customerId) {
        await tx.customer.update({
          where: { businessId_id: { businessId, id: existing.customerId } },
          data: {
            currentBalance: {
              decrement: existing.balanceAmount,
            },
          },
        });
      }

      // 3. Reverse inventory stock movements
      const productIds = existing.items
        .map((it) => it.productId)
        .filter((pid): pid is string => Boolean(pid));

      if (productIds.length > 0) {
        const products = await tx.product.findMany({
          where: { businessId, id: { in: productIds } },
        });

        const productMap = new Map(products.map((p) => [p.id, p]));
        const warehouse = await tx.warehouse.findFirst({
          where: { businessId, branchId: existing.branchId },
        }) || (await tx.warehouse.findFirst({ where: { businessId } }));

        if (warehouse) {
          for (const item of existing.items) {
            if (item.productId) {
              const product = productMap.get(item.productId);
              if (product && product.trackStock) {
                await tx.stockMovement.create({
                  data: {
                    businessId,
                    warehouseId: warehouse.id,
                    productId: item.productId,
                    movementType: StockMovementType.SALE_RETURN,
                    quantity: item.quantity,
                    unitCost: product.purchasePrice || new Prisma.Decimal(0),
                    referenceType: 'INVOICE_CANCEL',
                    referenceId: existing.id,
                    notes: `Stock returned on cancellation: ${dto.reason}`,
                  },
                });
              }
            }
          }
        }
      }

      // 4. Mark associated GST Records as cancelled
      await tx.gstRecord.updateMany({
        where: { businessId, invoiceId: existing.id },
        data: { isCancelled: true },
      });

      // 5. Create Audit Log
      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'INVOICE_CANCELLED',
          entityName: 'Invoice',
          entityId: existing.id,
          oldValues: { status: existing.status },
          newValues: {
            status: InvoiceStatus.CANCELLED,
            reason: dto.reason,
            cancelledAt: new Date().toISOString(),
          },
        },
      });

      return {
        success: true,
        statusCode: 200,
        data: cancelledInvoice,
      };
    });
  }
}
