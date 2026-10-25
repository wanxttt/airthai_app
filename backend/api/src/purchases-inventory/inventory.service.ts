import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { CreateStockAdjustmentDto } from './dto/stock-adjustment.dto';
import { QueryInventoryDto } from './dto/query-inventory.dto';
import { Prisma, StockMovementType } from '@prisma/client';

export interface ProductInventoryView {
  id: string;
  name: string;
  sku: string | null;
  barcode: string | null;
  categoryName: string | null;
  unitSymbol: string | null;
  trackStock: boolean;
  minStockLevel: number;
  currentStock: number;
  stockStatus: 'IN_STOCK' | 'LOW_STOCK' | 'OUT_OF_STOCK';
  unitCost: number;
  valuation: number;
}

@Injectable()
export class InventoryService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * High-level inventory valuation and status metrics using Weighted Average Cost (WAC).
   */
  async getSummary(businessId: string) {
    const products = await this.prisma.product.findMany({
      where: { businessId, status: 'ACTIVE' },
      select: {
        id: true,
        minStockLevel: true,
        purchasePrice: true,
        trackStock: true,
        stockMovements: {
          select: {
            movementType: true,
            quantity: true,
            unitCost: true,
          },
        },
      },
    });

    let totalProducts = products.length;
    let totalStockQty = 0;
    let lowStockCount = 0;
    let outOfStockCount = 0;
    let totalValuation = new Prisma.Decimal(0);

    for (const p of products) {
      if (!p.trackStock) continue;

      let currentStock = 0;
      let totalPurchaseCost = new Prisma.Decimal(0);
      let totalPurchaseQty = new Prisma.Decimal(0);

      for (const m of p.stockMovements) {
        const qty = Number(m.quantity);
        if (['PURCHASE', 'SALE_RETURN', 'ADJUSTMENT_ADD'].includes(m.movementType)) {
          currentStock += qty;
        } else {
          currentStock -= qty;
        }

        // Track Weighted Average Cost inputs from purchases
        if (m.movementType === StockMovementType.PURCHASE) {
          totalPurchaseCost = totalPurchaseCost.plus(m.quantity.mul(m.unitCost));
          totalPurchaseQty = totalPurchaseQty.plus(m.quantity);
        }
      }

      totalStockQty += currentStock;

      const minLevel = Number(p.minStockLevel || 0);
      if (currentStock <= 0) {
        outOfStockCount++;
      } else if (currentStock <= minLevel) {
        lowStockCount++;
      }

      // Compute WAC per unit
      let unitCost = p.purchasePrice || new Prisma.Decimal(0);
      if (!totalPurchaseQty.isZero()) {
        unitCost = totalPurchaseCost.div(totalPurchaseQty);
      }

      if (currentStock > 0) {
        const itemValuation = unitCost.mul(currentStock);
        totalValuation = totalValuation.plus(itemValuation);
      }
    }

    return {
      success: true,
      statusCode: 200,
      data: {
        totalProducts,
        totalStockQuantity: totalStockQty,
        lowStockCount,
        outOfStockCount,
        totalValuation: Number(totalValuation.toFixed(2)),
        valuationMethod: 'WEIGHTED_AVERAGE_COST',
      },
    };
  }

  /**
   * Paginated list of products with current stock levels, low-stock flags, and valuations.
   */
  async getProducts(businessId: string, query: QueryInventoryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 50));

    const where: Prisma.ProductWhereInput = {
      businessId,
      status: 'ACTIVE',
    };

    if (query.categoryId) {
      where.categoryId = query.categoryId;
    }

    if (query.search && query.search.trim()) {
      const term = query.search.trim();
      where.OR = [
        { name: { contains: term, mode: 'insensitive' } },
        { sku: { contains: term, mode: 'insensitive' } },
        { barcode: { contains: term, mode: 'insensitive' } },
      ];
    }

    const products = await this.prisma.product.findMany({
      where,
      orderBy: { name: 'asc' },
      include: {
        category: { select: { name: true } },
        unit: { select: { symbol: true } },
        stockMovements: {
          select: {
            movementType: true,
            quantity: true,
            unitCost: true,
          },
        },
      },
    });

    const calculatedViews: ProductInventoryView[] = [];

    for (const p of products) {
      let currentStock = 0;
      let totalPurchaseCost = new Prisma.Decimal(0);
      let totalPurchaseQty = new Prisma.Decimal(0);

      for (const m of p.stockMovements) {
        const qty = Number(m.quantity);
        if (['PURCHASE', 'SALE_RETURN', 'ADJUSTMENT_ADD'].includes(m.movementType)) {
          currentStock += qty;
        } else {
          currentStock -= qty;
        }

        if (m.movementType === StockMovementType.PURCHASE) {
          totalPurchaseCost = totalPurchaseCost.plus(m.quantity.mul(m.unitCost));
          totalPurchaseQty = totalPurchaseQty.plus(m.quantity);
        }
      }

      const minLevel = Number(p.minStockLevel || 0);
      let stockStatus: 'IN_STOCK' | 'LOW_STOCK' | 'OUT_OF_STOCK' = 'IN_STOCK';
      if (currentStock <= 0) {
        stockStatus = 'OUT_OF_STOCK';
      } else if (currentStock <= minLevel) {
        stockStatus = 'LOW_STOCK';
      }

      let unitCost = p.purchasePrice ? Number(p.purchasePrice) : 0;
      if (!totalPurchaseQty.isZero()) {
        unitCost = Number(totalPurchaseCost.div(totalPurchaseQty).toFixed(2));
      }

      const valuation = currentStock > 0 ? Number((currentStock * unitCost).toFixed(2)) : 0;

      calculatedViews.push({
        id: p.id,
        name: p.name,
        sku: p.sku,
        barcode: p.barcode,
        categoryName: p.category?.name || null,
        unitSymbol: p.unit?.symbol || null,
        trackStock: p.trackStock,
        minStockLevel: minLevel,
        currentStock,
        stockStatus,
        unitCost,
        valuation,
      });
    }

    // Apply stock status filter if present
    let filtered = calculatedViews;
    if (query.stockStatus && query.stockStatus !== 'ALL') {
      filtered = filtered.filter((i) => i.stockStatus === query.stockStatus);
    }

    const total = filtered.length;
    const paginated = filtered.slice((page - 1) * limit, page * limit);

    return {
      success: true,
      statusCode: 200,
      data: paginated,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  }

  /**
   * Detailed chronological ledger of all stock movements for a specific product.
   */
  async getProductMovements(businessId: string, productId: string, page = 1, limit = 50) {
    const product = await this.prisma.product.findUnique({
      where: { businessId_id: { businessId, id: productId } },
      select: { id: true, name: true, sku: true },
    });

    if (!product) {
      throw new NotFoundException(`Product with ID ${productId} not found.`);
    }

    const skip = (page - 1) * limit;
    const [movements, total] = await Promise.all([
      this.prisma.stockMovement.findMany({
        where: { businessId, productId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          warehouse: { select: { name: true } },
        },
      }),
      this.prisma.stockMovement.count({ where: { businessId, productId } }),
    ]);

    return {
      success: true,
      statusCode: 200,
      data: {
        product,
        movements,
      },
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  }

  /**
   * Authorized stock adjustment (Increase, Decrease, Damage).
   * Enforces business negative-stock policy.
   */
  async createAdjustment(businessId: string, dto: CreateStockAdjustmentDto, userId?: string) {
    const product = await this.prisma.product.findUnique({
      where: { businessId_id: { businessId, id: dto.productId } },
      include: {
        stockMovements: {
          select: { movementType: true, quantity: true },
        },
      },
    });

    if (!product) {
      throw new NotFoundException(`Product with ID ${dto.productId} not found.`);
    }

    const business = await this.prisma.business.findUnique({
      where: { id: businessId },
      include: { settings: true },
    });

    const allowNegativeStock = business?.settings?.allowNegativeStock ?? false;

    // Calculate current available stock
    const currentStock = product.stockMovements.reduce((acc, m) => {
      const q = Number(m.quantity);
      if (['PURCHASE', 'SALE_RETURN', 'ADJUSTMENT_ADD'].includes(m.movementType)) {
        return acc + q;
      } else {
        return acc - q;
      }
    }, 0);

    // Negative stock policy enforcement
    const isReduction =
      dto.movementType === StockMovementType.ADJUSTMENT_SUB ||
      dto.movementType === StockMovementType.DAMAGE;

    if (isReduction && !allowNegativeStock && currentStock < dto.quantity) {
      throw new BadRequestException(
        `Cannot reduce stock below zero. Current stock: ${currentStock}, Requested adjustment: ${dto.quantity}.`,
      );
    }

    return await this.prisma.$transaction(async (tx) => {
      let warehouseId = dto.warehouseId;
      if (!warehouseId) {
        const wh = await tx.warehouse.findFirst({
          where: { businessId, isDefault: true },
        }) || (await tx.warehouse.findFirst({ where: { businessId } }));

        if (!wh) {
          throw new NotFoundException('No warehouse found for this business.');
        }
        warehouseId = wh.id;
      }

      const qty = new Prisma.Decimal(dto.quantity);
      const unitCost = dto.unitCost
        ? new Prisma.Decimal(dto.unitCost)
        : (product.purchasePrice || new Prisma.Decimal(0));

      // 1. Create traceable StockMovement
      const movement = await tx.stockMovement.create({
        data: {
          businessId,
          warehouseId,
          productId: dto.productId,
          movementType: dto.movementType,
          quantity: qty,
          unitCost,
          referenceType: 'MANUAL_ADJUSTMENT',
          notes: `${dto.reason}${dto.notes ? ` - ${dto.notes}` : ''}`,
        },
      });

      // 2. Update Stock on hand
      if (dto.movementType === StockMovementType.ADJUSTMENT_ADD) {
        await tx.stock.upsert({
          where: {
            businessId_id: { businessId, id: `${warehouseId}_${dto.productId}` },
          },
          update: { quantityOnHand: { increment: qty } },
          create: {
            id: `${warehouseId}_${dto.productId}`,
            businessId,
            warehouseId,
            productId: dto.productId,
            quantityOnHand: qty,
          },
        });
      } else {
        await tx.stock.upsert({
          where: {
            businessId_id: { businessId, id: `${warehouseId}_${dto.productId}` },
          },
          update: { quantityOnHand: { decrement: qty } },
          create: {
            id: `${warehouseId}_${dto.productId}`,
            businessId,
            warehouseId,
            productId: dto.productId,
            quantityOnHand: new Prisma.Decimal(0).minus(qty),
          },
        });
      }

      // 3. Write AuditLog
      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'STOCK_ADJUSTED',
          entityName: 'Product',
          entityId: dto.productId,
          newValues: {
            movementType: dto.movementType,
            quantity: dto.quantity,
            reason: dto.reason,
            warehouseId,
          },
        },
      });

      return {
        success: true,
        statusCode: 201,
        data: movement,
      };
    });
  }
}
