import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/accounting_service.dart';
import 'package:airthai/features/accounting/models/account_model.dart';
import 'package:airthai/features/accounting/models/journal_model.dart';
import 'package:airthai/features/accounting/models/financial_report_models.dart';
import 'package:airthai/features/accounting/models/gst_report_models.dart';
import 'package:airthai/features/accounting/presentation/screens/accounting_screen.dart';

void main() {
  setUp(() {
    SessionManager.instance.setAuthMode(AuthMode.devMock);
    AccountingService.instance.resetDevMock();
  });

  group('Accounting Domain Models', () {
    test('AccountModel parses correctly and maps account classifications', () {
      final json = {
        'id': 'acc_test_1',
        'code': '1000',
        'name': 'Cash on Hand',
        'type': 'ASSET',
        'balance': 15000.0,
        'createdAt': '2026-10-20T00:00:00.000Z',
      };

      final model = AccountModel.fromJson(json);
      expect(model.code, '1000');
      expect(model.name, 'Cash on Hand');
      expect(model.type, AccountType.asset);
      expect(model.type.isDebitNormal, true);
      expect(model.balance, 15000.0);
    });

    test('JournalEntryModel computes totals and validates balancing status', () {
      final balancedJournal = JournalEntryModel(
        id: 'jrn_1',
        entryNumber: 'JRN-2026-27-0001',
        date: DateTime.now(),
        narration: 'Balanced transaction',
        entries: [
          LedgerEntryModel(
            id: 'l1',
            accountId: 'a1',
            accountCode: '1000',
            accountName: 'Cash',
            accountType: AccountType.asset,
            debit: 1000.0,
            credit: 0.0,
          ),
          LedgerEntryModel(
            id: 'l2',
            accountId: 'a2',
            accountCode: '4000',
            accountName: 'Sales',
            accountType: AccountType.revenue,
            debit: 0.0,
            credit: 1000.0,
          ),
        ],
      );

      expect(balancedJournal.totalDebit, 1000.0);
      expect(balancedJournal.totalCredit, 1000.0);
      expect(balancedJournal.isBalanced, true);

      final unbalancedJournal = JournalEntryModel(
        id: 'jrn_2',
        entryNumber: 'JRN-2026-27-0002',
        date: DateTime.now(),
        narration: 'Unbalanced transaction',
        entries: [
          LedgerEntryModel(
            id: 'l3',
            accountId: 'a1',
            accountCode: '1000',
            accountName: 'Cash',
            accountType: AccountType.asset,
            debit: 1000.0,
            credit: 0.0,
          ),
          LedgerEntryModel(
            id: 'l4',
            accountId: 'a2',
            accountCode: '4000',
            accountName: 'Sales',
            accountType: AccountType.revenue,
            debit: 0.0,
            credit: 800.0,
          ),
        ],
      );

      expect(unbalancedJournal.isBalanced, false);
    });

    test('TrialBalanceModel parses and validates balanced condition', () {
      final tb = TrialBalanceModel(
        asOfDate: DateTime.now(),
        isBalanced: true,
        totalDebits: 50000.0,
        totalCredits: 50000.0,
        difference: 0.0,
        items: [
          TrialBalanceItemModel(
            accountId: 'acc_1',
            code: '1000',
            name: 'Cash',
            type: AccountType.asset,
            debit: 50000.0,
            credit: 0.0,
          ),
          TrialBalanceItemModel(
            accountId: 'acc_2',
            code: '3000',
            name: "Owner's Capital",
            type: AccountType.equity,
            debit: 0.0,
            credit: 50000.0,
          ),
        ],
      );

      expect(tb.isBalanced, true);
      expect(tb.totalDebits, tb.totalCredits);
      expect(tb.difference, 0.0);
    });

    test('Gstr1Model & Gstr3bModel retain statutory preparation disclaimers', () {
      final g1 = Gstr1Model(
        returnPeriod: '2026-10',
        totalTaxableValue: 100000.0,
        totalCgst: 9000.0,
        totalSgst: 9000.0,
        totalIgst: 0.0,
        totalCess: 0.0,
        totalTaxLiability: 18000.0,
        table4B2bCount: 1,
        table4B2bTaxable: 100000.0,
        table4B2bTax: 18000.0,
        b2bInvoices: [],
        table7B2cCount: 0,
        table7B2cTaxable: 0.0,
        table7B2cTax: 0.0,
        hsnSummary: [],
        disclaimer: 'Statutory preparation summary. File on official GST portal.',
      );

      expect(g1.disclaimer, contains('GST portal'));
      expect(g1.totalTaxLiability, 18000.0);
    });
  });

  group('AccountingService Unit Operations', () {
    test('getAccounts returns default pre-seeded Chart of Accounts in DevMock mode', () async {
      final res = await AccountingService.instance.getAccounts();
      expect(res.isSuccess, true);
      expect(res.data, isNotEmpty);
      expect(res.data!.any((a) => a.code == '1000'), true); // Cash
      expect(res.data!.any((a) => a.code == '1100'), true); // AR
      expect(res.data!.any((a) => a.code == '2000'), true); // AP
      expect(res.data!.any((a) => a.code == '4000'), true); // Sales
      expect(res.data!.any((a) => a.code == '5000'), true); // COGS
    });

    test('createAccount adds custom account and rejects duplicate code', () async {
      final res = await AccountingService.instance.createAccount(
        code: '1050',
        name: 'Petty Cash - Factory',
        type: AccountType.asset,
        openingBalance: 5000.0,
      );

      expect(res.isSuccess, true);
      expect(res.data!.code, '1050');

      // Duplicate code check
      final dupRes = await AccountingService.instance.createAccount(
        code: '1050',
        name: 'Duplicate Petty Cash',
        type: AccountType.asset,
      );
      expect(dupRes.isSuccess, false);
      expect(dupRes.error, contains('already exists'));
    });

    test('createJournalEntry strictly rejects unbalanced entries', () async {
      final res = await AccountingService.instance.createJournalEntry(
        narration: 'Unbalanced entry attempt',
        entries: [
          {'accountId': 'acc_1000', 'debit': 5000.0, 'credit': 0.0},
          {'accountId': 'acc_4000', 'debit': 0.0, 'credit': 4000.0},
        ],
      );

      expect(res.isSuccess, false);
      expect(res.error, contains('unbalanced'));
    });

    test('createJournalEntry accepts balanced double-entry vouchers', () async {
      final res = await AccountingService.instance.createJournalEntry(
        narration: 'Office computer purchase',
        entries: [
          {'accountId': 'acc_1010', 'debit': 0.0, 'credit': 35000.0},
          {'accountId': 'acc_1200', 'debit': 35000.0, 'credit': 0.0},
        ],
      );

      expect(res.isSuccess, true);
      expect(res.data!.entryNumber, startsWith('JRN-'));
      expect(res.data!.isBalanced, true);
    });

    test('getTrialBalance produces balanced report in DevMock mode', () async {
      final res = await AccountingService.instance.getTrialBalance();
      expect(res.isSuccess, true);
      expect(res.data!.isBalanced, true);
      expect(res.data!.difference, 0.0);
      expect(res.data!.items, isNotEmpty);
    });

    test('getProfitLoss calculates gross profit and net profit', () async {
      final res = await AccountingService.instance.getProfitLoss();
      expect(res.isSuccess, true);
      expect(res.data!.totalRevenue, 92500.0);
      expect(res.data!.costOfGoodsSold, 42000.0);
      expect(res.data!.grossProfit, 50500.0); // 92500 - 42000
      expect(res.data!.totalOperatingExpenses, 28900.0);
      expect(res.data!.netProfit, 21600.0); // 50500 - 28900
    });

    test('getGstr1 and getGstr3b return preparation summaries with statutory disclaimer', () async {
      final res1 = await AccountingService.instance.getGstr1(returnPeriod: '2026-10');
      expect(res1.isSuccess, true);
      expect(res1.data!.returnPeriod, '2026-10');
      expect(res1.data!.disclaimer, isNotEmpty);
      expect(res1.data!.table4B2bCount, greaterThan(0));

      final res3b = await AccountingService.instance.getGstr3b(returnPeriod: '2026-10');
      expect(res3b.isSuccess, true);
      expect(res3b.data!.returnPeriod, '2026-10');
      expect(res3b.data!.disclaimer, isNotEmpty);
      expect(res3b.data!.totalNetPayable, 5400.0);
    });
  });

  group('AccountingScreen Widget UI', () {
    testWidgets('renders all accounting tabs, trial balance, and statutory disclaimer', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AccountingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and action buttons
      expect(find.text('Accounting & GST Engine'), findsOneWidget);
      expect(find.text('Record Journal Entry'), findsOneWidget);
      expect(find.text('+ Account'), findsOneWidget);

      // Check all 5 tabs exist
      expect(find.text('Chart of Accounts'), findsOneWidget);
      expect(find.text('Journal Entries'), findsOneWidget);
      expect(find.text('Trial Balance'), findsOneWidget);
      expect(find.text('Profit & Loss'), findsOneWidget);
      expect(find.text('GST Returns (GSTR-1 & 3B)'), findsOneWidget);

      // Check default tab (Chart of Accounts)
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('Cash on Hand'), findsOneWidget);

      // Switch to Trial Balance tab
      await tester.tap(find.text('Trial Balance'));
      await tester.pumpAndSettle();
      expect(find.text('Double-Entry Ledger is Balanced'), findsOneWidget);

      // Switch to GST Returns tab
      await tester.tap(find.text('GST Returns (GSTR-1 & 3B)'));
      await tester.pumpAndSettle();
      expect(find.text('GST Preparation Summaries'), findsOneWidget);
      expect(find.textContaining('Preparation summary generated from AirthAI'), findsOneWidget);
      expect(find.text('Form GSTR-1: Outward Supplies Summary'), findsOneWidget);
      expect(find.text('Form GSTR-3B: Monthly Return Summary'), findsOneWidget);
    });
  });
}
