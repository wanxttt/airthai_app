import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { Prisma } from '@prisma/client';

@Injectable()
export class SequenceService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Calculate Indian Fiscal Year (April 1 to March 31).
   * e.g. Oct 2026 -> "2026-27"; Feb 2027 -> "2026-27"
   */
  public getFiscalYear(date: Date = new Date()): string {
    const year = date.getFullYear();
    const month = date.getMonth(); // 0-indexed: 0=Jan, 3=Apr

    if (month >= 3) {
      const nextYearShort = String((year + 1) % 100).padStart(2, '0');
      return `${year}-${nextYearShort}`;
    } else {
      const currentYearShort = String(year % 100).padStart(2, '0');
      return `${year - 1}-${currentYearShort}`;
    }
  }

  /**
   * Concurrency-safe atomic generation of document numbers.
   * Can be executed within a Prisma transaction client.
   */
  public async getNextNumber(
    businessId: string,
    documentType: 'INVOICE' | 'QUOTATION' | 'ORDER' | 'RECEIPT' | 'PAYMENT' | 'EXPENSE' | 'JOURNAL' | string,
    defaultPrefix: string = 'INV',
    date: Date = new Date(),
    tx?: Prisma.TransactionClient,
  ): Promise<string> {
    const client = tx || this.prisma;
    const fiscalYear = this.getFiscalYear(date);

    const seq = await client.documentSequence.upsert({
      where: {
        businessId_documentType_fiscalYear: {
          businessId,
          documentType,
          fiscalYear,
        },
      },
      update: {
        nextNumber: {
          increment: 1,
        },
      },
      create: {
        businessId,
        documentType,
        fiscalYear,
        prefix: defaultPrefix,
        nextNumber: 2,
      },
    });

    const allocatedNumber = seq.nextNumber - 1;
    const padded = String(allocatedNumber).padStart(4, '0');
    return `${seq.prefix}-${fiscalYear}-${padded}`;
  }
}
