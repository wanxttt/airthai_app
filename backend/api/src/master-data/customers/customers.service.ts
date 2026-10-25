import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { QueryCustomersDto } from './dto/query-customers.dto';

@Injectable()
export class CustomersService {
  constructor(private readonly prisma: PrismaService) {}

  async create(businessId: string, dto: CreateCustomerDto) {
    const openingBal = dto.openingBalance !== undefined ? dto.openingBalance : 0;

    return await this.prisma.customer.create({
      data: {
        businessId,
        name: dto.name.trim(),
        phone: dto.phone ? dto.phone.trim() : null,
        email: dto.email ? dto.email.trim().toLowerCase() : null,
        gstin: dto.gstin ? dto.gstin.trim().toUpperCase() : null,
        billingAddress: dto.billingAddress ? dto.billingAddress.trim() : null,
        shippingAddress: dto.shippingAddress ? dto.shippingAddress.trim() : null,
        city: dto.city ? dto.city.trim() : null,
        state: dto.state ? dto.state.trim() : null,
        stateCode: dto.stateCode ? dto.stateCode.trim() : null,
        pincode: dto.pincode ? dto.pincode.trim() : null,
        openingBalance: openingBal,
        currentBalance: openingBal,
        creditLimit: dto.creditLimit !== undefined ? dto.creditLimit : null,
        creditPeriodDays: dto.creditPeriodDays !== undefined ? dto.creditPeriodDays : 0,
        status: 'ACTIVE',
      },
    });
  }

  async findAll(businessId: string, query: QueryCustomersDto) {
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
      ];
    }

    const [total, customers, aggregate] = await Promise.all([
      this.prisma.customer.count({ where }),
      this.prisma.customer.findMany({
        where,
        orderBy: { name: 'asc' },
        skip,
        take: limit,
      }),
      this.prisma.customer.aggregate({
        where: { businessId, status: 'ACTIVE' },
        _sum: { currentBalance: true },
      }),
    ]);

    return {
      data: customers,
      summary: {
        totalReceivables: aggregate._sum.currentBalance || 0,
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
    const customer = await this.prisma.customer.findUnique({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
      include: {
        invoices: {
          take: 10,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            invoiceNumber: true,
            invoiceDate: true,
            totalAmount: true,
            receivedAmount: true,
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

    if (!customer) {
      throw new NotFoundException('Customer not found in your business.');
    }

    return customer;
  }

  async update(businessId: string, id: string, dto: UpdateCustomerDto) {
    await this.findOne(businessId, id);

    return await this.prisma.customer.update({
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
        billingAddress: dto.billingAddress !== undefined ? (dto.billingAddress ? dto.billingAddress.trim() : null) : undefined,
        shippingAddress: dto.shippingAddress !== undefined ? (dto.shippingAddress ? dto.shippingAddress.trim() : null) : undefined,
        city: dto.city !== undefined ? (dto.city ? dto.city.trim() : null) : undefined,
        state: dto.state !== undefined ? (dto.state ? dto.state.trim() : null) : undefined,
        stateCode: dto.stateCode !== undefined ? (dto.stateCode ? dto.stateCode.trim() : null) : undefined,
        pincode: dto.pincode !== undefined ? (dto.pincode ? dto.pincode.trim() : null) : undefined,
        openingBalance: dto.openingBalance,
        creditLimit: dto.creditLimit !== undefined ? dto.creditLimit : undefined,
        creditPeriodDays: dto.creditPeriodDays,
        status: dto.status,
      },
    });
  }

  async toggleArchive(businessId: string, id: string) {
    const customer = await this.findOne(businessId, id);
    const newStatus = customer.status === 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE';

    return await this.prisma.customer.update({
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

    const [invoiceCount, paymentCount, orderCount] = await Promise.all([
      this.prisma.invoice.count({ where: { businessId, customerId: id } }),
      this.prisma.payment.count({ where: { businessId, customerId: id } }),
      this.prisma.salesOrder.count({ where: { businessId, customerId: id } }),
    ]);

    const total = invoiceCount + paymentCount + orderCount;
    if (total > 0) {
      throw new BadRequestException(
        `Cannot delete customer: they have ${total} associated transaction(s). Please archive the customer instead.`,
      );
    }

    await this.prisma.customer.delete({
      where: {
        businessId_id: {
          businessId,
          id,
        },
      },
    });

    return {
      success: true,
      message: 'Customer deleted successfully.',
    };
  }
}
