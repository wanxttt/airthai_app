import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/service_result.dart';
import '../security/session_manager.dart';
import '../../features/accounting/models/account_model.dart';
import '../../features/accounting/models/journal_model.dart';
import '../../features/accounting/models/financial_report_models.dart';
import '../../features/accounting/models/gst_report_models.dart';

class AccountingService {
  AccountingService._();
  static final AccountingService instance = AccountingService._();

  int _nextJournalSeq = 4;

  // Pre-seeded Chart of Accounts for DevMock mode
  final List<AccountModel> _mockAccounts = [
    AccountModel(id: 'acc_1000', code: '1000', name: 'Cash on Hand', type: AccountType.asset, balance: 25000.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_1010', code: '1010', name: 'Bank Account (Current/Savings)', type: AccountType.asset, balance: 145000.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_1100', code: '1100', name: 'Accounts Receivable (Debtors Control)', type: AccountType.asset, balance: 45000.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_1200', code: '1200', name: 'Merchandise Inventory', type: AccountType.asset, balance: 85000.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_1300', code: '1300', name: 'Input CGST', type: AccountType.asset, balance: 5400.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_1310', code: '1310', name: 'Input SGST', type: AccountType.asset, balance: 5400.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_1320', code: '1320', name: 'Input IGST', type: AccountType.asset, balance: 0.0, createdAt: DateTime(2026, 4, 1)),

    AccountModel(id: 'acc_2000', code: '2000', name: 'Accounts Payable (Creditors Control)', type: AccountType.liability, balance: 35000.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_2100', code: '2100', name: 'Output CGST', type: AccountType.liability, balance: 5400.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_2110', code: '2110', name: 'Output SGST', type: AccountType.liability, balance: 5400.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_2120', code: '2120', name: 'Output IGST', type: AccountType.liability, balance: 0.0, createdAt: DateTime(2026, 4, 1)),

    AccountModel(id: 'acc_3000', code: '3000', name: "Owner's Capital", type: AccountType.equity, balance: 200000.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_3100', code: '3100', name: 'Retained Earnings', type: AccountType.equity, balance: 43400.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_3200', code: '3200', name: 'Opening Balance Equity', type: AccountType.equity, balance: 0.0, createdAt: DateTime(2026, 4, 1)),

    AccountModel(id: 'acc_4000', code: '4000', name: 'Sales Revenue', type: AccountType.revenue, balance: 90000.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_4100', code: '4100', name: 'Other Operating Income', type: AccountType.revenue, balance: 2500.0, createdAt: DateTime(2026, 4, 1)),

    AccountModel(id: 'acc_5000', code: '5000', name: 'Cost of Goods Sold (COGS)', type: AccountType.expense, balance: 42000.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_5100', code: '5100', name: 'General & Administrative Expenses', type: AccountType.expense, balance: 7500.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_5200', code: '5200', name: 'Rent & Facilities', type: AccountType.expense, balance: 18000.0, createdAt: DateTime(2026, 4, 1)),
    AccountModel(id: 'acc_5300', code: '5300', name: 'Logistics & Freight Outward', type: AccountType.expense, balance: 3400.0, createdAt: DateTime(2026, 4, 1)),
  ];

  // Pre-seeded Journal Entries for DevMock mode
  final List<JournalEntryModel> _mockJournals = [
    JournalEntryModel(
      id: 'jrn_mock_001',
      entryNumber: 'JRN-2026-27-0001',
      date: DateTime.now().subtract(const Duration(days: 5)),
      narration: 'Owner initial capital introduction into business bank account',
      referenceType: 'CAPITAL_INTRODUCTION',
      entries: [
        LedgerEntryModel(
          id: 'le_001',
          accountId: 'acc_1010',
          accountCode: '1010',
          accountName: 'Bank Account (Current/Savings)',
          accountType: AccountType.asset,
          debit: 200000.0,
          credit: 0.0,
        ),
        LedgerEntryModel(
          id: 'le_002',
          accountId: 'acc_3000',
          accountCode: '3000',
          accountName: "Owner's Capital",
          accountType: AccountType.equity,
          debit: 0.0,
          credit: 200000.0,
        ),
      ],
    ),
    JournalEntryModel(
      id: 'jrn_mock_002',
      entryNumber: 'JRN-2026-27-0002',
      date: DateTime.now().subtract(const Duration(days: 3)),
      narration: 'Sales Invoice INV-2026-27-0001 to Shree Ganesh Hardware',
      referenceType: 'INVOICE',
      referenceId: 'inv_001',
      entries: [
        LedgerEntryModel(
          id: 'le_003',
          accountId: 'acc_1100',
          accountCode: '1100',
          accountName: 'Accounts Receivable (Debtors Control)',
          accountType: AccountType.asset,
          debit: 59000.0,
          credit: 0.0,
        ),
        LedgerEntryModel(
          id: 'le_004',
          accountId: 'acc_4000',
          accountCode: '4000',
          accountName: 'Sales Revenue',
          accountType: AccountType.revenue,
          debit: 0.0,
          credit: 50000.0,
        ),
        LedgerEntryModel(
          id: 'le_005',
          accountId: 'acc_2100',
          accountCode: '2100',
          accountName: 'Output CGST',
          accountType: AccountType.liability,
          debit: 0.0,
          credit: 4500.0,
        ),
        LedgerEntryModel(
          id: 'le_006',
          accountId: 'acc_2110',
          accountCode: '2110',
          accountName: 'Output SGST',
          accountType: AccountType.liability,
          debit: 0.0,
          credit: 4500.0,
        ),
      ],
    ),
    JournalEntryModel(
      id: 'jrn_mock_003',
      entryNumber: 'JRN-2026-27-0003',
      date: DateTime.now().subtract(const Duration(days: 2)),
      narration: 'Customer Receipt REC-2026-27-0001 from Shree Ganesh Hardware via UPI',
      referenceType: 'RECEIPT',
      referenceId: 'pay_001',
      entries: [
        LedgerEntryModel(
          id: 'le_007',
          accountId: 'acc_1010',
          accountCode: '1010',
          accountName: 'Bank Account (Current/Savings)',
          accountType: AccountType.asset,
          debit: 5000.0,
          credit: 0.0,
        ),
        LedgerEntryModel(
          id: 'le_008',
          accountId: 'acc_1100',
          accountCode: '1100',
          accountName: 'Accounts Receivable (Debtors Control)',
          accountType: AccountType.asset,
          debit: 0.0,
          credit: 5000.0,
        ),
      ],
    ),
  ];

  /// Get Chart of Accounts
  Future<ServiceResult<List<AccountModel>>> getAccounts() async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(List.from(_mockAccounts));
    }

    try {
      final res = await ApiClient.instance.get(ApiConstants.accountingAccounts);
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data!['data'] as List? ?? [])
            .map((e) => AccountModel.fromJson(e))
            .toList();
        return ServiceResult.success(list);
      }
      return ServiceResult.failure(res.data?['message'] ?? 'Failed to load accounts');
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  /// Create Account
  Future<ServiceResult<AccountModel>> createAccount({
    required String code,
    required String name,
    required AccountType type,
    double? openingBalance,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      if (_mockAccounts.any((a) => a.code == code)) {
        return ServiceResult.failure('Account with code $code already exists.');
      }
      final newAcc = AccountModel(
        id: 'acc_mock_${DateTime.now().millisecondsSinceEpoch}',
        code: code,
        name: name,
        type: type,
        balance: openingBalance ?? 0.0,
        createdAt: DateTime.now(),
      );
      _mockAccounts.add(newAcc);

      // Offset Opening Balance Equity (3200) to keep Double-Entry ledger balanced
      if (openingBalance != null && openingBalance > 0) {
        final eqIdx = _mockAccounts.indexWhere((a) => a.code == '3200');
        if (eqIdx != -1) {
          final eq = _mockAccounts[eqIdx];
          _mockAccounts[eqIdx] = AccountModel(
            id: eq.id,
            code: eq.code,
            name: eq.name,
            type: eq.type,
            balance: eq.balance + (type.isDebitNormal ? openingBalance : -openingBalance),
            createdAt: eq.createdAt,
          );
        }
      }

      return ServiceResult.success(newAcc);
    }

    try {
      final res = await ApiClient.instance.post(
        ApiConstants.accountingAccounts,
        body: {
          'code': code,
          'name': name,
          'type': type.toServerString(),
          if (openingBalance != null && openingBalance > 0)
            'openingBalance': openingBalance,
        },
      );
      if ((res.statusCode == 200 || res.statusCode == 201) && res.data != null) {
        return ServiceResult.success(AccountModel.fromJson(res.data!['data']));
      }
      return ServiceResult.failure(res.data?['message'] ?? 'Failed to create account');
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  /// Get Journal Entries
  Future<ServiceResult<List<JournalEntryModel>>> getJournalEntries({
    String? search,
    String? accountId,
    String? startDate,
    String? endDate,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      var filtered = List<JournalEntryModel>.from(_mockJournals);
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        filtered = filtered.where((j) =>
            j.entryNumber.toLowerCase().contains(q) ||
            j.narration.toLowerCase().contains(q)).toList();
      }
      return ServiceResult.success(filtered);
    }

    try {
      final queryParams = <String, String>{};
      if (search != null) queryParams['search'] = search;
      if (accountId != null) queryParams['accountId'] = accountId;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final res = await ApiClient.instance.get(
        ApiConstants.accountingJournals,
        queryParams: queryParams,
      );
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data!['data'] as List? ?? [])
            .map((e) => JournalEntryModel.fromJson(e))
            .toList();
        return ServiceResult.success(list);
      }
      return ServiceResult.failure(res.data?['message'] ?? 'Failed to load journals');
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  /// Record Manual Journal Entry (Double-Entry Balanced)
  Future<ServiceResult<JournalEntryModel>> createJournalEntry({
    required String narration,
    DateTime? date,
    required List<Map<String, dynamic>> entries,
  }) async {
    if (entries.length < 2) {
      return ServiceResult.failure('A journal entry must contain at least 2 ledger lines.');
    }

    double totalDebit = 0.0;
    double totalCredit = 0.0;
    for (final e in entries) {
      final d = (e['debit'] as num?)?.toDouble() ?? 0.0;
      final c = (e['credit'] as num?)?.toDouble() ?? 0.0;
      totalDebit += d;
      totalCredit += c;
    }

    if ((totalDebit - totalCredit).abs() >= 0.01) {
      return ServiceResult.failure(
        'Journal entry is unbalanced: Total Debits (₹${totalDebit.toStringAsFixed(2)}) != Total Credits (₹${totalCredit.toStringAsFixed(2)})',
      );
    }

    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      final entryNumber = 'JRN-2026-27-000${_nextJournalSeq++}';
      final journalId = 'jrn_mock_${DateTime.now().millisecondsSinceEpoch}';

      final ledgerLines = entries.map((raw) {
        final acc = _mockAccounts.firstWhere(
          (a) => a.id == raw['accountId'],
          orElse: () => _mockAccounts.first,
        );
        final d = (raw['debit'] as num?)?.toDouble() ?? 0.0;
        final c = (raw['credit'] as num?)?.toDouble() ?? 0.0;

        return LedgerEntryModel(
          id: 'le_${DateTime.now().microsecondsSinceEpoch}',
          accountId: acc.id,
          accountCode: acc.code,
          accountName: acc.name,
          accountType: acc.type,
          debit: d,
          credit: c,
        );
      }).toList();

      final newJournal = JournalEntryModel(
        id: journalId,
        entryNumber: entryNumber,
        date: date ?? DateTime.now(),
        narration: narration,
        referenceType: 'MANUAL',
        entries: ledgerLines,
      );

      _mockJournals.insert(0, newJournal);
      return ServiceResult.success(newJournal);
    }

    try {
      final res = await ApiClient.instance.post(
        ApiConstants.accountingJournals,
        body: {
          'narration': narration,
          'date': (date ?? DateTime.now()).toIso8601String(),
          'entries': entries,
        },
      );
      if ((res.statusCode == 200 || res.statusCode == 201) && res.data != null) {
        return ServiceResult.success(JournalEntryModel.fromJson(res.data!['data']));
      }
      return ServiceResult.failure(res.data?['message'] ?? 'Failed to post journal entry');
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  /// Get Trial Balance
  Future<ServiceResult<TrialBalanceModel>> getTrialBalance({DateTime? asOfDate}) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      final items = _mockAccounts.map((a) {
        final isDebit = a.type.isDebitNormal;
        return TrialBalanceItemModel(
          accountId: a.id,
          code: a.code,
          name: a.name,
          type: a.type,
          debit: isDebit ? a.balance : 0.0,
          credit: !isDebit ? a.balance : 0.0,
        );
      }).toList();

      final totalDebits = items.fold(0.0, (sum, i) => sum + i.debit);
      final totalCredits = items.fold(0.0, (sum, i) => sum + i.credit);
      final diff = (totalDebits - totalCredits).abs();

      return ServiceResult.success(TrialBalanceModel(
        asOfDate: asOfDate ?? DateTime.now(),
        isBalanced: diff < 0.01,
        totalDebits: totalDebits,
        totalCredits: totalCredits,
        difference: diff,
        items: items,
      ));
    }

    try {
      final queryParams = <String, String>{};
      if (asOfDate != null) queryParams['asOfDate'] = asOfDate.toIso8601String();

      final res = await ApiClient.instance.get(
        ApiConstants.accountingTrialBalance,
        queryParams: queryParams,
      );
      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(TrialBalanceModel.fromJson(res.data!['data']));
      }
      return ServiceResult.failure(res.data?['message'] ?? 'Failed to load trial balance');
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  /// Get Profit & Loss
  Future<ServiceResult<ProfitLossModel>> getProfitLoss({DateTime? startDate, DateTime? endDate}) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(ProfitLossModel(
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
        totalRevenue: 92500.0,
        costOfGoodsSold: 42000.0,
        grossProfit: 50500.0,
        totalOperatingExpenses: 28900.0,
        netProfit: 21600.0,
        revenueBreakdown: [
          ReportLineItem(code: '4000', name: 'Sales Revenue', amount: 90000.0),
          ReportLineItem(code: '4100', name: 'Other Operating Income', amount: 2500.0),
        ],
        expenseBreakdown: [
          ReportLineItem(code: '5100', name: 'General & Administrative Expenses', amount: 7500.0),
          ReportLineItem(code: '5200', name: 'Rent & Facilities', amount: 18000.0),
          ReportLineItem(code: '5300', name: 'Logistics & Freight Outward', amount: 3400.0),
        ],
      ));
    }

    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final res = await ApiClient.instance.get(
        ApiConstants.accountingProfitLoss,
        queryParams: queryParams,
      );
      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(ProfitLossModel.fromJson(res.data!['data']));
      }
      return ServiceResult.failure(res.data?['message'] ?? 'Failed to load Profit & Loss');
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  /// Get GSTR-1 Summary
  Future<ServiceResult<Gstr1Model>> getGstr1({String? returnPeriod}) async {
    final period = returnPeriod ?? '2026-10';
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(Gstr1Model(
        returnPeriod: period,
        totalTaxableValue: 75000.0,
        totalCgst: 6750.0,
        totalSgst: 6750.0,
        totalIgst: 0.0,
        totalCess: 0.0,
        totalTaxLiability: 13500.0,
        table4B2bCount: 2,
        table4B2bTaxable: 50000.0,
        table4B2bTax: 9000.0,
        b2bInvoices: [
          Gstr1B2bInvoice(
            invoiceNumber: 'INV-2026-27-0001',
            invoiceDate: DateTime(2026, 10, 15),
            customerName: 'Shree Ganesh Hardware',
            customerGstin: '27AABCU9603R1ZM',
            placeOfSupply: '27-Maharashtra',
            taxableValue: 30000.0,
            cgstAmount: 2700.0,
            sgstAmount: 2700.0,
            igstAmount: 0.0,
            totalTax: 5400.0,
            totalInvoiceAmount: 35400.0,
          ),
          Gstr1B2bInvoice(
            invoiceNumber: 'INV-2026-27-0002',
            invoiceDate: DateTime(2026, 10, 20),
            customerName: 'Om Sai Electricals',
            customerGstin: '27AAAPL1234C1Z0',
            placeOfSupply: '27-Maharashtra',
            taxableValue: 20000.0,
            cgstAmount: 1800.0,
            sgstAmount: 1800.0,
            igstAmount: 0.0,
            totalTax: 3600.0,
            totalInvoiceAmount: 23600.0,
          ),
        ],
        table7B2cCount: 3,
        table7B2cTaxable: 25000.0,
        table7B2cTax: 4500.0,
        hsnSummary: [
          HsnSummaryItem(
            hsnCode: '8471',
            description: 'Computers & Peripheral Hardware',
            quantity: 15.0,
            taxableValue: 50000.0,
            cgstAmount: 4500.0,
            sgstAmount: 4500.0,
            igstAmount: 0.0,
            totalTax: 9000.0,
          ),
          HsnSummaryItem(
            hsnCode: '8504',
            description: 'Electrical Power Adapters & Transformers',
            quantity: 50.0,
            taxableValue: 25000.0,
            cgstAmount: 2250.0,
            sgstAmount: 2250.0,
            igstAmount: 0.0,
            totalTax: 4500.0,
          ),
        ],
        disclaimer:
            'Preparation summary generated from AirthAI financial records. '
            'Direct filing must be executed on the GST Common Portal.',
      ));
    }

    try {
      final res = await ApiClient.instance.get(
        ApiConstants.gstGstr1,
        queryParams: {'returnPeriod': period},
      );
      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(Gstr1Model.fromJson(
          res.data!['data'],
          res.data!['disclaimer'] ?? 'Statutory preparation summary only.',
        ));
      }
      return ServiceResult.failure(res.data?['message'] ?? 'Failed to load GSTR-1');
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  /// Get GSTR-3B Summary
  Future<ServiceResult<Gstr3bModel>> getGstr3b({String? returnPeriod}) async {
    final period = returnPeriod ?? '2026-10';
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(Gstr3bModel(
        returnPeriod: period,
        outwardTaxable: 75000.0,
        outwardIgst: 0.0,
        outwardCgst: 6750.0,
        outwardSgst: 6750.0,
        totalOutwardTax: 13500.0,
        itcTaxable: 45000.0,
        itcIgst: 0.0,
        itcCgst: 4050.0,
        itcSgst: 4050.0,
        totalItcAvailable: 8100.0,
        netPayableIgst: 0.0,
        netPayableCgst: 2700.0,
        netPayableSgst: 2700.0,
        totalNetPayable: 5400.0,
        disclaimer:
            'Statutory preparation summary for Form GSTR-3B. '
            'Final return filing must be done on the official GSTN portal.',
      ));
    }

    try {
      final res = await ApiClient.instance.get(
        ApiConstants.gstGstr3b,
        queryParams: {'returnPeriod': period},
      );
      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(Gstr3bModel.fromJson(
          res.data!['data'],
          res.data!['disclaimer'] ?? 'Statutory preparation summary only.',
        ));
      }
      return ServiceResult.failure(res.data?['message'] ?? 'Failed to load GSTR-3B');
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  /// Resets in-memory mock data for isolated test executions.
  void resetDevMock() {
    _mockAccounts.clear();
    _mockAccounts.addAll([
      AccountModel(id: 'acc_1000', code: '1000', name: 'Cash on Hand', type: AccountType.asset, balance: 25000.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_1010', code: '1010', name: 'Bank Account (Current/Savings)', type: AccountType.asset, balance: 145000.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_1100', code: '1100', name: 'Accounts Receivable (Debtors Control)', type: AccountType.asset, balance: 45000.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_1200', code: '1200', name: 'Merchandise Inventory', type: AccountType.asset, balance: 85000.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_1300', code: '1300', name: 'Input CGST', type: AccountType.asset, balance: 5400.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_1310', code: '1310', name: 'Input SGST', type: AccountType.asset, balance: 5400.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_1320', code: '1320', name: 'Input IGST', type: AccountType.asset, balance: 0.0, createdAt: DateTime(2026, 4, 1)),

      AccountModel(id: 'acc_2000', code: '2000', name: 'Accounts Payable (Creditors Control)', type: AccountType.liability, balance: 35000.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_2100', code: '2100', name: 'Output CGST', type: AccountType.liability, balance: 5400.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_2110', code: '2110', name: 'Output SGST', type: AccountType.liability, balance: 5400.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_2120', code: '2120', name: 'Output IGST', type: AccountType.liability, balance: 0.0, createdAt: DateTime(2026, 4, 1)),

      AccountModel(id: 'acc_3000', code: '3000', name: "Owner's Capital", type: AccountType.equity, balance: 200000.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_3100', code: '3100', name: 'Retained Earnings', type: AccountType.equity, balance: 43400.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_3200', code: '3200', name: 'Opening Balance Equity', type: AccountType.equity, balance: 0.0, createdAt: DateTime(2026, 4, 1)),

      AccountModel(id: 'acc_4000', code: '4000', name: 'Sales Revenue', type: AccountType.revenue, balance: 90000.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_4100', code: '4100', name: 'Other Operating Income', type: AccountType.revenue, balance: 2500.0, createdAt: DateTime(2026, 4, 1)),

      AccountModel(id: 'acc_5000', code: '5000', name: 'Cost of Goods Sold (COGS)', type: AccountType.expense, balance: 42000.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_5100', code: '5100', name: 'General & Administrative Expenses', type: AccountType.expense, balance: 7500.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_5200', code: '5200', name: 'Rent & Facilities', type: AccountType.expense, balance: 18000.0, createdAt: DateTime(2026, 4, 1)),
      AccountModel(id: 'acc_5300', code: '5300', name: 'Logistics & Freight Outward', type: AccountType.expense, balance: 3400.0, createdAt: DateTime(2026, 4, 1)),
    ]);
  }
}
