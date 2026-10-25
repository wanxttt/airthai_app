import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateUnitDto } from './dto/create-unit.dto';
import { UpdateUnitDto } from './dto/update-unit.dto';

@Injectable()
export class UnitsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(businessId: string, dto: CreateUnitDto) {
    const trimmedSymbol = dto.symbol.trim();
    const trimmedName = dto.name.trim();

    const existing = await this.prisma.unit.findUnique({
      where: {
        businessId_symbol: {
          businessId,
          symbol: trimmedSymbol,
        },
      },
    });

    if (existing) {
      throw new ConflictException(
        `Unit with symbol '${trimmedSymbol}' already exists in your business.`,
      );
    }

    return await this.prisma.unit.create({
      data: {
        businessId,
        name: trimmedName,
        symbol: trimmedSymbol,
      },
    });
  }

  async findAll(businessId: string) {
    return await this.prisma.unit.findMany({
      where: { businessId },
      include: {
        _count: {
          select: { products: true },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  async findOne(businessId: string, id: string) {
    const unit = await this.prisma.unit.findUnique({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
      include: {
        _count: {
          select: { products: true },
        },
      },
    });

    if (!unit) {
      throw new NotFoundException('Unit not found.');
    }

    return unit;
  }

  async update(businessId: string, id: string, dto: UpdateUnitDto) {
    await this.findOne(businessId, id);

    const updateData: { name?: string; symbol?: string } = {};

    if (dto.name !== undefined) {
      updateData.name = dto.name.trim();
    }

    if (dto.symbol !== undefined) {
      const trimmedSymbol = dto.symbol.trim();
      const existing = await this.prisma.unit.findUnique({
        where: {
          businessId_symbol: {
            businessId,
            symbol: trimmedSymbol,
          },
        },
      });

      if (existing && existing.id !== id) {
        throw new ConflictException(
          `Unit with symbol '${trimmedSymbol}' already exists in your business.`,
        );
      }
      updateData.symbol = trimmedSymbol;
    }

    return await this.prisma.unit.update({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
      data: updateData,
    });
  }

  async delete(businessId: string, id: string) {
    await this.findOne(businessId, id);

    const productCount = await this.prisma.product.count({
      where: {
        businessId,
        unitId: id,
      },
    });

    if (productCount > 0) {
      throw new BadRequestException(
        `Cannot delete unit: it is referenced by ${productCount} product(s). Please reassign or delete the products first.`,
      );
    }

    await this.prisma.unit.delete({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
    });

    return {
      success: true,
      message: 'Unit deleted successfully.',
    };
  }
}

