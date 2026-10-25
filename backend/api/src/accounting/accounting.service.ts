import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { SequenceService } from '../sales/sequence.service';
import { Prisma, AccountType } from '@prisma/client';
import { CreateAccountDto } from './dto/create-account.dto';
import { CreateJournalEntryDto, CreateLedgerEntryDto } from './dto/create-journal-entry.dto';
import { QueryJournalDto } from './dto/query-journal.dto';

export interface DefaultAccountSpec {
  code: string;
  name: string;
  type: AccountType;
  description?: string;
}

export const DEFAULT_CHART_OF_ACCOUNTS: DefaultAccountSpec[] = [
  // Assets (1000 - 1999)
  { code: '1000', name: 'Cash on Hand', type: AccountType.ASSET, description: 'Petty cash and drawer cash' },
  { code: '1010', name: 'Bank Account (Current/Savings)', type: AccountType.ASSET, description: 'Primary business operating bank account' },
  { code: '1100', name: 'Accounts Receivable (Debtors Control)', type: AccountType.ASSET, description: 'Amounts owed by customers for credit sales' },
  { code: '1200', name: 'Merchandise Inventory', type: AccountType.ASSET, description: 'Inventory stock on hand at cost' },
  { code: '1300', name: 'Input CGST', type: AccountType.ASSET, description: 'Central GST paid on purchases and expenses' },
  { code: '1310', name: 'Input SGST', type: AccountType.ASSET, description: 'State GST paid on purchases and expenses' },
  { code: '1320', name: 'Input IGST', type: AccountType.ASSET, description: 'Integrated GST paid on inter-state purchases' },

  // Liabilities (2000 - 2999)
  { code: '2000', name: 'Accounts Payable (Creditors Control)', type: AccountType.LIABILITY, description: 'Amounts owed to suppliers for purchases' },
  { code: '2100', name: 'Output CGST', type: AccountType.LIABILITY, description: 'Central GST collected on taxable sales' },
  { code: '2110', name: 'Output SGST', type: AccountType.LIABILITY, description: 'State GST collected on taxable sales' },
  { code: '2120', name: 'Output IGST', type: AccountType.LIABILITY, description: 'Integrated GST collected on inter-state sales' },

  // Equity (3000 - 3999)
  { code: '3000', name: "Owner's Capital", type: AccountType.EQUITY, description: "Capital introduced by business owner/partners" },
  { code: '3100', name: 'Retained Earnings', type: AccountType.EQUITY, description: 'Cumulative profits retained in the business' },
  { code: '3200', name: 'Opening Balance Equity', type: AccountType.EQUITY, description: 'Offset account for opening ledger balances' },

  // Revenue (4000 - 4999)
  { code: '4000', name: 'Sales Revenue', type: AccountType.REVENUE, description: 'Operating income from product and service sales' },
  { code: '4100', name: 'Other Operating Income', type: AccountType.REVENUE, description: 'Discounts received, interest, and incidental income' },

  // Expenses (5000 - 5999)
  { code: '5000', name: 'Cost of Goods Sold (COGS)', type: AccountType.EXPENSE, description: 'Direct inventory acquisition and production costs' },
  { code: '5100', name: 'General & Administrative Expenses', type: AccountType.EXPENSE, description: 'Office supplies, professional fees, and general overhead' },
  { code: '5200', name: 'Rent & Facilities', type: AccountType.EXPENSE, description: 'Building rent, warehouse lease, and electricity/water utilities' },
  { code: '5300', name: 'Logistics & Freight Outward', type: AccountType.EXPENSE, description: 'Transportation and courier shipping fees' },
];

@Injectable()
export class AccountingService {
  private readonly logger = new Logger(AccountingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
  ) {}

  /**
   * Auto-seeds the standard Indian MSME Chart of Accounts if none exist for this business.
   * Can be executed within a transaction client.
   */
  public async ensureDefaultAccounts(
    businessId: string,
    tx?: Prisma.TransactionClient,
  ): Promise<Map<string, any>> {
    const client = tx || this.prisma;
    const existing = await client.account.findMany({
      where: { businessId },
    });

    if (existing.length === 0) {
      this.logger.log(`Auto-seeding default Chart of Accounts for business: ${businessId}`);
      for (const spec of DEFAULT_CHART_OF_ACCOUNTS) {
        await client.account.create({
          data: {
            businessId,
            code: spec.code,
            name: spec.name,
            type: spec.type,
            balance: new Prisma.Decimal(0),
          },
        });
      }
      const seeded = await client.account.findMany({ where: { businessId } });
      const map = new Map<string, any>();
      for (const acc of seeded) {
        map.set(acc.code, acc);
      }
      return map;
    }

    const map = new Map<string, any>();
    for (const acc of existing) {
      map.set(acc.code, acc);
    }
    return map;
  }

  /**
   * Retrieve all accounts in the Chart of Accounts for a business.
   */
  public async getAccounts(businessId: string) {
    await this.ensureDefaultAccounts(businessId);
    const accounts = await this.prisma.account.findMany({
      where: { businessId },
      orderBy: { code: 'asc' },
    });

    return {
      statusCode: 200,
      message: 'Chart of Accounts retrieved successfully',
      data: accounts,
    };
  }

  /**
   * Create a custom account and optionally post an opening balance entry.
   */
  public async createAccount(
    businessId: string,
    dto: CreateAccountDto,
    userId?: string,
  ) {
    await this.ensureDefaultAccounts(businessId);

    const existing = await this.prisma.account.findFirst({
      where: { businessId, code: dto.code },
    });
    if (existing) {
      throw new ConflictException(`Account with code ${dto.code} already exists for this business`);
    }

    const openingBalance = dto.openingBalance ? new Prisma.Decimal(dto.openingBalance) : new Prisma.Decimal(0);

    return this.prisma.$transaction(async (tx) => {
      const account = await tx.account.create({
        data: {
          businessId,
          code: dto.code,
          name: dto.name,
          type: dto.type,
          balance: openingBalance,
        },
      });

      // If opening balance > 0, post balanced opening journal entry against Opening Balance Equity (3200)
      if (!openingBalance.isZero()) {
        const openingEquity = await tx.account.findFirst({
          where: { businessId, code: '3200' },
        });

        if (openingEquity) {
          const entryNumber = await this.sequenceService.getNextNumber(
            businessId,
            'JOURNAL',
            'JRN',
            new Date(),
            tx,
          );

          const isDebitNormal = dto.type === AccountType.ASSET || dto.type === AccountType.EXPENSE;
          const journal = await tx.journalEntry.create({
            data: {
              businessId,
              entryNumber,
              date: new Date(),
              narration: `Opening balance for ${dto.name} (${dto.code})`,
              referenceType: 'OPENING_BALANCE',
              referenceId: account.id,
            },
          });

          await tx.ledgerEntry.createMany({
            data: [
              {
                businessId,
                journalEntryId: journal.id,
                accountId: account.id,
                debit: isDebitNormal ? openingBalance : new Prisma.Decimal(0),
                credit: isDebitNormal ? new Prisma.Decimal(0) : openingBalance,
              },
              {
                businessId,
                journalEntryId: journal.id,
                accountId: openingEquity.id,
                debit: isDebitNormal ? new Prisma.Decimal(0) : openingBalance,
                credit: isDebitNormal ? openingBalance : new Prisma.Decimal(0),
              },
            ],
          });

          // Update opening equity balance
          await tx.account.update({
            where: { businessId_id: { businessId, id: openingEquity.id } },
            data: {
              balance: isDebitNormal
                ? { increment: openingBalance }
                : { decrement: openingBalance },
            },
          });
        }
      }

      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'ACCOUNT_CREATED',
          entityName: 'Account',
          entityId: account.id,
          newValues: { code: account.code, name: account.name, type: account.type },
        },
      });

      return {
        statusCode: 201,
        message: 'Account created successfully',
        data: account,
      };
    });
  }

  /**
   * Record a manual journal entry with double-entry validation.
   * Total debits must equal total credits.
   */
  public async createJournalEntry(
    businessId: string,
    dto: CreateJournalEntryDto,
    userId?: string,
  ) {
    if (!dto.entries || dto.entries.length < 2) {
      throw new BadRequestException('A journal entry must contain at least 2 ledger entries');
    }

    let totalDebit = new Prisma.Decimal(0);
    let totalCredit = new Prisma.Decimal(0);

    for (const item of dto.entries) {
      const d = item.debit ? new Prisma.Decimal(item.debit) : new Prisma.Decimal(0);
      const c = item.credit ? new Prisma.Decimal(item.credit) : new Prisma.Decimal(0);

      if (d.isNegative() || c.isNegative()) {
        throw new BadRequestException('Debit and credit amounts cannot be negative');
      }
      if (d.isZero() && c.isZero()) {
        throw new BadRequestException('Each ledger line must have a non-zero debit or credit amount');
      }
      if (!d.isZero() && !c.isZero()) {
        throw new BadRequestException('A single ledger line cannot have both debit and credit amounts');
      }

      totalDebit = totalDebit.plus(d);
      totalCredit = totalCredit.plus(c);
    }

    if (!totalDebit.equals(totalCredit)) {
      throw new BadRequestException(
        `Journal entry is unbalanced: Total Debits (${totalDebit.toFixed(2)}) != Total Credits (${totalCredit.toFixed(2)})`,
      );
    }

    if (totalDebit.isZero()) {
      throw new BadRequestException('Journal entry amounts must be greater than zero');
    }

    const accountIds = Array.from(new Set(dto.entries.map((e) => e.accountId)));
    const accounts = await this.prisma.account.findMany({
      where: { businessId, id: { in: accountIds } },
    });

    if (accounts.length !== accountIds.length) {
      throw new NotFoundException('One or more referenced accounts do not exist in this business');
    }

    const accountMap = new Map<string, any>();
    for (const acc of accounts) {
      accountMap.set(acc.id, acc);
    }

    const entryDate = dto.date ? new Date(dto.date) : new Date();

    return this.prisma.$transaction(async (tx) => {
      const entryNumber = await this.sequenceService.getNextNumber(
        businessId,
        'JOURNAL',
        'JRN',
        entryDate,
        tx,
      );

      const journal = await tx.journalEntry.create({
        data: {
          businessId,
          entryNumber,
          date: entryDate,
          narration: dto.narration,
          referenceType: dto.referenceType || 'MANUAL',
          referenceId: dto.referenceId || null,
        },
      });

      const ledgerCreates: Prisma.LedgerEntryCreateManyInput[] = [];

      for (const item of dto.entries) {
        const d = item.debit ? new Prisma.Decimal(item.debit) : new Prisma.Decimal(0);
        const c = item.credit ? new Prisma.Decimal(item.credit) : new Prisma.Decimal(0);
        const acc = accountMap.get(item.accountId);

        ledgerCreates.push({
          businessId,
          journalEntryId: journal.id,
          accountId: item.accountId,
          debit: d,
          credit: c,
        });

        // Update account balance
        // Normal balances: ASSET & EXPENSE are debit-normal (+debit, -credit)
        // LIABILITY, EQUITY, REVENUE are credit-normal (+credit, -debit)
        const isDebitNormal = acc.type === AccountType.ASSET || acc.type === AccountType.EXPENSE;
        const balanceDelta = isDebitNormal ? d.minus(c) : c.minus(d);

        await tx.account.update({
          where: { businessId_id: { businessId, id: item.accountId } },
          data: {
            balance: {
              increment: balanceDelta,
            },
          },
        });
      }

      await tx.ledgerEntry.createMany({
        data: ledgerCreates,
      });

      await tx.auditLog.create({
        data: {
          businessId,
          userId: userId || null,
          action: 'JOURNAL_ENTRY_POSTED',
          entityName: 'JournalEntry',
          entityId: journal.id,
          newValues: {
            entryNumber: journal.entryNumber,
            totalAmount: totalDebit.toString(),
            narration: journal.narration,
            lines: dto.entries.length,
          },
        },
      });

      const fullJournal = await tx.journalEntry.findUnique({
        where: { businessId_id: { businessId, id: journal.id } },
        include: {
          ledgerEntries: {
            include: { account: true },
          },
        },
      });

      return {
        statusCode: 201,
        message: 'Journal entry posted successfully',
        data: fullJournal,
      };
    });
  }

  /**
   * List journal entries with filters and pagination.
   */
  public async getJournalEntries(businessId: string, query: QueryJournalDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const skip = (page - 1) * limit;

    const where: Prisma.JournalEntryWhereInput = { businessId };

    if (query.search) {
      where.OR = [
        { entryNumber: { contains: query.search, mode: 'insensitive' } },
        { narration: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    if (query.referenceType) {
      where.referenceType = query.referenceType;
    }

    if (query.accountId) {
      where.ledgerEntries = {
        some: { accountId: query.accountId },
      };
    }

    if (query.startDate || query.endDate) {
      where.date = {};
      if (query.startDate) where.date.gte = new Date(query.startDate);
      if (query.endDate) where.date.lte = new Date(query.endDate);
    }

    const [total, items] = await Promise.all([
      this.prisma.journalEntry.count({ where }),
      this.prisma.journalEntry.findMany({
        where,
        skip,
        take: limit,
        orderBy: { date: 'desc' },
        include: {
          ledgerEntries: {
            include: {
              account: {
                select: { id: true, code: true, name: true, type: true },
              },
            },
          },
        },
      }),
    ]);

    return {
      statusCode: 200,
      message: 'Journal entries retrieved successfully',
      data: items,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get single journal entry with ledger lines.
   */
  public async getJournalEntryById(businessId: string, id: string) {
    const journal = await this.prisma.journalEntry.findUnique({
      where: { businessId_id: { businessId, id } },
      include: {
        ledgerEntries: {
          include: { account: true },
        },
      },
    });

    if (!journal) {
      throw new NotFoundException('Journal entry not found');
    }

    return {
      statusCode: 200,
      message: 'Journal entry details retrieved',
      data: journal,
    };
  }

  // =========================================================================
  // DOUBLE-ENTRY TRANSACTION POSTING HOOKS (Called inside atomic transactions)
  // =========================================================================

  /**
   * Post double entries for an issued sales invoice.
   * Debit: Accounts Receivable (1100) = totalAmount
   * Credit: Sales Revenue (4000) = subtotal
   * Credit: Output CGST (2100) = cgstAmount (if any)
   * Credit: Output SGST (2110) = sgstAmount (if any)
   * Credit: Output IGST (2120) = igstAmount (if any)
   */
  public async postInvoiceIssuedJournal(
    businessId: string,
    invoice: {
      id: string;
      invoiceNumber: string;
      invoiceDate: Date;
      totalAmount: Prisma.Decimal;
      subtotal: Prisma.Decimal;
      cgstAmount: Prisma.Decimal;
      sgstAmount: Prisma.Decimal;
      igstAmount: Prisma.Decimal;
    },
    tx: Prisma.TransactionClient,
  ) {
    const accountMap = await this.ensureDefaultAccounts(businessId, tx);
    const arAccount = accountMap.get('1100');
    const salesAccount = accountMap.get('4000');
    const cgstAccount = accountMap.get('2100');
    const sgstAccount = accountMap.get('2110');
    const igstAccount = accountMap.get('2120');

    if (!arAccount || !salesAccount) return;

    const entryNumber = await this.sequenceService.getNextNumber(
      businessId,
      'JOURNAL',
      'JRN',
      invoice.invoiceDate,
      tx,
    );

    const journal = await tx.journalEntry.create({
      data: {
        businessId,
        entryNumber,
        date: invoice.invoiceDate,
        narration: `Sales Invoice ${invoice.invoiceNumber}`,
        referenceType: 'INVOICE',
        referenceId: invoice.id,
      },
    });

    const lines: Prisma.LedgerEntryCreateManyInput[] = [
      {
        businessId,
        journalEntryId: journal.id,
        accountId: arAccount.id,
        debit: invoice.totalAmount,
        credit: new Prisma.Decimal(0),
      },
      {
        businessId,
        journalEntryId: journal.id,
        accountId: salesAccount.id,
        debit: new Prisma.Decimal(0),
        credit: invoice.subtotal,
      },
    ];

    if (!invoice.cgstAmount.isZero() && cgstAccount) {
      lines.push({
        businessId,
        journalEntryId: journal.id,
        accountId: cgstAccount.id,
        debit: new Prisma.Decimal(0),
        credit: invoice.cgstAmount,
      });
    }

    if (!invoice.sgstAmount.isZero() && sgstAccount) {
      lines.push({
        businessId,
        journalEntryId: journal.id,
        accountId: sgstAccount.id,
        debit: new Prisma.Decimal(0),
        credit: invoice.sgstAmount,
      });
    }

    if (!invoice.igstAmount.isZero() && igstAccount) {
      lines.push({
        businessId,
        journalEntryId: journal.id,
        accountId: igstAccount.id,
        debit: new Prisma.Decimal(0),
        credit: invoice.igstAmount,
      });
    }

    await tx.ledgerEntry.createMany({ data: lines });

    // Update account balances
    await tx.account.update({
      where: { businessId_id: { businessId, id: arAccount.id } },
      data: { balance: { increment: invoice.totalAmount } },
    });
    await tx.account.update({
      where: { businessId_id: { businessId, id: salesAccount.id } },
      data: { balance: { increment: invoice.subtotal } },
    });
    if (!invoice.cgstAmount.isZero() && cgstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: cgstAccount.id } },
        data: { balance: { increment: invoice.cgstAmount } },
      });
    }
    if (!invoice.sgstAmount.isZero() && sgstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: sgstAccount.id } },
        data: { balance: { increment: invoice.sgstAmount } },
      });
    }
    if (!invoice.igstAmount.isZero() && igstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: igstAccount.id } },
        data: { balance: { increment: invoice.igstAmount } },
      });
    }
  }

  /**
   * Post reversal double entries for a cancelled sales invoice.
   */
  public async postInvoiceCancelledJournal(
    businessId: string,
    invoice: {
      id: string;
      invoiceNumber: string;
      totalAmount: Prisma.Decimal;
      subtotal: Prisma.Decimal;
      cgstAmount: Prisma.Decimal;
      sgstAmount: Prisma.Decimal;
      igstAmount: Prisma.Decimal;
    },
    tx: Prisma.TransactionClient,
  ) {
    const accountMap = await this.ensureDefaultAccounts(businessId, tx);
    const arAccount = accountMap.get('1100');
    const salesAccount = accountMap.get('4000');
    const cgstAccount = accountMap.get('2100');
    const sgstAccount = accountMap.get('2110');
    const igstAccount = accountMap.get('2120');

    if (!arAccount || !salesAccount) return;

    const entryNumber = await this.sequenceService.getNextNumber(
      businessId,
      'JOURNAL',
      'JRN',
      new Date(),
      tx,
    );

    const journal = await tx.journalEntry.create({
      data: {
        businessId,
        entryNumber,
        date: new Date(),
        narration: `Cancellation / Reversal of Invoice ${invoice.invoiceNumber}`,
        referenceType: 'INVOICE_CANCELLED',
        referenceId: invoice.id,
      },
    });

    const lines: Prisma.LedgerEntryCreateManyInput[] = [
      {
        businessId,
        journalEntryId: journal.id,
        accountId: arAccount.id,
        debit: new Prisma.Decimal(0),
        credit: invoice.totalAmount,
      },
      {
        businessId,
        journalEntryId: journal.id,
        accountId: salesAccount.id,
        debit: invoice.subtotal,
        credit: new Prisma.Decimal(0),
      },
    ];

    if (!invoice.cgstAmount.isZero() && cgstAccount) {
      lines.push({
        businessId,
        journalEntryId: journal.id,
        accountId: cgstAccount.id,
        debit: invoice.cgstAmount,
        credit: new Prisma.Decimal(0),
      });
    }

    if (!invoice.sgstAmount.isZero() && sgstAccount) {
      lines.push({
        businessId,
        journalEntryId: journal.id,
        accountId: sgstAccount.id,
        debit: invoice.sgstAmount,
        credit: new Prisma.Decimal(0),
      });
    }

    if (!invoice.igstAmount.isZero() && igstAccount) {
      lines.push({
        businessId,
        journalEntryId: journal.id,
        accountId: igstAccount.id,
        debit: invoice.igstAmount,
        credit: new Prisma.Decimal(0),
      });
    }

    await tx.ledgerEntry.createMany({ data: lines });

    // Reverse balances
    await tx.account.update({
      where: { businessId_id: { businessId, id: arAccount.id } },
      data: { balance: { decrement: invoice.totalAmount } },
    });
    await tx.account.update({
      where: { businessId_id: { businessId, id: salesAccount.id } },
      data: { balance: { decrement: invoice.subtotal } },
    });
    if (!invoice.cgstAmount.isZero() && cgstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: cgstAccount.id } },
        data: { balance: { decrement: invoice.cgstAmount } },
      });
    }
    if (!invoice.sgstAmount.isZero() && sgstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: sgstAccount.id } },
        data: { balance: { decrement: invoice.sgstAmount } },
      });
    }
    if (!invoice.igstAmount.isZero() && igstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: igstAccount.id } },
        data: { balance: { decrement: invoice.igstAmount } },
      });
    }
  }

  /**
   * Post double entries for a confirmed/received purchase bill.
   * Debit: Merchandise Inventory (1200) = subtotal
   * Debit: Input CGST (1300) = cgst (if any)
   * Debit: Input SGST (1310) = sgst (if any)
   * Credit: Accounts Payable (2000) = totalAmount
   */
  public async postPurchaseReceivedJournal(
    businessId: string,
    purchase: {
      id: string;
      billNumber: string;
      billDate?: Date;
      totalAmount: Prisma.Decimal;
      subtotal: Prisma.Decimal;
      taxAmount: Prisma.Decimal;
    },
    tx: Prisma.TransactionClient,
  ) {
    const accountMap = await this.ensureDefaultAccounts(businessId, tx);
    const apAccount = accountMap.get('2000');
    const invAccount = accountMap.get('1200');
    const cgstAccount = accountMap.get('1300');
    const sgstAccount = accountMap.get('1310');

    if (!apAccount || !invAccount) return;

    const entryNumber = await this.sequenceService.getNextNumber(
      businessId,
      'JOURNAL',
      'JRN',
      purchase.billDate || new Date(),
      tx,
    );

    const journal = await tx.journalEntry.create({
      data: {
        businessId,
        entryNumber,
        date: purchase.billDate || new Date(),
        narration: `Purchase Bill ${purchase.billNumber}`,
        referenceType: 'PURCHASE',
        referenceId: purchase.id,
      },
    });

    const halfTax = purchase.taxAmount.div(2);
    const lines: Prisma.LedgerEntryCreateManyInput[] = [
      {
        businessId,
        journalEntryId: journal.id,
        accountId: invAccount.id,
        debit: purchase.subtotal,
        credit: new Prisma.Decimal(0),
      },
    ];

    if (!purchase.taxAmount.isZero() && cgstAccount && sgstAccount) {
      lines.push(
        {
          businessId,
          journalEntryId: journal.id,
          accountId: cgstAccount.id,
          debit: halfTax,
          credit: new Prisma.Decimal(0),
        },
        {
          businessId,
          journalEntryId: journal.id,
          accountId: sgstAccount.id,
          debit: halfTax,
          credit: new Prisma.Decimal(0),
        },
      );
    }

    lines.push({
      businessId,
      journalEntryId: journal.id,
      accountId: apAccount.id,
      debit: new Prisma.Decimal(0),
      credit: purchase.totalAmount,
    });

    await tx.ledgerEntry.createMany({ data: lines });

    // Update balances
    await tx.account.update({
      where: { businessId_id: { businessId, id: invAccount.id } },
      data: { balance: { increment: purchase.subtotal } },
    });
    if (!purchase.taxAmount.isZero() && cgstAccount && sgstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: cgstAccount.id } },
        data: { balance: { increment: halfTax } },
      });
      await tx.account.update({
        where: { businessId_id: { businessId, id: sgstAccount.id } },
        data: { balance: { increment: halfTax } },
      });
    }
    await tx.account.update({
      where: { businessId_id: { businessId, id: apAccount.id } },
      data: { balance: { increment: purchase.totalAmount } },
    });
  }

  /**
   * Post reversal double entries for a cancelled purchase bill.
   */
  public async postPurchaseCancelledJournal(
    businessId: string,
    purchase: {
      id: string;
      billNumber: string;
      totalAmount: Prisma.Decimal;
      subtotal: Prisma.Decimal;
      taxAmount: Prisma.Decimal;
    },
    tx: Prisma.TransactionClient,
  ) {
    const accountMap = await this.ensureDefaultAccounts(businessId, tx);
    const apAccount = accountMap.get('2000');
    const invAccount = accountMap.get('1200');
    const cgstAccount = accountMap.get('1300');
    const sgstAccount = accountMap.get('1310');

    if (!apAccount || !invAccount) return;

    const entryNumber = await this.sequenceService.getNextNumber(
      businessId,
      'JOURNAL',
      'JRN',
      new Date(),
      tx,
    );

    const journal = await tx.journalEntry.create({
      data: {
        businessId,
        entryNumber,
        date: new Date(),
        narration: `Cancellation / Reversal of Purchase Bill ${purchase.billNumber}`,
        referenceType: 'PURCHASE_CANCELLED',
        referenceId: purchase.id,
      },
    });

    const halfTax = purchase.taxAmount.div(2);
    const lines: Prisma.LedgerEntryCreateManyInput[] = [
      {
        businessId,
        journalEntryId: journal.id,
        accountId: apAccount.id,
        debit: purchase.totalAmount,
        credit: new Prisma.Decimal(0),
      },
      {
        businessId,
        journalEntryId: journal.id,
        accountId: invAccount.id,
        debit: new Prisma.Decimal(0),
        credit: purchase.subtotal,
      },
    ];

    if (!purchase.taxAmount.isZero() && cgstAccount && sgstAccount) {
      lines.push(
        {
          businessId,
          journalEntryId: journal.id,
          accountId: cgstAccount.id,
          debit: new Prisma.Decimal(0),
          credit: halfTax,
        },
        {
          businessId,
          journalEntryId: journal.id,
          accountId: sgstAccount.id,
          debit: new Prisma.Decimal(0),
          credit: halfTax,
        },
      );
    }

    await tx.ledgerEntry.createMany({ data: lines });

    // Reverse balances
    await tx.account.update({
      where: { businessId_id: { businessId, id: apAccount.id } },
      data: { balance: { decrement: purchase.totalAmount } },
    });
    await tx.account.update({
      where: { businessId_id: { businessId, id: invAccount.id } },
      data: { balance: { decrement: purchase.subtotal } },
    });
    if (!purchase.taxAmount.isZero() && cgstAccount && sgstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: cgstAccount.id } },
        data: { balance: { decrement: halfTax } },
      });
      await tx.account.update({
        where: { businessId_id: { businessId, id: sgstAccount.id } },
        data: { balance: { decrement: halfTax } },
      });
    }
  }

  /**
   * Post customer receipt journal:
   * Debit: Cash (1000) or Bank (1010) = amount
   * Credit: Accounts Receivable (1100) = amount
   */
  public async postReceiptJournal(
    businessId: string,
    payment: {
      id: string;
      paymentNumber: string;
      paymentDate: Date;
      paymentMethod: string;
      amount: Prisma.Decimal;
    },
    tx: Prisma.TransactionClient,
  ) {
    const accountMap = await this.ensureDefaultAccounts(businessId, tx);
    const arAccount = accountMap.get('1100');
    const cashBankCode = payment.paymentMethod === 'CASH' ? '1000' : '1010';
    const cashBankAccount = accountMap.get(cashBankCode);

    if (!arAccount || !cashBankAccount) return;

    const entryNumber = await this.sequenceService.getNextNumber(
      businessId,
      'JOURNAL',
      'JRN',
      payment.paymentDate,
      tx,
    );

    const journal = await tx.journalEntry.create({
      data: {
        businessId,
        entryNumber,
        date: payment.paymentDate,
        narration: `Customer Receipt ${payment.paymentNumber} via ${payment.paymentMethod}`,
        referenceType: 'RECEIPT',
        referenceId: payment.id,
      },
    });

    await tx.ledgerEntry.createMany({
      data: [
        {
          businessId,
          journalEntryId: journal.id,
          accountId: cashBankAccount.id,
          debit: payment.amount,
          credit: new Prisma.Decimal(0),
        },
        {
          businessId,
          journalEntryId: journal.id,
          accountId: arAccount.id,
          debit: new Prisma.Decimal(0),
          credit: payment.amount,
        },
      ],
    });

    await tx.account.update({
      where: { businessId_id: { businessId, id: cashBankAccount.id } },
      data: { balance: { increment: payment.amount } },
    });
    await tx.account.update({
      where: { businessId_id: { businessId, id: arAccount.id } },
      data: { balance: { decrement: payment.amount } },
    });
  }

  /**
   * Post supplier payment disbursement journal:
   * Debit: Accounts Payable (2000) = amount
   * Credit: Cash (1000) or Bank (1010) = amount
   */
  public async postDisbursementJournal(
    businessId: string,
    payment: {
      id: string;
      paymentNumber: string;
      paymentDate: Date;
      paymentMethod: string;
      amount: Prisma.Decimal;
    },
    tx: Prisma.TransactionClient,
  ) {
    const accountMap = await this.ensureDefaultAccounts(businessId, tx);
    const apAccount = accountMap.get('2000');
    const cashBankCode = payment.paymentMethod === 'CASH' ? '1000' : '1010';
    const cashBankAccount = accountMap.get(cashBankCode);

    if (!apAccount || !cashBankAccount) return;

    const entryNumber = await this.sequenceService.getNextNumber(
      businessId,
      'JOURNAL',
      'JRN',
      payment.paymentDate,
      tx,
    );

    const journal = await tx.journalEntry.create({
      data: {
        businessId,
        entryNumber,
        date: payment.paymentDate,
        narration: `Supplier Disbursement ${payment.paymentNumber} via ${payment.paymentMethod}`,
        referenceType: 'PAYMENT',
        referenceId: payment.id,
      },
    });

    await tx.ledgerEntry.createMany({
      data: [
        {
          businessId,
          journalEntryId: journal.id,
          accountId: apAccount.id,
          debit: payment.amount,
          credit: new Prisma.Decimal(0),
        },
        {
          businessId,
          journalEntryId: journal.id,
          accountId: cashBankAccount.id,
          debit: new Prisma.Decimal(0),
          credit: payment.amount,
        },
      ],
    });

    await tx.account.update({
      where: { businessId_id: { businessId, id: apAccount.id } },
      data: { balance: { decrement: payment.amount } },
    });
    await tx.account.update({
      where: { businessId_id: { businessId, id: cashBankAccount.id } },
      data: { balance: { decrement: payment.amount } },
    });
  }

  /**
   * Post reversal journal for a voided payment voucher.
   */
  public async postPaymentVoidedJournal(
    businessId: string,
    payment: {
      id: string;
      paymentNumber: string;
      paymentType: string;
      paymentMethod: string;
      amount: Prisma.Decimal;
    },
    tx: Prisma.TransactionClient,
  ) {
    const accountMap = await this.ensureDefaultAccounts(businessId, tx);
    const cashBankCode = payment.paymentMethod === 'CASH' ? '1000' : '1010';
    const cashBankAccount = accountMap.get(cashBankCode);
    const controlAccount = accountMap.get(payment.paymentType === 'CUSTOMER_RECEIPT' ? '1100' : '2000');

    if (!controlAccount || !cashBankAccount) return;

    const entryNumber = await this.sequenceService.getNextNumber(
      businessId,
      'JOURNAL',
      'JRN',
      new Date(),
      tx,
    );

    const journal = await tx.journalEntry.create({
      data: {
        businessId,
        entryNumber,
        date: new Date(),
        narration: `Void Reversal of ${payment.paymentNumber}`,
        referenceType: 'PAYMENT_VOIDED',
        referenceId: payment.id,
      },
    });

    if (payment.paymentType === 'CUSTOMER_RECEIPT') {
      // Reversal: Debit AR (1100), Credit Cash/Bank
      await tx.ledgerEntry.createMany({
        data: [
          {
            businessId,
            journalEntryId: journal.id,
            accountId: controlAccount.id,
            debit: payment.amount,
            credit: new Prisma.Decimal(0),
          },
          {
            businessId,
            journalEntryId: journal.id,
            accountId: cashBankAccount.id,
            debit: new Prisma.Decimal(0),
            credit: payment.amount,
          },
        ],
      });
      await tx.account.update({
        where: { businessId_id: { businessId, id: controlAccount.id } },
        data: { balance: { increment: payment.amount } },
      });
      await tx.account.update({
        where: { businessId_id: { businessId, id: cashBankAccount.id } },
        data: { balance: { decrement: payment.amount } },
      });
    } else {
      // Reversal: Debit Cash/Bank, Credit AP (2000)
      await tx.ledgerEntry.createMany({
        data: [
          {
            businessId,
            journalEntryId: journal.id,
            accountId: cashBankAccount.id,
            debit: payment.amount,
            credit: new Prisma.Decimal(0),
          },
          {
            businessId,
            journalEntryId: journal.id,
            accountId: controlAccount.id,
            debit: new Prisma.Decimal(0),
            credit: payment.amount,
          },
        ],
      });
      await tx.account.update({
        where: { businessId_id: { businessId, id: cashBankAccount.id } },
        data: { balance: { increment: payment.amount } },
      });
      await tx.account.update({
        where: { businessId_id: { businessId, id: controlAccount.id } },
        data: { balance: { increment: payment.amount } },
      });
    }
  }

  /**
   * Post double entries for an incurred business expense.
   * Debit: General Expense (5100) = amount - gstAmount
   * Debit: Input CGST (1300) = gstAmount / 2 (if any)
   * Debit: Input SGST (1310) = gstAmount / 2 (if any)
   * Credit: Cash (1000) or Bank (1010) = amount
   */
  public async postExpenseJournal(
    businessId: string,
    expense: {
      id: string;
      expenseNumber: string;
      date?: Date;
      expenseDate?: Date;
      paymentMethod: string;
      amount: Prisma.Decimal;
      gstAmount: Prisma.Decimal;
      vendor?: string | null;
      vendorName?: string | null;
    },
    tx: Prisma.TransactionClient,
  ) {
    const expDate = expense.date || expense.expenseDate || new Date();
    const vendorLabel = expense.vendor || expense.vendorName;
    const accountMap = await this.ensureDefaultAccounts(businessId, tx);
    const expAccount = accountMap.get('5100');
    const cashBankCode = expense.paymentMethod === 'CASH' ? '1000' : '1010';
    const cashBankAccount = accountMap.get(cashBankCode);
    const cgstAccount = accountMap.get('1300');
    const sgstAccount = accountMap.get('1310');

    if (!expAccount || !cashBankAccount) return;

    const entryNumber = await this.sequenceService.getNextNumber(
      businessId,
      'JOURNAL',
      'JRN',
      expDate,
      tx,
    );

    const journal = await tx.journalEntry.create({
      data: {
        businessId,
        entryNumber,
        date: expDate,
        narration: `Expense ${expense.expenseNumber}${expense.vendorName ? ` (${expense.vendorName})` : ''}`,
        referenceType: 'EXPENSE',
        referenceId: expense.id,
      },
    });

    const netAmount = expense.amount.minus(expense.gstAmount);
    const halfGst = expense.gstAmount.div(2);

    const lines: Prisma.LedgerEntryCreateManyInput[] = [
      {
        businessId,
        journalEntryId: journal.id,
        accountId: expAccount.id,
        debit: netAmount,
        credit: new Prisma.Decimal(0),
      },
    ];

    if (!expense.gstAmount.isZero() && cgstAccount && sgstAccount) {
      lines.push(
        {
          businessId,
          journalEntryId: journal.id,
          accountId: cgstAccount.id,
          debit: halfGst,
          credit: new Prisma.Decimal(0),
        },
        {
          businessId,
          journalEntryId: journal.id,
          accountId: sgstAccount.id,
          debit: halfGst,
          credit: new Prisma.Decimal(0),
        },
      );
    }

    lines.push({
      businessId,
      journalEntryId: journal.id,
      accountId: cashBankAccount.id,
      debit: new Prisma.Decimal(0),
      credit: expense.amount,
    });

    await tx.ledgerEntry.createMany({ data: lines });

    // Update balances
    await tx.account.update({
      where: { businessId_id: { businessId, id: expAccount.id } },
      data: { balance: { increment: netAmount } },
    });
    if (!expense.gstAmount.isZero() && cgstAccount && sgstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: cgstAccount.id } },
        data: { balance: { increment: halfGst } },
      });
      await tx.account.update({
        where: { businessId_id: { businessId, id: sgstAccount.id } },
        data: { balance: { increment: halfGst } },
      });
    }
    await tx.account.update({
      where: { businessId_id: { businessId, id: cashBankAccount.id } },
      data: { balance: { decrement: expense.amount } },
    });
  }

  /**
   * Post reversal double entries for a deleted expense.
   */
  public async postExpenseDeletedJournal(
    businessId: string,
    expense: {
      id: string;
      expenseNumber: string;
      paymentMethod: string;
      amount: Prisma.Decimal;
      gstAmount: Prisma.Decimal;
    },
    tx: Prisma.TransactionClient,
  ) {
    const accountMap = await this.ensureDefaultAccounts(businessId, tx);
    const expAccount = accountMap.get('5100');
    const cashBankCode = expense.paymentMethod === 'CASH' ? '1000' : '1010';
    const cashBankAccount = accountMap.get(cashBankCode);
    const cgstAccount = accountMap.get('1300');
    const sgstAccount = accountMap.get('1310');

    if (!expAccount || !cashBankAccount) return;

    const entryNumber = await this.sequenceService.getNextNumber(
      businessId,
      'JOURNAL',
      'JRN',
      new Date(),
      tx,
    );

    const journal = await tx.journalEntry.create({
      data: {
        businessId,
        entryNumber,
        date: new Date(),
        narration: `Deletion Reversal of Expense ${expense.expenseNumber}`,
        referenceType: 'EXPENSE_DELETED',
        referenceId: expense.id,
      },
    });

    const netAmount = expense.amount.minus(expense.gstAmount);
    const halfGst = expense.gstAmount.div(2);

    const lines: Prisma.LedgerEntryCreateManyInput[] = [
      {
        businessId,
        journalEntryId: journal.id,
        accountId: cashBankAccount.id,
        debit: expense.amount,
        credit: new Prisma.Decimal(0),
      },
      {
        businessId,
        journalEntryId: journal.id,
        accountId: expAccount.id,
        debit: new Prisma.Decimal(0),
        credit: netAmount,
      },
    ];

    if (!expense.gstAmount.isZero() && cgstAccount && sgstAccount) {
      lines.push(
        {
          businessId,
          journalEntryId: journal.id,
          accountId: cgstAccount.id,
          debit: new Prisma.Decimal(0),
          credit: halfGst,
        },
        {
          businessId,
          journalEntryId: journal.id,
          accountId: sgstAccount.id,
          debit: new Prisma.Decimal(0),
          credit: halfGst,
        },
      );
    }

    await tx.ledgerEntry.createMany({ data: lines });

    // Reverse balances
    await tx.account.update({
      where: { businessId_id: { businessId, id: cashBankAccount.id } },
      data: { balance: { increment: expense.amount } },
    });
    await tx.account.update({
      where: { businessId_id: { businessId, id: expAccount.id } },
      data: { balance: { decrement: netAmount } },
    });
    if (!expense.gstAmount.isZero() && cgstAccount && sgstAccount) {
      await tx.account.update({
        where: { businessId_id: { businessId, id: cgstAccount.id } },
        data: { balance: { decrement: halfGst } },
      });
      await tx.account.update({
        where: { businessId_id: { businessId, id: sgstAccount.id } },
        data: { balance: { decrement: halfGst } },
      });
    }
  }

  // =========================================================================
  // FINANCIAL REPORTING (Trial Balance, Profit & Loss, Sub-ledgers)
  // =========================================================================

  /**
   * Generate Trial Balance.
   * Confirms: Total Debits == Total Credits.
   */
  public async getTrialBalance(businessId: string, asOfDate?: Date) {
    await this.ensureDefaultAccounts(businessId);

    const accounts = await this.prisma.account.findMany({
      where: { businessId },
      orderBy: { code: 'asc' },
    });

    const dateFilter: Prisma.DateTimeFilter | undefined = asOfDate ? { lte: asOfDate } : undefined;

    const items: Array<{
      accountId: string;
      code: string;
      name: string;
      type: AccountType;
      debit: number;
      credit: number;
    }> = [];

    let totalDebitSum = new Prisma.Decimal(0);
    let totalCreditSum = new Prisma.Decimal(0);

    for (const acc of accounts) {
      const movements = await this.prisma.ledgerEntry.aggregate({
        where: {
          businessId,
          accountId: acc.id,
          ...(dateFilter ? { journalEntry: { date: dateFilter } } : {}),
        },
        _sum: {
          debit: true,
          credit: true,
        },
      });

      const totalDebits = movements._sum.debit || new Prisma.Decimal(0);
      const totalCredits = movements._sum.credit || new Prisma.Decimal(0);

      // Normal balance classification
      const isDebitNormal = acc.type === AccountType.ASSET || acc.type === AccountType.EXPENSE;
      let netDebit = new Prisma.Decimal(0);
      let netCredit = new Prisma.Decimal(0);

      if (isDebitNormal) {
        const net = totalDebits.minus(totalCredits);
        if (net.greaterThanOrEqualTo(0)) {
          netDebit = net;
        } else {
          netCredit = net.abs();
        }
      } else {
        const net = totalCredits.minus(totalDebits);
        if (net.greaterThanOrEqualTo(0)) {
          netCredit = net;
        } else {
          netDebit = net.abs();
        }
      }

      totalDebitSum = totalDebitSum.plus(netDebit);
      totalCreditSum = totalCreditSum.plus(netCredit);

      items.push({
        accountId: acc.id,
        code: acc.code,
        name: acc.name,
        type: acc.type,
        debit: netDebit.toNumber(),
        credit: netCredit.toNumber(),
      });
    }

    const difference = totalDebitSum.minus(totalCreditSum).abs();
    const isBalanced = difference.lessThan(0.01);

    return {
      statusCode: 200,
      message: 'Trial balance calculated successfully',
      data: {
        asOfDate: (asOfDate || new Date()).toISOString(),
        isBalanced,
        totalDebits: totalDebitSum.toNumber(),
        totalCredits: totalCreditSum.toNumber(),
        difference: difference.toNumber(),
        items,
      },
    };
  }

  /**
   * Generate Profit & Loss statement for a period.
   * Revenue - COGS = Gross Profit
   * Gross Profit - Operating Expenses = Net Profit
   */
  public async getProfitAndLoss(
    businessId: string,
    startDate?: Date,
    endDate?: Date,
  ) {
    await this.ensureDefaultAccounts(businessId);

    const dateFilter: Prisma.DateTimeFilter | undefined = (startDate || endDate)
      ? {
          ...(startDate ? { gte: startDate } : {}),
          ...(endDate ? { lte: endDate } : {}),
        }
      : undefined;

    // 1. Operating Revenue (REVENUE accounts, e.g. 4000, 4100)
    const revenueAccounts = await this.prisma.account.findMany({
      where: { businessId, type: AccountType.REVENUE },
      orderBy: { code: 'asc' },
    });

    const revenueLines: Array<{ code: string; name: string; amount: number }> = [];
    let totalRevenue = new Prisma.Decimal(0);

    for (const acc of revenueAccounts) {
      const agg = await this.prisma.ledgerEntry.aggregate({
        where: {
          businessId,
          accountId: acc.id,
          ...(dateFilter ? { journalEntry: { date: dateFilter } } : {}),
        },
        _sum: { credit: true, debit: true },
      });
      const net = (agg._sum.credit || new Prisma.Decimal(0)).minus(agg._sum.debit || new Prisma.Decimal(0));
      totalRevenue = totalRevenue.plus(net);
      revenueLines.push({
        code: acc.code,
        name: acc.name,
        amount: net.toNumber(),
      });
    }

    // 2. Cost of Goods Sold (COGS: Account 5000)
    const cogsAccount = await this.prisma.account.findFirst({
      where: { businessId, code: '5000' },
    });
    let cogsAmount = new Prisma.Decimal(0);
    if (cogsAccount) {
      const agg = await this.prisma.ledgerEntry.aggregate({
        where: {
          businessId,
          accountId: cogsAccount.id,
          ...(dateFilter ? { journalEntry: { date: dateFilter } } : {}),
        },
        _sum: { debit: true, credit: true },
      });
      cogsAmount = (agg._sum.debit || new Prisma.Decimal(0)).minus(agg._sum.credit || new Prisma.Decimal(0));
    }

    const grossProfit = totalRevenue.minus(cogsAmount);

    // 3. Operating Expenses (EXPENSE accounts excluding COGS 5000)
    const expenseAccounts = await this.prisma.account.findMany({
      where: {
        businessId,
        type: AccountType.EXPENSE,
        code: { not: '5000' },
      },
      orderBy: { code: 'asc' },
    });

    const expenseLines: Array<{ code: string; name: string; amount: number }> = [];
    let totalOperatingExpenses = new Prisma.Decimal(0);

    for (const acc of expenseAccounts) {
      const agg = await this.prisma.ledgerEntry.aggregate({
        where: {
          businessId,
          accountId: acc.id,
          ...(dateFilter ? { journalEntry: { date: dateFilter } } : {}),
        },
        _sum: { debit: true, credit: true },
      });
      const net = (agg._sum.debit || new Prisma.Decimal(0)).minus(agg._sum.credit || new Prisma.Decimal(0));
      totalOperatingExpenses = totalOperatingExpenses.plus(net);
      expenseLines.push({
        code: acc.code,
        name: acc.name,
        amount: net.toNumber(),
      });
    }

    const netProfit = grossProfit.minus(totalOperatingExpenses);

    return {
      statusCode: 200,
      message: 'Profit and Loss statement generated successfully',
      data: {
        startDate: startDate ? startDate.toISOString() : null,
        endDate: endDate ? endDate.toISOString() : null,
        totalRevenue: totalRevenue.toNumber(),
        costOfGoodsSold: cogsAmount.toNumber(),
        grossProfit: grossProfit.toNumber(),
        totalOperatingExpenses: totalOperatingExpenses.toNumber(),
        netProfit: netProfit.toNumber(),
        revenueBreakdown: revenueLines,
        expenseBreakdown: expenseLines,
      },
    };
  }

  /**
   * Reconciles Accounts Receivable sub-ledger (Customer balances) with General Ledger control account 1100.
   */
  public async getCustomerReceivablesReport(businessId: string) {
    const [customers, arAccount] = await Promise.all([
      this.prisma.customer.findMany({
        where: { businessId },
        select: { id: true, name: true, phone: true, currentBalance: true },
        orderBy: { name: 'asc' },
      }),
      this.prisma.account.findFirst({
        where: { businessId, code: '1100' },
      }),
    ]);

    let totalReceivables = new Prisma.Decimal(0);
    for (const c of customers) {
      totalReceivables = totalReceivables.plus(c.currentBalance);
    }

    const controlBalance = arAccount ? arAccount.balance : new Prisma.Decimal(0);
    const discrepancy = totalReceivables.minus(controlBalance).abs();

    return {
      statusCode: 200,
      message: 'Customer receivables sub-ledger retrieved',
      data: {
        totalReceivables: totalReceivables.toNumber(),
        generalLedgerControlBalance: controlBalance.toNumber(),
        isReconciled: discrepancy.lessThan(0.01),
        discrepancy: discrepancy.toNumber(),
        customers: customers.map((c) => ({
          id: c.id,
          name: c.name,
          phone: c.phone,
          currentBalance: Number(c.currentBalance),
        })),
      },
    };
  }

  /**
   * Reconciles Accounts Payable sub-ledger (Supplier balances) with General Ledger control account 2000.
   */
  public async getSupplierPayablesReport(businessId: string) {
    const [suppliers, apAccount] = await Promise.all([
      this.prisma.supplier.findMany({
        where: { businessId },
        select: { id: true, name: true, phone: true, currentBalance: true },
        orderBy: { name: 'asc' },
      }),
      this.prisma.account.findFirst({
        where: { businessId, code: '2000' },
      }),
    ]);

    let totalPayables = new Prisma.Decimal(0);
    for (const s of suppliers) {
      totalPayables = totalPayables.plus(s.currentBalance);
    }

    const controlBalance = apAccount ? apAccount.balance : new Prisma.Decimal(0);
    const discrepancy = totalPayables.minus(controlBalance).abs();

    return {
      statusCode: 200,
      message: 'Supplier payables sub-ledger retrieved',
      data: {
        totalPayables: totalPayables.toNumber(),
        generalLedgerControlBalance: controlBalance.toNumber(),
        isReconciled: discrepancy.lessThan(0.01),
        discrepancy: discrepancy.toNumber(),
        suppliers: suppliers.map((s) => ({
          id: s.id,
          name: s.name,
          phone: s.phone,
          currentBalance: Number(s.currentBalance),
        })),
      },
    };
  }
}
