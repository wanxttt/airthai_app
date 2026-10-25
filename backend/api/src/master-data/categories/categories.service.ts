import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(businessId: string, dto: CreateCategoryDto) {
    const trimmedName = dto.name.trim();

    const existing = await this.prisma.category.findUnique({
      where: {
        businessId_name: {
          businessId,
          name: trimmedName,
        },
      },
    });

    if (existing) {
      throw new ConflictException(
        `Category '${trimmedName}' already exists in your business.`,
      );
    }

    if (dto.parentId) {
      const parent = await this.prisma.category.findUnique({
        where: {
          businessId_id: {
            businessId,
            id: dto.parentId,
          },
        },
      });
      if (!parent) {
        throw new NotFoundException('Parent category not found in your business.');
      }
    }

    return await this.prisma.category.create({
      data: {
        businessId,
        name: trimmedName,
        parentId: dto.parentId || null,
      },
    });
  }

  async findAll(businessId: string) {
    return await this.prisma.category.findMany({
      where: { businessId },
      include: {
        _count: {
          select: { products: true, children: true },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  async findOne(businessId: string, id: string) {
    const category = await this.prisma.category.findUnique({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
      include: {
        parent: true,
        children: true,
        _count: {
          select: { products: true },
        },
      },
    });

    if (!category) {
      throw new NotFoundException('Category not found.');
    }

    return category;
  }

  async update(businessId: string, id: string, dto: UpdateCategoryDto) {
    await this.findOne(businessId, id);

    const updateData: { name?: string; parentId?: string | null } = {};

    if (dto.name !== undefined) {
      const trimmedName = dto.name.trim();
      const existing = await this.prisma.category.findUnique({
        where: {
          businessId_name: {
            businessId,
            name: trimmedName,
          },
        },
      });

      if (existing && existing.id !== id) {
        throw new ConflictException(
          `Category '${trimmedName}' already exists in your business.`,
        );
      }
      updateData.name = trimmedName;
    }

    if (dto.parentId !== undefined) {
      if (dto.parentId === id) {
        throw new BadRequestException('A category cannot be its own parent.');
      }

      if (dto.parentId) {
        const parent = await this.prisma.category.findUnique({
          where: {
            businessId_id: {
              businessId,
              id: dto.parentId,
            },
          },
        });
        if (!parent) {
          throw new NotFoundException('Parent category not found in your business.');
        }
      }
      updateData.parentId = dto.parentId || null;
    }

    return await this.prisma.category.update({
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
        categoryId: id,
      },
    });

    if (productCount > 0) {
      throw new BadRequestException(
        `Cannot delete category: it is referenced by ${productCount} product(s). Please reassign or delete the products first.`,
      );
    }

    const childCount = await this.prisma.category.count({
      where: {
        businessId,
        parentId: id,
      },
    });

    if (childCount > 0) {
      throw new BadRequestException(
        `Cannot delete category: it has ${childCount} sub-category(ies). Please reassign or delete sub-categories first.`,
      );
    }

    await this.prisma.category.delete({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
    });

    return {
      success: true,
      message: 'Category deleted successfully.',
    };
  }
}

