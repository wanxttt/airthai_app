import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { SequenceService } from './sequence.service';
import { InvoicesService } from './invoices.service';
import { CreateQuotationDto } from './dto/create-quotation.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class QuotationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
    private readonly invoicesService: InvoicesService,
  ) {}

  async findAll(businessId: string, search?: string, status?: string) {
    const where: Prisma.QuotationWhereInput = { businessId };

    if (status && status !== 'ALL') {
      where.status = status;
    }

    if (search && search.trim()) {
      const term = search.trim();
      where.OR = [
        { quotationNumber: { contains: term, mode: 'insensitive' } },
        { customer: { name: { contains: term, mode: 'insensitive' } } },
      ];
    }

    const quotations = await this.prisma.quotation.findMany({
      where,
      orderBy: { date: 'desc' },
      include: {
        customer: {
          select: { id: true, name: true, phone: true },
        },
        items: true,
      },
    });

    return {
      success: true,
      statusCode: 200,
      data: quotations,
    };
  }

  async findOne(businessId: string, id: string) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { businessId_id: { businessId, id } },
      include: {
        customer: true,
        items: {
          include: {
            product: {
              select: { id: true, name: true, sku: true },
            },
          },
        },
      },
    });

    if (!quotation) {
      throw new NotFoundException(`Quotation with ID ${id} not found.`);
    }

    return {
      success: true,
      statusCode: 200,
      data: quotation,
    };
  }

  async create(businessId: string, dto: CreateQuotationDto) {
    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException('Quotation must contain at least one item.');
    }

    const quotationDate = dto.date ? new Date(dto.date) : new Date();
    const quotationNumber = await this.sequenceService.getNextNumber(
      businessId,
      'QUOTATION',
      'QUO',
      quotationDate,
    );

    let subtotal = new Prisma.Decimal(0);
    let taxAmount = new Prisma.Decimal(0);

    const calculatedItems = dto.items.map((it) => {
      const qty = new Prisma.Decimal(it.quantity);
      const price = new Prisma.Decimal(it.unitPrice);
      const gross = qty.mul(price);
      const discount = new Prisma.Decimal(it.discountAmount || 0);
      const taxable = Prisma.Decimal.max(0, gross.minus(discount));
      const rate = new Prisma.Decimal(it.gstRate || 0);
      const tax = taxable.mul(rate).div(100);
      const total = taxable.plus(tax);

      subtotal = subtotal.plus(gross);
      taxAmount = taxAmount.plus(tax);

      return {
        productId: it.productId || null,
        description: it.description,
        hsnCode: it.hsnCode || null,
        quantity: qty,
        unitPrice: price,
        discountAmount: discount,
        taxAmount: tax,
        totalAmount: total,
      };
    });

    const invoiceDiscount = new Prisma.Decimal(dto.discountAmount || 0);
    const totalAmount = subtotal.minus(invoiceDiscount).plus(taxAmount);

    const quotation = await this.prisma.quotation.create({
      data: {
        businessId,
        customerId: dto.customerId || null,
        quotationNumber,
        date: quotationDate,
        validUntil: dto.validUntil ? new Date(dto.validUntil) : null,
        status: 'DRAFT',
        subtotal,
        discountAmount: invoiceDiscount,
        taxAmount,
        totalAmount,
        notes: dto.notes || null,
        items: {
          create: calculatedItems,
        },
      },
      include: {
        items: true,
        customer: true,
      },
    });

    return {
      success: true,
      statusCode: 201,
      data: quotation,
    };
  }

  /**
   * Convert an existing quotation directly into an official issued Invoice.
   */
  async convertToInvoice(businessId: string, id: string, userId?: string) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { businessId_id: { businessId, id } },
      include: { items: true, customer: true },
    });

    if (!quotation) {
      throw new NotFoundException(`Quotation with ID ${id} not found.`);
    }

    if (quotation.status === 'CONVERTED') {
      throw new BadRequestException('Quotation has already been converted to an invoice.');
    }

    // Create the invoice
    const invoiceResult = await this.invoicesService.create(
      businessId,
      {
        customerId: quotation.customerId || undefined,
        invoiceDate: new Date().toISOString(),
        placeOfSupply: quotation.customer?.state || '27',
        notes: `Converted from Quotation ${quotation.quotationNumber}. ${quotation.notes || ''}`,
        discountAmount: Number(quotation.discountAmount),
        items: quotation.items.map((it) => ({
          productId: it.productId || undefined,
          description: it.description,
          hsnCode: it.hsnCode || undefined,
          quantity: Number(it.quantity),
          unitPrice: Number(it.unitPrice),
          discountAmount: Number(it.discountAmount),
          gstRate: it.taxAmount.isZero() ? 0 : 18, // default or rate
        })),
      },
      userId,
    );

    // Update quotation status to CONVERTED
    await this.prisma.quotation.update({
      where: { businessId_id: { businessId, id } },
      data: { status: 'CONVERTED' },
    });

    return invoiceResult;
  }
}
