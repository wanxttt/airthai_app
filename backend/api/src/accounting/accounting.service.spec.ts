import { Test, TestingModule } from '@nestjs/testing';
import { AccountingService, DEFAULT_CHART_OF_ACCOUNTS } from './accounting.service';
import { PrismaService } from '../database/prisma.service';
import { SequenceService } from '../sales/sequence.service';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { AccountType, Prisma } from '@prisma/client';

describe('AccountingService', () => {
  let service: AccountingService;
  let prisma: any;
  let sequenceService: any;

  const mockBusinessId = 'biz_test_accounting_001';
  const mockUserId = 'usr_test_accountant_001';

  beforeEach(async () => {
    prisma = {
      account: {
        findMany: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      journalEntry: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        count: jest.fn(),
      },
      ledgerEntry: {
        createMany: jest.fn(),
        aggregate: jest.fn(),
      },
      customer: {
        findMany: jest.fn(),
      },
      supplier: {
        findMany: jest.fn(),
      },
      auditLog: {
        create: jest.fn(),
      },
      $transaction: jest.fn((cb) => cb(prisma)),
    };

    sequenceService = {
      getNextNumber: jest.fn().mockResolvedValue('JRN-2026-27-0001'),
      getFiscalYear: jest.fn().mockReturnValue('2026-27'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AccountingService,
        { provide: PrismaService, useValue: prisma },
        { provide: SequenceService, useValue: sequenceService },
      ],
    }).compile();

    service = module.get<AccountingService>(AccountingService);
  });

  describe('ensureDefaultAccounts', () => {
    it('should auto-seed standard Indian Chart of Accounts when business has no accounts', async () => {
      prisma.account.findMany
        .mockResolvedValueOnce([]) // First check empty
        .mockResolvedValueOnce(
          DEFAULT_CHART_OF_ACCOUNTS.map((a, idx) => ({
            id: `acc_${idx}`,
            businessId: mockBusinessId,
            code: a.code,
            name: a.name,
            type: a.type,
            balance: new Prisma.Decimal(0),
          })),
        );

      prisma.account.create.mockImplementation((args: any) => ({
        id: `acc_${args.data.code}`,
        ...args.data,
      }));

      const map = await service.ensureDefaultAccounts(mockBusinessId);

      expect(prisma.account.create).toHaveBeenCalledTimes(DEFAULT_CHART_OF_ACCOUNTS.length);
      expect(map.has('1000')).toBe(true); // Cash
      expect(map.has('1100')).toBe(true); // AR
      expect(map.has('2000')).toBe(true); // AP
      expect(map.has('4000')).toBe(true); // Sales
      expect(map.has('5000')).toBe(true); // COGS
    });

    it('should return existing accounts map without re-seeding if already initialized', async () => {
      const existing = [
        { id: 'acc_1000', businessId: mockBusinessId, code: '1000', name: 'Cash', type: AccountType.ASSET, balance: new Prisma.Decimal(5000) },
      ];
      prisma.account.findMany.mockResolvedValue(existing);

      const map = await service.ensureDefaultAccounts(mockBusinessId);

      expect(prisma.account.create).not.toHaveBeenCalled();
      expect(map.size).toBe(1);
      expect(map.get('1000').name).toBe('Cash');
    });
  });

  describe('createJournalEntry (Double-Entry Balancing)', () => {
    it('should reject a journal entry with fewer than 2 lines', async () => {
      await expect(
        service.createJournalEntry(mockBusinessId, {
          narration: 'Single entry attempt',
          entries: [{ accountId: 'acc_1', debit: 1000 }],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject an unbalanced journal entry where debits != credits', async () => {
      await expect(
        service.createJournalEntry(mockBusinessId, {
          narration: 'Unbalanced journal',
          entries: [
            { accountId: 'acc_1', debit: 1000 },
            { accountId: 'acc_2', credit: 800 },
          ],
        }),
      ).rejects.toThrow(/is unbalanced/);
    });

    it('should reject negative amounts on ledger lines', async () => {
      await expect(
        service.createJournalEntry(mockBusinessId, {
          narration: 'Negative line',
          entries: [
            { accountId: 'acc_1', debit: -500 },
            { accountId: 'acc_2', credit: -500 },
          ],
        }),
      ).rejects.toThrow(/cannot be negative/);
    });

    it('should reject zero amount journal entries', async () => {
      await expect(
        service.createJournalEntry(mockBusinessId, {
          narration: 'Zero amount journal',
          entries: [
            { accountId: 'acc_1', debit: 0 },
            { accountId: 'acc_2', credit: 0 },
          ],
        }),
      ).rejects.toThrow(/non-zero debit or credit amount|greater than zero/);
    });

    it('should successfully post a balanced journal entry and update account balances atomically', async () => {
      const accounts = [
        { id: 'acc_1', businessId: mockBusinessId, code: '1000', name: 'Cash', type: AccountType.ASSET, balance: new Prisma.Decimal(5000) },
        { id: 'acc_2', businessId: mockBusinessId, code: '4000', name: 'Sales Revenue', type: AccountType.REVENUE, balance: new Prisma.Decimal(10000) },
      ];
      prisma.account.findMany.mockResolvedValue(accounts);

      const createdJournal = {
        id: 'jrn_001',
        businessId: mockBusinessId,
        entryNumber: 'JRN-2026-27-0001',
        date: new Date(),
        narration: 'Cash sale received directly',
      };
      prisma.journalEntry.create.mockResolvedValue(createdJournal);
      prisma.ledgerEntry.createMany.mockResolvedValue({ count: 2 });
      prisma.account.update.mockResolvedValue({});
      prisma.journalEntry.findUnique.mockResolvedValue({
        ...createdJournal,
        ledgerEntries: [
          { id: 'le_1', accountId: 'acc_1', debit: 2500, credit: 0 },
          { id: 'le_2', accountId: 'acc_2', debit: 0, credit: 2500 },
        ],
      });

      const res = await service.createJournalEntry(
        mockBusinessId,
        {
          narration: 'Cash sale received directly',
          entries: [
            { accountId: 'acc_1', debit: 2500 },
            { accountId: 'acc_2', credit: 2500 },
          ],
        },
        mockUserId,
      );

      expect(res.statusCode).toBe(201);
      expect(prisma.journalEntry.create).toHaveBeenCalled();
      expect(prisma.ledgerEntry.createMany).toHaveBeenCalledWith({
        data: expect.arrayContaining([
          expect.objectContaining({ accountId: 'acc_1', debit: new Prisma.Decimal(2500) }),
          expect.objectContaining({ accountId: 'acc_2', credit: new Prisma.Decimal(2500) }),
        ]),
      });
      // Asset balance incremented by debit
      expect(prisma.account.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { businessId_id: { businessId: mockBusinessId, id: 'acc_1' } },
          data: { balance: { increment: new Prisma.Decimal(2500) } },
        }),
      );
      // Revenue balance incremented by credit
      expect(prisma.account.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { businessId_id: { businessId: mockBusinessId, id: 'acc_2' } },
          data: { balance: { increment: new Prisma.Decimal(2500) } },
        }),
      );
    });
  });

  describe('Operational Transaction Posting Hooks (Double-Entry Verification)', () => {
    it('postInvoiceIssuedJournal: debits AR and credits Sales Revenue & Output Taxes with balanced debits and credits', async () => {
      const coa = [
        { id: 'acc_ar', code: '1100', type: AccountType.ASSET },
        { id: 'acc_sales', code: '4000', type: AccountType.REVENUE },
        { id: 'acc_cgst', code: '2100', type: AccountType.LIABILITY },
        { id: 'acc_sgst', code: '2110', type: AccountType.LIABILITY },
      ];
      prisma.account.findMany.mockResolvedValue(coa);
      prisma.journalEntry.create.mockResolvedValue({ id: 'jrn_inv_1' });

      const invoice = {
        id: 'inv_101',
        invoiceNumber: 'INV-2026-27-0001',
        invoiceDate: new Date(),
        totalAmount: new Prisma.Decimal('11800.00'),
        subtotal: new Prisma.Decimal('10000.00'),
        cgstAmount: new Prisma.Decimal('900.00'),
        sgstAmount: new Prisma.Decimal('900.00'),
        igstAmount: new Prisma.Decimal('0.00'),
      };

      await service.postInvoiceIssuedJournal(mockBusinessId, invoice, prisma);

      expect(prisma.journalEntry.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          referenceType: 'INVOICE',
          referenceId: 'inv_101',
        }),
      });

      expect(prisma.ledgerEntry.createMany).toHaveBeenCalledWith({
        data: [
          expect.objectContaining({ accountId: 'acc_ar', debit: new Prisma.Decimal('11800.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_sales', debit: new Prisma.Decimal(0), credit: new Prisma.Decimal('10000.00') }),
          expect.objectContaining({ accountId: 'acc_cgst', debit: new Prisma.Decimal(0), credit: new Prisma.Decimal('900.00') }),
          expect.objectContaining({ accountId: 'acc_sgst', debit: new Prisma.Decimal(0), credit: new Prisma.Decimal('900.00') }),
        ],
      });
    });

    it('postInvoiceCancelledJournal: posts exact inverse double-entry reversal', async () => {
      const coa = [
        { id: 'acc_ar', code: '1100', type: AccountType.ASSET },
        { id: 'acc_sales', code: '4000', type: AccountType.REVENUE },
        { id: 'acc_cgst', code: '2100', type: AccountType.LIABILITY },
        { id: 'acc_sgst', code: '2110', type: AccountType.LIABILITY },
      ];
      prisma.account.findMany.mockResolvedValue(coa);
      prisma.journalEntry.create.mockResolvedValue({ id: 'jrn_inv_rev' });

      const invoice = {
        id: 'inv_101',
        invoiceNumber: 'INV-2026-27-0001',
        totalAmount: new Prisma.Decimal('11800.00'),
        subtotal: new Prisma.Decimal('10000.00'),
        cgstAmount: new Prisma.Decimal('900.00'),
        sgstAmount: new Prisma.Decimal('900.00'),
        igstAmount: new Prisma.Decimal('0.00'),
      };

      await service.postInvoiceCancelledJournal(mockBusinessId, invoice, prisma);

      expect(prisma.ledgerEntry.createMany).toHaveBeenCalledWith({
        data: [
          expect.objectContaining({ accountId: 'acc_ar', debit: new Prisma.Decimal(0), credit: new Prisma.Decimal('11800.00') }),
          expect.objectContaining({ accountId: 'acc_sales', debit: new Prisma.Decimal('10000.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_cgst', debit: new Prisma.Decimal('900.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_sgst', debit: new Prisma.Decimal('900.00'), credit: new Prisma.Decimal(0) }),
        ],
      });
    });

    it('postPurchaseReceivedJournal: debits Inventory & Input Tax, credits Accounts Payable', async () => {
      const coa = [
        { id: 'acc_ap', code: '2000', type: AccountType.LIABILITY },
        { id: 'acc_inv', code: '1200', type: AccountType.ASSET },
        { id: 'acc_cgst_in', code: '1300', type: AccountType.ASSET },
        { id: 'acc_sgst_in', code: '1310', type: AccountType.ASSET },
      ];
      prisma.account.findMany.mockResolvedValue(coa);
      prisma.journalEntry.create.mockResolvedValue({ id: 'jrn_purch_1' });

      const purchase = {
        id: 'purch_201',
        billNumber: 'BILL-2026-001',
        totalAmount: new Prisma.Decimal('59000.00'),
        subtotal: new Prisma.Decimal('50000.00'),
        taxAmount: new Prisma.Decimal('9000.00'),
      };

      await service.postPurchaseReceivedJournal(mockBusinessId, purchase, prisma);

      expect(prisma.ledgerEntry.createMany).toHaveBeenCalledWith({
        data: [
          expect.objectContaining({ accountId: 'acc_inv', debit: new Prisma.Decimal('50000.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_cgst_in', debit: new Prisma.Decimal('4500.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_sgst_in', debit: new Prisma.Decimal('4500.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_ap', debit: new Prisma.Decimal(0), credit: new Prisma.Decimal('59000.00') }),
        ],
      });
    });

    it('postReceiptJournal: debits Cash/Bank and credits Accounts Receivable', async () => {
      const coa = [
        { id: 'acc_bank', code: '1010', type: AccountType.ASSET },
        { id: 'acc_ar', code: '1100', type: AccountType.ASSET },
      ];
      prisma.account.findMany.mockResolvedValue(coa);
      prisma.journalEntry.create.mockResolvedValue({ id: 'jrn_rcp_1' });

      const payment = {
        id: 'pay_301',
        paymentNumber: 'RCP-2026-27-0001',
        paymentDate: new Date(),
        paymentMethod: 'UPI',
        amount: new Prisma.Decimal('15000.00'),
      };

      await service.postReceiptJournal(mockBusinessId, payment, prisma);

      expect(prisma.ledgerEntry.createMany).toHaveBeenCalledWith({
        data: [
          expect.objectContaining({ accountId: 'acc_bank', debit: new Prisma.Decimal('15000.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_ar', debit: new Prisma.Decimal(0), credit: new Prisma.Decimal('15000.00') }),
        ],
      });
    });

    it('postExpenseJournal: debits General Expense and Input Taxes, credits Cash/Bank', async () => {
      const coa = [
        { id: 'acc_exp', code: '5100', type: AccountType.EXPENSE },
        { id: 'acc_cgst_in', code: '1300', type: AccountType.ASSET },
        { id: 'acc_sgst_in', code: '1310', type: AccountType.ASSET },
        { id: 'acc_cash', code: '1000', type: AccountType.ASSET },
      ];
      prisma.account.findMany.mockResolvedValue(coa);
      prisma.journalEntry.create.mockResolvedValue({ id: 'jrn_exp_1' });

      const expense = {
        id: 'exp_401',
        expenseNumber: 'EXP-2026-27-0001',
        expenseDate: new Date(),
        paymentMethod: 'CASH',
        amount: new Prisma.Decimal('4720.00'),
        gstAmount: new Prisma.Decimal('720.00'),
      };

      await service.postExpenseJournal(mockBusinessId, expense, prisma);

      expect(prisma.ledgerEntry.createMany).toHaveBeenCalledWith({
        data: [
          expect.objectContaining({ accountId: 'acc_exp', debit: new Prisma.Decimal('4000.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_cgst_in', debit: new Prisma.Decimal('360.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_sgst_in', debit: new Prisma.Decimal('360.00'), credit: new Prisma.Decimal(0) }),
          expect.objectContaining({ accountId: 'acc_cash', debit: new Prisma.Decimal(0), credit: new Prisma.Decimal('4720.00') }),
        ],
      });
    });
  });

  describe('Financial Reports (Trial Balance & Profit & Loss)', () => {
    it('getTrialBalance: verifies balancing (Total Debits == Total Credits)', async () => {
      const accounts = [
        { id: 'acc_cash', code: '1000', name: 'Cash', type: AccountType.ASSET },
        { id: 'acc_sales', code: '4000', name: 'Sales', type: AccountType.REVENUE },
      ];
      prisma.account.findMany.mockResolvedValue(accounts);

      prisma.ledgerEntry.aggregate
        .mockResolvedValueOnce({ _sum: { debit: new Prisma.Decimal('5000.00'), credit: new Prisma.Decimal(0) } })
        .mockResolvedValueOnce({ _sum: { debit: new Prisma.Decimal(0), credit: new Prisma.Decimal('5000.00') } });

      const res = await service.getTrialBalance(mockBusinessId);

      expect(res.statusCode).toBe(200);
      expect(res.data.isBalanced).toBe(true);
      expect(res.data.totalDebits).toBe(5000);
      expect(res.data.totalCredits).toBe(5000);
      expect(res.data.difference).toBe(0);
    });

    it('getProfitAndLoss: calculates Gross Profit and Net Profit correctly', async () => {
      prisma.account.findMany.mockImplementation((args: any) => {
        if (args?.where?.type === AccountType.REVENUE) {
          return [{ id: 'acc_rev', code: '4000', name: 'Sales Revenue', type: AccountType.REVENUE }];
        }
        if (args?.where?.type === AccountType.EXPENSE) {
          return [{ id: 'acc_rent', code: '5200', name: 'Rent', type: AccountType.EXPENSE }];
        }
        return [{ id: 'acc_1000', code: '1000' }]; // Default accounts check
      });

      // COGS account (5000)
      prisma.account.findFirst.mockResolvedValue({
        id: 'acc_cogs',
        code: '5000',
        name: 'COGS',
        type: AccountType.EXPENSE,
      });

      prisma.ledgerEntry.aggregate
        // Revenue aggregate: credit 100000
        .mockResolvedValueOnce({ _sum: { credit: new Prisma.Decimal('100000.00'), debit: new Prisma.Decimal(0) } })
        // COGS aggregate: debit 60000
        .mockResolvedValueOnce({ _sum: { debit: new Prisma.Decimal('60000.00'), credit: new Prisma.Decimal(0) } })
        // Rent aggregate: debit 15000
        .mockResolvedValueOnce({ _sum: { debit: new Prisma.Decimal('15000.00'), credit: new Prisma.Decimal(0) } });

      const res = await service.getProfitAndLoss(mockBusinessId);

      expect(res.statusCode).toBe(200);
      expect(res.data.totalRevenue).toBe(100000);
      expect(res.data.costOfGoodsSold).toBe(60000);
      expect(res.data.grossProfit).toBe(40000);
      expect(res.data.totalOperatingExpenses).toBe(15000);
      expect(res.data.netProfit).toBe(25000); // 40000 - 15000
    });
  });

  describe('Receivables & Payables Sub-Ledger Reconciliation', () => {
    it('getCustomerReceivablesReport: compares customer total balances against Control Account 1100', async () => {
      prisma.customer.findMany.mockResolvedValue([
        { id: 'c1', name: 'Alpha Traders', phone: '9876543210', currentBalance: new Prisma.Decimal('25000.00') },
        { id: 'c2', name: 'Beta Retailers', phone: '9876543211', currentBalance: new Prisma.Decimal('15000.00') },
      ]);
      prisma.account.findFirst.mockResolvedValue({
        id: 'acc_ar',
        code: '1100',
        balance: new Prisma.Decimal('40000.00'),
      });

      const res = await service.getCustomerReceivablesReport(mockBusinessId);

      expect(res.statusCode).toBe(200);
      expect(res.data.totalReceivables).toBe(40000);
      expect(res.data.generalLedgerControlBalance).toBe(40000);
      expect(res.data.isReconciled).toBe(true);
      expect(res.data.discrepancy).toBe(0);
    });
  });
});
