import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';
import { QuerySuppliersDto } from './dto/query-suppliers.dto';

@Injectable()
export class SuppliersService {
  constructor(private readonly prisma: PrismaService) {}

  async create(businessId: string, dto: CreateSupplierDto) {
    const openingBal = dto.openingBalance !== undefined ? dto.openingBalance : 0;

    return await this.prisma.supplier.create({
      data: {
        businessId,
        name: dto.name.trim(),
        phone: dto.phone ? dto.phone.trim() : null,
        email: dto.email ? dto.email.trim().toLowerCase() : null,
        gstin: dto.gstin ? dto.gstin.trim().toUpperCase() : null,
        pan: dto.pan ? dto.pan.trim().toUpperCase() : null,
        address: dto.address ? dto.address.trim() : null,
        city: dto.city ? dto.city.trim() : null,
        state: dto.state ? dto.state.trim() : null,
        stateCode: dto.stateCode ? dto.stateCode.trim() : null,
        bankName: dto.bankName ? dto.bankName.trim() : null,
        accountNumber: dto.accountNumber ? dto.accountNumber.trim() : null,
        ifscCode: dto.ifscCode ? dto.ifscCode.trim().toUpperCase() : null,
        openingBalance: openingBal,
        currentBalance: openingBal,
        status: 'ACTIVE',
      },
    });
  }

  async findAll(businessId: string, query: QuerySuppliersDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const skip = (page - 1) * limit;

    const where: any = { businessId };

    if (query.status && query.status !== 'ALL') {
      where.status = query.status;
    } else if (!query.status) {
      where.status = 'ACTIVE';
    }

    if (query.search && query.search.trim().length > 0) {
      const term = query.search.trim();
      where.OR = [
        { name: { contains: term, mode: 'insensitive' } },
        { phone: { contains: term, mode: 'insensitive' } },
        { email: { contains: term, mode: 'insensitive' } },
        { gstin: { contains: term, mode: 'insensitive' } },
        { pan: { contains: term, mode: 'insensitive' } },
      ];
    }

    const [total, suppliers, aggregate] = await Promise.all([
      this.prisma.supplier.count({ where }),
      this.prisma.supplier.findMany({
        where,
        orderBy: { name: 'asc' },
        skip,
        take: limit,
      }),
      this.prisma.supplier.aggregate({
        where: { businessId, status: 'ACTIVE' },
        _sum: { currentBalance: true },
      }),
    ]);

    return {
      data: suppliers,
      summary: {
        totalPayables: aggregate._sum.currentBalance || 0,
      },
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  }

  async findOne(businessId: string, id: string) {
    const supplier = await this.prisma.supplier.findUnique({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
      include: {
        purchases: {
          take: 10,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            billNumber: true,
            billDate: true,
            totalAmount: true,
            paidAmount: true,
            status: true,
          },
        },
        payments: {
          take: 10,
          orderBy: { paymentDate: 'desc' },
          select: {
            id: true,
            paymentNumber: true,
            paymentDate: true,
            amount: true,
            paymentMethod: true,
          },
        },
      },
    });

    if (!supplier) {
      throw new NotFoundException('Supplier not found in your business.');
    }

    return supplier;
  }

  async update(businessId: string, id: string, dto: UpdateSupplierDto) {
    await this.findOne(businessId, id);

    return await this.prisma.supplier.update({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
      data: {
        name: dto.name !== undefined ? dto.name.trim() : undefined,
        phone: dto.phone !== undefined ? (dto.phone ? dto.phone.trim() : null) : undefined,
        email: dto.email !== undefined ? (dto.email ? dto.email.trim().toLowerCase() : null) : undefined,
        gstin: dto.gstin !== undefined ? (dto.gstin ? dto.gstin.trim().toUpperCase() : null) : undefined,
        pan: dto.pan !== undefined ? (dto.pan ? dto.pan.trim().toUpperCase() : null) : undefined,
        address: dto.address !== undefined ? (dto.address ? dto.address.trim() : null) : undefined,
        city: dto.city !== undefined ? (dto.city ? dto.city.trim() : null) : undefined,
        state: dto.state !== undefined ? (dto.state ? dto.state.trim() : null) : undefined,
        stateCode: dto.stateCode !== undefined ? (dto.stateCode ? dto.stateCode.trim() : null) : undefined,
        bankName: dto.bankName !== undefined ? (dto.bankName ? dto.bankName.trim() : null) : undefined,
        accountNumber: dto.accountNumber !== undefined ? (dto.accountNumber ? dto.accountNumber.trim() : null) : undefined,
        ifscCode: dto.ifscCode !== undefined ? (dto.ifscCode ? dto.ifscCode.trim().toUpperCase() : null) : undefined,
        openingBalance: dto.openingBalance,
        status: dto.status,
      },
    });
  }

  async toggleArchive(businessId: string, id: string) {
    const supplier = await this.findOne(businessId, id);
    const newStatus = supplier.status === 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE';

    return await this.prisma.supplier.update({
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

    const [purchaseCount, paymentCount] = await Promise.all([
      this.prisma.purchase.count({ where: { businessId, supplierId: id } }),
      this.prisma.payment.count({ where: { businessId, supplierId: id } }),
    ]);

    const total = purchaseCount + paymentCount;
    if (total > 0) {
      throw new BadRequestException(
        `Cannot delete supplier: they have ${total} associated purchase or payment record(s). Please archive the supplier instead.`,
      );
    }

    await this.prisma.supplier.delete({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
    });

    return {
      success: true,
      message: 'Supplier deleted successfully.',
    };
  }
}
