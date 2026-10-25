import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { CreatePurchaseDto } from './dto/create-purchase.dto';
import { QueryPurchasesDto } from './dto/query-purchases.dto';
import { CancelPurchaseDto } from './dto/cancel-purchase.dto';
import { PaymentStatus, Prisma, PurchaseStatus, StockMovementType } from '@prisma/client';

@Injectable()
export class PurchasesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Find paginated and filtered purchase bills for the tenant.
   */
  async findAll(businessId: string, query: QueryPurchasesDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 50));
    const skip = (page - 1) * limit;

    const where: Prisma.PurchaseWhereInput = {
      businessId,
    };

    if (query.status && query.status !== 'ALL') {
      where.status = query.status as PurchaseStatus;
    }

    if (query.supplierId) {
      where.supplierId = query.supplierId;
    }

    if (query.startDate || query.endDate) {
      where.billDate = {};
      if (query.startDate) {
        where.billDate.gte = new Date(query.startDate);
      }
      if (query.endDate) {
        where.billDate.lte = new Date(query.endDate);
      }
    }

    if (query.search && query.search.trim()) {
      const term = query.search.trim();
      where.OR = [
        { billNumber: { contains: term, mode: 'insensitive' } },
        { supplier: { name: { contains: term, mode: 'insensitive' } } },
        { supplier: { gstin: { contains: term, mode: 'insensitive' } } },
      ];
    }

    const [purchases, total] = await Promise.all([
      this.prisma.purchase.findMany({
        where,
        skip,
        take: limit,
        orderBy: [{ billDate: 'desc' }, { createdAt: 'desc' }],
        include: {
          supplier: {
            select: {
              id: true,
              name: true,
              phone: true,
              gstin: true,
              city: true,
              currentBalance: true,
            },
          },
          items: true,
        },
      }),
      this.prisma.purchase.count({ where }),
    ]);

    return {
      success: true,
      statusCode: 200,
      data: purchases,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  }

  /**
   * Retrieve purchase details with supplier, branch, and items.
   */
  async findOne(businessId: string, id: string) {
    const purchase = await this.prisma.purchase.findUnique({
      where: { businessId_id: { businessId, id } },
      include: {
        supplier: true,
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

    if (!purchase) {
      throw new NotFoundException(`Purchase bill with ID ${id} not found.`);
    }

    return {
      success: true,
      statusCode: 200,
      data: purchase,
    };
  }

  /**
   * Create purchase bill atomically.
   * If status is RECEIVED, immediately creates stock movements, updates stock on hand,
   * updates supplier payable balance, records GST entry, and writes audit event.
   */
  async create(businessId: string, dto: CreatePurchaseDto, userId?: string) {
    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException('Purchase bill must contain at least one line item.');
    }

    // 1. Idempotency Check
    if (dto.clientOperationId) {
      const existing = await this.prisma.purchase.findFirst({
        where: { businessId, clientOperationId: dto.clientOperationId },
        include: { supplier: true, items: true },
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

    return await this.prisma.$transaction(async (tx) => {
      // 2. Validate Supplier
      const supplier = await tx.supplier.findUnique({
        where: { businessId_id: { businessId, id: dto.supplierId } },
      });
      if (!supplier) {
        throw new BadRequestException(`Supplier with ID ${dto.supplierId} not found.`);
      }

      // Check unique bill number per supplier
      const duplicateBill = await tx.purchase.findUnique({
        where: {
          businessId_supplierId_billNumber: {
            businessId,
            supplierId: dto.supplierId,
            billNumber: dto.billNumber.trim(),
          },
        },
      });
      if (duplicateBill) {
        throw new ConflictException(
          `Purchase bill "${dto.billNumber}" already exists for supplier "${supplier.name}".`,
        );
      }

      // 3. Resolve Branch & Warehouse
      let branchId = dto.branchId;
      if (branchId) {
        const branchExists = await tx.branch.findUnique({
          where: { businessId_id: { businessId, id: branchId } },
        });
        if (!branchExists) {
          throw new BadRequestException(`Branch ${branchId} does not belong to your business.`);
        }
      } else {
        let branch = await tx.branch.findFirst({
          where: { businessId, isMain: true },
        }) || (await tx.branch.findFirst({ where: { businessId } }));

        if (!branch) {
          branch = await tx.branch.create({
            data: { businessId, name: 'Main Branch', isMain: true },
          });
        }
        branchId = branch.id;
      }

      let warehouse = await tx.warehouse.findFirst({
        where: { businessId, branchId },
      }) || (await tx.warehouse.findFirst({ where: { businessId } }));

      if (!warehouse) {
        warehouse = await tx.warehouse.create({
          data: { businessId, branchId, name: 'Main Warehouse', isDefault: true },
        });
      }

      // 4. Validate Products
      const productIds = dto.items.map((it) => it.productId);
      const products = await tx.product.findMany({
        where: { businessId, id: { in: productIds } },
      });

      if (products.length !== productIds.length) {
        throw new BadRequestException('One or more products do not belong to your business.');
      }
      const productMap = new Map(products.map((p) => [p.id, p]));

      // 5. Authoritative Decimal Calculations
      let subtotal = new Prisma.Decimal(0);
      let totalTax = new Prisma.Decimal(0);

      const calculatedItems = dto.items.map((it) => {
        const qty = new Prisma.Decimal(it.quantity).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
        const cost = new Prisma.Decimal(it.unitCost).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
        const gross = qty.mul(cost).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
        const rate = new Prisma.Decimal(it.taxRate || 0).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
        const tax = gross.mul(rate).div(100).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
        const lineTotal = gross.plus(tax).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);

        subtotal = subtotal.plus(gross);
        totalTax = totalTax.plus(tax);

        return {
          businessId,
          productId: it.productId,
          description: it.description,
          hsnCode: it.hsnCode || null,
          quantity: qty,
          unitCost: cost,
          taxRate: rate,
          taxAmount: tax,
          totalAmount: lineTotal,
        };
      });

      const totalAmount = subtotal.plus(totalTax).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
      const billDate = dto.billDate ? new Date(dto.billDate) : new Date();
      const status = dto.status || PurchaseStatus.RECEIVED;

      // 6. Create Purchase Record
      const purchase = await tx.purchase.create({
        data: {
          businessId,
          branchId,
          supplierId: dto.supplierId,
          billNumber: dto.billNumber.trim(),
          billDate,
          status,
          subtotal,
          taxAmount: totalTax,
          totalAmount,
          paidAmount: new Prisma.Decimal(0),
          balanceAmount: totalAmount,
          paymentStatus: PaymentStatus.UNPAID,
          notes: dto.notes || null,
          clientOperationId: dto.clientOperationId || null,
          items: {
            create: calculatedItems,
          },
        },
        include: {
          supplier: true,
          items: true,
        },
      });

      // 7. If status is RECEIVED, execute inventory & financial effects
      if (status === PurchaseStatus.RECEIVED) {
        await this._applyReceiveEffects(tx, businessId, purchase, calculatedItems, warehouse.id, supplier, userId);
      }

      return {
        success: true,
        statusCode: 201,
        data: purchase,
      };
    });
  }

  /**
   * Receive/Confirm an ORDERED purchase bill.
   */
  async receive(businessId: string, id: string, userId?: string) {
    const existing = await this.prisma.purchase.findUnique({
      where: { businessId_id: { businessId, id } },
      include: { supplier: true, items: true },
    });

    if (!existing) {
      throw new NotFoundException(`Purchase with ID ${id} not found.`);
    }

    if (existing.status === PurchaseStatus.RECEIVED) {
      throw new BadRequestException('Purchase is already received.');
    }

    if (existing.status === PurchaseStatus.CANCELLED) {
      throw new BadRequestException('Cannot receive a cancelled purchase.');
    }

    return await this.prisma.$transaction(async (tx) => {
      const warehouse = await tx.warehouse.findFirst({
        where: { businessId, branchId: existing.branchId },
      }) || (await tx.warehouse.findFirst({ where: { businessId } }));

      if (!warehouse) {
        throw new NotFoundException('Warehouse not configured for this branch.');
      }

      const updatedPurchase = await tx.purchase.update({
        where: { businessId_id: { businessId, id } },
        data: { status: PurchaseStatus.RECEIVED },
        include: { supplier: true, items: true },
      });

      await this._applyReceiveEffects(
        tx,
        businessId,
        updatedPurchase,
        existing.items,
        warehouse.id,
        existing.supplier,
        userId,
      );

      return {
        success: true,
        statusCode: 200,
        data: updatedPurchase,
      };
    });
  }

  /**
   * Cancel an existing purchase bill with full inventory and payable reversal.
   */
  async cancel(businessId: string, id: string, dto: CancelPurchaseDto, userId?: string) {
    const existing = await this.prisma.purchase.findUnique({
      where: { businessId_id: { businessId, id } },
      include: { supplier: true, items: true },
    });

    if (!existing) {
      throw new NotFoundException(`Purchase bill with ID ${id} not found.`);
    }

    if (existing.status === PurchaseStatus.CANCELLED) {
      throw new BadRequestException('Purchase is already cancelled.');
    }

    return await this.prisma.$transaction(async (tx) => {
      // 1. Mark status as CANCELLED
      const cancelled = await tx.purchase.update({
        where: { businessId_id: { businessId, id } },
        data: {
          status: PurchaseStatus.CANCELLED,
          notes: (existing.notes ? `${existing.notes} | ` : '') + `Cancelled: ${dto.reason}`,
        },
        include: { supplier: true, items: true },
      });

      // 2. If it was RECEIVED, reverse effects
      if (existing.status === PurchaseStatus.RECEIVED) {
        // Reverse supplier balance
        await tx.supplier.update({
          where: { businessId_id: { businessId, id: existing.supplierId } },
          data: {
            currentBalance: {
              decrement: existing.balanceAmount,
            },
          },
        });

        // Reverse stock movements
        const warehouse = await tx.warehouse.findFirst({
          where: { businessId, branchId: existing.branchId },
        }) || (await tx.warehouse.findFirst({ where: { businessId } }));

        if (warehouse) {
          for (const item of existing.items) {
            await tx.stockMovement.create({
              data: {
                businessId,
                warehouseId: warehouse.id,
                productId: item.productId,
                movementType: StockMovementType.PURCHASE_RETURN,
                quantity: item.quantity,
                unitCost: item.unitCost,
                referenceType: 'PURCHASE_CANCEL',
                referenceId: existing.id,
                notes: `Reversed on purchase bill cancellation: ${dto.reason}`,
              },
            });

            // Update Stock table on hand
            await tx.stock.upsert({
              where: {
                businessId_id: { businessId, id: `${warehouse.id}_${item.productId}` },
              },
              update: {
                quantityOnHand: { decrement: item.quantity },
              },
              create: {
                id: `${warehouse.id}_${item.productId}`,
                businessId,
                warehouseId: warehouse.id,
                productId: item.productId,
                quantityOnHand: new Prisma.Decimal(0).minus(item.quantity),
              },
            });
          }
        }

        // Cancel GST records
        await tx.gstRecord.updateMany({
          where: { businessId, purchaseId: existing.id },
          data: { isCancelled: true },
        });
      }

      // 3. Write Audit Log
      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'PURCHASE_CANCELLED',
          entityName: 'Purchase',
          entityId: existing.id,
          oldValues: { status: existing.status },
          newValues: { status: PurchaseStatus.CANCELLED, reason: dto.reason },
        },
      });

      return {
        success: true,
        statusCode: 200,
        data: cancelled,
      };
    });
  }

  private async _applyReceiveEffects(
    tx: Prisma.TransactionClient,
    businessId: string,
    purchase: any,
    items: any[],
    warehouseId: string,
    supplier: any,
    userId?: string,
  ) {
    // 1. Create StockMovements & Update StockOnHand
    for (const item of items) {
      await tx.stockMovement.create({
        data: {
          businessId,
          warehouseId,
          productId: item.productId,
          movementType: StockMovementType.PURCHASE,
          quantity: item.quantity,
          unitCost: item.unitCost,
          referenceType: 'PURCHASE',
          referenceId: purchase.id,
          notes: `Received via purchase bill ${purchase.billNumber}`,
        },
      });

      await tx.stock.upsert({
        where: {
          businessId_id: { businessId, id: `${warehouseId}_${item.productId}` },
        },
        update: {
          quantityOnHand: { increment: item.quantity },
        },
        create: {
          id: `${warehouseId}_${item.productId}`,
          businessId,
          warehouseId,
          productId: item.productId,
          quantityOnHand: item.quantity,
        },
      });
    }

    // 2. Increment Supplier Payable Balance
    await tx.supplier.update({
      where: { businessId_id: { businessId, id: purchase.supplierId } },
      data: {
        currentBalance: {
          increment: purchase.balanceAmount,
        },
      },
    });

    // 3. Record GST Input Tax Credit record if applicable
    if (!purchase.taxAmount.isZero()) {
      const billDate = purchase.billDate || new Date();
      const returnPeriod = `${billDate.getFullYear()}-${String(billDate.getMonth() + 1).padStart(2, '0')}`;
      await tx.gstRecord.create({
        data: {
          businessId,
          returnPeriod,
          transactionType: 'PURCHASE',
          purchaseId: purchase.id,
          gstin: supplier?.gstin || null,
          placeOfSupply: supplier?.state || '27',
          taxableValue: purchase.subtotal,
          cgstAmount: purchase.taxAmount.div(2),
          sgstAmount: purchase.taxAmount.div(2),
          igstAmount: new Prisma.Decimal(0),
        },
      });
    }

    // 4. Audit Log
    await tx.auditLog.create({
      data: {
        businessId,
        userId: userId || null,
        action: 'PURCHASE_RECEIVED',
        entityName: 'Purchase',
        entityId: purchase.id,
        newValues: {
          billNumber: purchase.billNumber,
          totalAmount: purchase.totalAmount ? purchase.totalAmount.toString() : '0',
          supplierId: purchase.supplierId,
        },
      },
    });
  }
}
