import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { Prisma } from '@prisma/client';
import { QueryGstDto } from './dto/query-report.dto';

export const GST_STATUTORY_DISCLAIMER =
  'This report is a statutory preparation summary generated from AirthAI financial ledgers. ' +
  'AirthAI does not provide automated filing or direct transmission to the GST Common Portal (GSTN). ' +
  'Returns must be reviewed and filed by an authorized tax practitioner or signatory.';

@Injectable()
export class GstService {
  private readonly logger = new Logger(GstService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Helper to format return period (e.g. 2026-10) from date.
   */
  public getReturnPeriod(date: Date = new Date()): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    return `${year}-${month}`;
  }

  /**
   * GSTR-1 Preparation Summary: Outward supplies to registered and unregistered persons, plus HSN summary.
   */
  public async getGstr1Summary(businessId: string, query: QueryGstDto) {
    const period = query.returnPeriod || this.getReturnPeriod();

    const where: Prisma.GstRecordWhereInput = {
      businessId,
      isCancelled: false,
      transactionType: { in: ['B2B', 'B2C'] },
    };

    if (query.returnPeriod) {
      where.returnPeriod = query.returnPeriod;
    } else if (query.startDate || query.endDate) {
      where.createdAt = {};
      if (query.startDate) where.createdAt.gte = new Date(query.startDate);
      if (query.endDate) where.createdAt.lte = new Date(query.endDate);
    } else {
      where.returnPeriod = period;
    }

    const records = await this.prisma.gstRecord.findMany({
      where,
      include: {
        invoice: {
          include: {
            items: true,
            customer: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    let totalTaxable = new Prisma.Decimal(0);
    let totalCgst = new Prisma.Decimal(0);
    let totalSgst = new Prisma.Decimal(0);
    let totalIgst = new Prisma.Decimal(0);
    let totalCess = new Prisma.Decimal(0);

    const b2bInvoices: any[] = [];
    const b2cInvoices: any[] = [];
    const hsnMap = new Map<
      string,
      {
        hsnCode: string;
        description: string;
        quantity: Prisma.Decimal;
        taxableValue: Prisma.Decimal;
        cgstAmount: Prisma.Decimal;
        sgstAmount: Prisma.Decimal;
        igstAmount: Prisma.Decimal;
        totalTax: Prisma.Decimal;
      }
    >();

    for (const rec of records) {
      totalTaxable = totalTaxable.plus(rec.taxableValue);
      totalCgst = totalCgst.plus(rec.cgstAmount);
      totalSgst = totalSgst.plus(rec.sgstAmount);
      totalIgst = totalIgst.plus(rec.igstAmount);
      totalCess = totalCess.plus(rec.cessAmount);

      const isB2B = rec.transactionType === 'B2B' || (rec.gstin && rec.gstin.trim().length > 0);

      const entry = {
        gstRecordId: rec.id,
        invoiceId: rec.invoiceId,
        invoiceNumber: rec.invoice?.invoiceNumber || 'N/A',
        invoiceDate: rec.invoice?.invoiceDate || rec.createdAt,
        customerName: rec.invoice?.customer?.name || 'Walk-in Customer',
        customerGstin: rec.gstin || null,
        placeOfSupply: rec.placeOfSupply,
        taxableValue: rec.taxableValue.toNumber(),
        cgstAmount: rec.cgstAmount.toNumber(),
        sgstAmount: rec.sgstAmount.toNumber(),
        igstAmount: rec.igstAmount.toNumber(),
        cessAmount: rec.cessAmount.toNumber(),
        totalTax: rec.cgstAmount.plus(rec.sgstAmount).plus(rec.igstAmount).plus(rec.cessAmount).toNumber(),
        totalInvoiceAmount: rec.invoice?.totalAmount.toNumber() || rec.taxableValue.toNumber(),
      };

      if (isB2B) {
        b2bInvoices.push(entry);
      } else {
        b2cInvoices.push(entry);
      }

      // Aggregate HSN Table 12
      if (rec.invoice?.items) {
        for (const item of rec.invoice.items) {
          const code = item.hsnCode || 'OTHER';
          const existing = hsnMap.get(code) || {
            hsnCode: code,
            description: item.description,
            quantity: new Prisma.Decimal(0),
            taxableValue: new Prisma.Decimal(0),
            cgstAmount: new Prisma.Decimal(0),
            sgstAmount: new Prisma.Decimal(0),
            igstAmount: new Prisma.Decimal(0),
            totalTax: new Prisma.Decimal(0),
          };

          existing.quantity = existing.quantity.plus(item.quantity);
          existing.taxableValue = existing.taxableValue.plus(item.taxableAmount);
          existing.cgstAmount = existing.cgstAmount.plus(item.cgstAmount);
          existing.sgstAmount = existing.sgstAmount.plus(item.sgstAmount);
          existing.igstAmount = existing.igstAmount.plus(item.igstAmount);
          existing.totalTax = existing.totalTax.plus(item.cgstAmount).plus(item.sgstAmount).plus(item.igstAmount);

          hsnMap.set(code, existing);
        }
      }
    }

    const totalTaxLiability = totalCgst.plus(totalSgst).plus(totalIgst).plus(totalCess);

    return {
      statusCode: 200,
      message: 'GSTR-1 preparation summary calculated successfully',
      disclaimer: GST_STATUTORY_DISCLAIMER,
      data: {
        returnPeriod: period,
        totalTaxableValue: totalTaxable.toNumber(),
        totalCgst: totalCgst.toNumber(),
        totalSgst: totalSgst.toNumber(),
        totalIgst: totalIgst.toNumber(),
        totalCess: totalCess.toNumber(),
        totalTaxLiability: totalTaxLiability.toNumber(),
        table4B2B: {
          count: b2bInvoices.length,
          taxableValue: b2bInvoices.reduce((acc, curr) => acc + curr.taxableValue, 0),
          taxAmount: b2bInvoices.reduce((acc, curr) => acc + curr.totalTax, 0),
          invoices: b2bInvoices,
        },
        table7B2C: {
          count: b2cInvoices.length,
          taxableValue: b2cInvoices.reduce((acc, curr) => acc + curr.taxableValue, 0),
          taxAmount: b2cInvoices.reduce((acc, curr) => acc + curr.totalTax, 0),
          invoices: b2cInvoices,
        },
        table12HsnSummary: Array.from(hsnMap.values()).map((h) => ({
          hsnCode: h.hsnCode,
          description: h.description,
          quantity: h.quantity.toNumber(),
          taxableValue: h.taxableValue.toNumber(),
          cgstAmount: h.cgstAmount.toNumber(),
          sgstAmount: h.sgstAmount.toNumber(),
          igstAmount: h.igstAmount.toNumber(),
          totalTax: h.totalTax.toNumber(),
        })),
      },
    };
  }

  /**
   * GSTR-3B Preparation Summary: Monthly summary of outward tax liability and eligible Input Tax Credit (ITC).
   */
  public async getGstr3bSummary(businessId: string, query: QueryGstDto) {
    const period = query.returnPeriod || this.getReturnPeriod();

    const where: Prisma.GstRecordWhereInput = {
      businessId,
      isCancelled: false,
    };

    if (query.returnPeriod) {
      where.returnPeriod = query.returnPeriod;
    } else if (query.startDate || query.endDate) {
      where.createdAt = {};
      if (query.startDate) where.createdAt.gte = new Date(query.startDate);
      if (query.endDate) where.createdAt.lte = new Date(query.endDate);
    } else {
      where.returnPeriod = period;
    }

    const [outwardRecords, inwardRecords, expenses] = await Promise.all([
      this.prisma.gstRecord.findMany({
        where: { ...where, transactionType: { in: ['B2B', 'B2C'] } },
      }),
      this.prisma.gstRecord.findMany({
        where: { ...where, transactionType: 'PURCHASE' },
      }),
      this.prisma.expense.findMany({
        where: {
          businessId,
          ...(query.returnPeriod
            ? {
                expenseDate: {
                  gte: new Date(`${period}-01`),
                  lt: new Date(new Date(`${period}-01`).setMonth(new Date(`${period}-01`).getMonth() + 1)),
                },
              }
            : query.startDate || query.endDate
            ? {
                expenseDate: {
                  ...(query.startDate ? { gte: new Date(query.startDate) } : {}),
                  ...(query.endDate ? { lte: new Date(query.endDate) } : {}),
                },
              }
            : {}),
          gstAmount: { gt: 0 },
        },
      }),
    ]);

    // 1. Table 3.1: Outward Supplies Liability
    let outTaxable = new Prisma.Decimal(0);
    let outCgst = new Prisma.Decimal(0);
    let outSgst = new Prisma.Decimal(0);
    let outIgst = new Prisma.Decimal(0);
    let outCess = new Prisma.Decimal(0);

    for (const r of outwardRecords) {
      outTaxable = outTaxable.plus(r.taxableValue);
      outCgst = outCgst.plus(r.cgstAmount);
      outSgst = outSgst.plus(r.sgstAmount);
      outIgst = outIgst.plus(r.igstAmount);
      outCess = outCess.plus(r.cessAmount);
    }

    // 2. Table 4: Eligible Input Tax Credit (ITC)
    let itcTaxable = new Prisma.Decimal(0);
    let itcCgst = new Prisma.Decimal(0);
    let itcSgst = new Prisma.Decimal(0);
    let itcIgst = new Prisma.Decimal(0);

    for (const r of inwardRecords) {
      itcTaxable = itcTaxable.plus(r.taxableValue);
      itcCgst = itcCgst.plus(r.cgstAmount);
      itcSgst = itcSgst.plus(r.sgstAmount);
      itcIgst = itcIgst.plus(r.igstAmount);
    }

    // Add eligible expenses GST to ITC
    for (const exp of expenses) {
      itcTaxable = itcTaxable.plus(exp.amount.minus(exp.gstAmount));
      const halfGst = exp.gstAmount.div(2);
      itcCgst = itcCgst.plus(halfGst);
      itcSgst = itcSgst.plus(halfGst);
    }

    // 3. Net Tax Payable: Max(0, Outward Liability - ITC)
    const netIgst = Prisma.Decimal.max(0, outIgst.minus(itcIgst));
    const netCgst = Prisma.Decimal.max(0, outCgst.minus(itcCgst));
    const netSgst = Prisma.Decimal.max(0, outSgst.minus(itcSgst));
    const totalNetPayable = netIgst.plus(netCgst).plus(netSgst).plus(outCess);

    return {
      statusCode: 200,
      message: 'GSTR-3B preparation summary calculated successfully',
      disclaimer: GST_STATUTORY_DISCLAIMER,
      data: {
        returnPeriod: period,
        table31OutwardSupplies: {
          taxableValue: outTaxable.toNumber(),
          igstAmount: outIgst.toNumber(),
          cgstAmount: outCgst.toNumber(),
          sgstAmount: outSgst.toNumber(),
          cessAmount: outCess.toNumber(),
          totalOutwardTax: outIgst.plus(outCgst).plus(outSgst).plus(outCess).toNumber(),
        },
        table4EligibleItc: {
          taxableValue: itcTaxable.toNumber(),
          igstAmount: itcIgst.toNumber(),
          cgstAmount: itcCgst.toNumber(),
          sgstAmount: itcSgst.toNumber(),
          totalItcAvailable: itcIgst.plus(itcCgst).plus(itcSgst).toNumber(),
        },
        netTaxPayable: {
          igst: netIgst.toNumber(),
          cgst: netCgst.toNumber(),
          sgst: netSgst.toNumber(),
          cess: outCess.toNumber(),
          totalPayable: totalNetPayable.toNumber(),
        },
      },
    };
  }

  /**
   * High-level overview of GST position (Sales tax collected vs Inward ITC).
   */
  public async getTaxSummary(businessId: string, startDate?: Date, endDate?: Date) {
    const where: Prisma.GstRecordWhereInput = {
      businessId,
      isCancelled: false,
    };

    if (startDate || endDate) {
      where.createdAt = {};
      if (startDate) where.createdAt.gte = startDate;
      if (endDate) where.createdAt.lte = endDate;
    }

    const records = await this.prisma.gstRecord.findMany({ where });

    let salesTaxable = new Prisma.Decimal(0);
    let salesTax = new Prisma.Decimal(0);
    let purchaseTaxable = new Prisma.Decimal(0);
    let purchaseTax = new Prisma.Decimal(0);

    for (const r of records) {
      const tax = r.cgstAmount.plus(r.sgstAmount).plus(r.igstAmount).plus(r.cessAmount);
      if (r.transactionType === 'B2B' || r.transactionType === 'B2C') {
        salesTaxable = salesTaxable.plus(r.taxableValue);
        salesTax = salesTax.plus(tax);
      } else if (r.transactionType === 'PURCHASE') {
        purchaseTaxable = purchaseTaxable.plus(r.taxableValue);
        purchaseTax = purchaseTax.plus(tax);
      }
    }

    const netTaxPayable = Prisma.Decimal.max(0, salesTax.minus(purchaseTax));

    return {
      statusCode: 200,
      message: 'GST summary retrieved',
      disclaimer: GST_STATUTORY_DISCLAIMER,
      data: {
        salesTaxable: salesTaxable.toNumber(),
        salesTaxCollected: salesTax.toNumber(),
        purchaseTaxable: purchaseTaxable.toNumber(),
        inputTaxCreditAvailable: purchaseTax.toNumber(),
        netTaxPayable: netTaxPayable.toNumber(),
        totalGstRecords: records.length,
      },
    };
  }
}
