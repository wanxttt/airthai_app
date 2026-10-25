import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductsDto } from './dto/query-products.dto';
import { ItemType, StockMovementType } from '@prisma/client';

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(businessId: string, dto: CreateProductDto) {
    const trimmedName = dto.name.trim();

    // Verify category belongs to this business
    if (dto.categoryId) {
      const category = await this.prisma.category.findUnique({
        where: {
          businessId_id: {
            businessId,
            id: dto.categoryId,
          },
        },
      });
      if (!category) {
        throw new BadRequestException('Selected category does not belong to your business.');
      }
    }

    // Verify unit belongs to this business
    if (dto.unitId) {
      const unit = await this.prisma.unit.findUnique({
        where: {
          businessId_id: {
            businessId,
            id: dto.unitId,
          },
        },
      });
      if (!unit) {
        throw new BadRequestException('Selected unit does not belong to your business.');
      }
    }

    // Verify SKU uniqueness within this business
    if (dto.sku) {
      const trimmedSku = dto.sku.trim();
      const existingSku = await this.prisma.product.findFirst({
        where: {
          businessId,
          sku: trimmedSku,
        },
      });
      if (existingSku) {
        throw new ConflictException(
          `Product with SKU '${trimmedSku}' already exists in your business.`,
        );
      }
    }

    const openingStock = dto.openingStock && dto.openingStock > 0 ? dto.openingStock : 0;

    return await this.prisma.$transaction(async (tx) => {
      const product = await tx.product.create({
        data: {
          businessId,
          name: trimmedName,
          sku: dto.sku ? dto.sku.trim() : null,
          barcode: dto.barcode ? dto.barcode.trim() : null,
          description: dto.description ? dto.description.trim() : null,
          hsnCode: dto.hsnCode ? dto.hsnCode.trim() : null,
          itemType: dto.itemType || ItemType.GOODS,
          trackStock: dto.trackStock !== undefined ? dto.trackStock : true,
          categoryId: dto.categoryId || null,
          unitId: dto.unitId || null,
          gstRate: dto.gstRate !== undefined ? dto.gstRate : 0,
          cessRate: dto.cessRate !== undefined ? dto.cessRate : 0,
          purchasePrice: dto.purchasePrice !== undefined ? dto.purchasePrice : 0,
          salePrice: dto.salePrice !== undefined ? dto.salePrice : 0,
          mrp: dto.mrp !== undefined ? dto.mrp : null,
          minStockLevel: dto.minStockLevel !== undefined ? dto.minStockLevel : 0,
          currentStock: openingStock,
          status: 'ACTIVE',
        },
        include: {
          category: true,
          unit: true,
        },
      });

      // If opening stock provided and stock is tracked, register warehouse stock
      if (openingStock > 0 && product.trackStock) {
        let warehouse = await tx.warehouse.findFirst({
          where: { businessId, isDefault: true },
        });

        if (!warehouse) {
          warehouse = await tx.warehouse.findFirst({
            where: { businessId },
          });
        }

        if (!warehouse) {
          warehouse = await tx.warehouse.create({
            data: {
              businessId,
              name: 'Main Warehouse',
              isDefault: true,
            },
          });
        }

        await tx.stock.create({
          data: {
            businessId,
            warehouseId: warehouse.id,
            productId: product.id,
            quantityOnHand: openingStock,
          },
        });

        await tx.stockMovement.create({
          data: {
            businessId,
            warehouseId: warehouse.id,
            productId: product.id,
            movementType: StockMovementType.ADJUSTMENT_ADD,
            quantity: openingStock,
            unitCost: dto.purchasePrice || 0,
          },
        });
      }

      return product;
    });
  }

  async findAll(businessId: string, query: QueryProductsDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const skip = (page - 1) * limit;

    const where: any = { businessId };

    if (query.status && query.status !== 'ALL') {
      where.status = query.status;
    } else if (!query.status) {
      where.status = 'ACTIVE';
    }

    if (query.categoryId) {
      where.categoryId = query.categoryId;
    }

    if (query.trackStock !== undefined) {
      where.trackStock = query.trackStock;
    }

    if (query.search && query.search.trim().length > 0) {
      const term = query.search.trim();
      where.OR = [
        { name: { contains: term, mode: 'insensitive' } },
        { sku: { contains: term, mode: 'insensitive' } },
        { barcode: { contains: term, mode: 'insensitive' } },
      ];
    }

    const [total, products] = await Promise.all([
      this.prisma.product.count({ where }),
      this.prisma.product.findMany({
        where,
        include: {
          category: {
            select: { id: true, name: true },
          },
          unit: {
            select: { id: true, name: true, symbol: true },
          },
        },
        orderBy: { name: 'asc' },
        skip,
        take: limit,
      }),
    ]);

    return {
      data: products,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  }

  async findOne(businessId: string, id: string) {
    const product = await this.prisma.product.findUnique({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
      include: {
        category: true,
        unit: true,
        stocks: {
          include: { warehouse: true },
        },
      },
    });

    if (!product) {
      throw new NotFoundException('Product not found in your business.');
    }

    return product;
  }

  async update(businessId: string, id: string, dto: UpdateProductDto) {
    await this.findOne(businessId, id);

    // Verify category belongs to this business if provided
    if (dto.categoryId) {
      const category = await this.prisma.category.findUnique({
        where: {
          businessId_id: {
            businessId,
            id: dto.categoryId,
          },
        },
      });
      if (!category) {
        throw new BadRequestException('Selected category does not belong to your business.');
      }
    }

    // Verify unit belongs to this business if provided
    if (dto.unitId) {
      const unit = await this.prisma.unit.findUnique({
        where: {
          businessId_id: {
            businessId,
            id: dto.unitId,
          },
        },
      });
      if (!unit) {
        throw new BadRequestException('Selected unit does not belong to your business.');
      }
    }

    // Verify SKU uniqueness if changing
    if (dto.sku) {
      const trimmedSku = dto.sku.trim();
      const existingSku = await this.prisma.product.findFirst({
        where: {
          businessId,
          sku: trimmedSku,
          NOT: { id },
        },
      });
      if (existingSku) {
        throw new ConflictException(
          `Product with SKU '${trimmedSku}' already exists in your business.`,
        );
      }
    }

    return await this.prisma.product.update({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
      data: {
        name: dto.name !== undefined ? dto.name.trim() : undefined,
        sku: dto.sku !== undefined ? (dto.sku ? dto.sku.trim() : null) : undefined,
        barcode: dto.barcode !== undefined ? (dto.barcode ? dto.barcode.trim() : null) : undefined,
        description: dto.description !== undefined ? (dto.description ? dto.description.trim() : null) : undefined,
        hsnCode: dto.hsnCode !== undefined ? (dto.hsnCode ? dto.hsnCode.trim() : null) : undefined,
        itemType: dto.itemType,
        trackStock: dto.trackStock,
        categoryId: dto.categoryId !== undefined ? (dto.categoryId || null) : undefined,
        unitId: dto.unitId !== undefined ? (dto.unitId || null) : undefined,
        gstRate: dto.gstRate,
        cessRate: dto.cessRate,
        purchasePrice: dto.purchasePrice,
        salePrice: dto.salePrice,
        mrp: dto.mrp !== undefined ? dto.mrp : undefined,
        minStockLevel: dto.minStockLevel,
        status: dto.status,
      },
      include: {
        category: true,
        unit: true,
      },
    });
  }

  async toggleArchive(businessId: string, id: string) {
    const product = await this.findOne(businessId, id);
    const newStatus = product.status === 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE';

    return await this.prisma.product.update({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
      data: { status: newStatus },
    });
  }

  async delete(businessId: string, id: string) {
    await this.findOne(businessId, id);

    // Prevent deletion if referenced by sales or purchases
    const [invoiceCount, purchaseCount, quoteCount, orderCount] = await Promise.all([
      this.prisma.invoiceItem.count({ where: { productId: id } }),
      this.prisma.purchaseItem.count({ where: { productId: id } }),
      this.prisma.quotationItem.count({ where: { productId: id } }),
      this.prisma.salesOrderItem.count({ where: { productId: id } }),
    ]);

    const totalReferences = invoiceCount + purchaseCount + quoteCount + orderCount;

    if (totalReferences > 0) {
      throw new BadRequestException(
        `Cannot delete product: it is referenced by existing transactions (${totalReferences} record(s)). Archive it instead to retain audit records.`,
      );
    }

    // Clean up related stocks & stockMovements before deleting product
    await this.prisma.$transaction(async (tx) => {
      await tx.stockMovement.deleteMany({
        where: { businessId, productId: id },
      });
      await tx.stock.deleteMany({
        where: { businessId, productId: id },
      });
      await tx.productVariant.deleteMany({
        where: { businessId, productId: id },
      });
      await tx.product.delete({
        where: {
          businessId_id: {
            businessId,
            id,
          },
        },
      });
    });

    return {
      success: true,
      message: 'Product deleted successfully.',
    };
  }
}
