import 'account_model.dart';

class TrialBalanceItemModel {
  final String accountId;
  final String code;
  final String name;
  final AccountType type;
  final double debit;
  final double credit;

  TrialBalanceItemModel({
    required this.accountId,
    required this.code,
    required this.name,
    required this.type,
    required this.debit,
    required this.credit,
  });

  factory TrialBalanceItemModel.fromJson(Map<String, dynamic> json) {
    return TrialBalanceItemModel(
      accountId: json['accountId'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      type: AccountType.fromString(json['type'] ?? 'ASSET'),
      debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TrialBalanceModel {
  final DateTime asOfDate;
  final bool isBalanced;
  final double totalDebits;
  final double totalCredits;
  final double difference;
  final List<TrialBalanceItemModel> items;

  TrialBalanceModel({
    required this.asOfDate,
    required this.isBalanced,
    required this.totalDebits,
    required this.totalCredits,
    required this.difference,
    required this.items,
  });

  factory TrialBalanceModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return TrialBalanceModel(
      asOfDate: json['asOfDate'] != null
          ? DateTime.tryParse(json['asOfDate']) ?? DateTime.now()
          : DateTime.now(),
      isBalanced: json['isBalanced'] ?? false,
      totalDebits: (json['totalDebits'] as num?)?.toDouble() ?? 0.0,
      totalCredits: (json['totalCredits'] as num?)?.toDouble() ?? 0.0,
      difference: (json['difference'] as num?)?.toDouble() ?? 0.0,
      items: rawItems.map((e) => TrialBalanceItemModel.fromJson(e)).toList(),
    );
  }
}

class ReportLineItem {
  final String code;
  final String name;
  final double amount;

  ReportLineItem({
    required this.code,
    required this.name,
    required this.amount,
  });

  factory ReportLineItem.fromJson(Map<String, dynamic> json) {
    return ReportLineItem(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProfitLossModel {
  final String? startDate;
  final String? endDate;
  final double totalRevenue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double totalOperatingExpenses;
  final double netProfit;
  final List<ReportLineItem> revenueBreakdown;
  final List<ReportLineItem> expenseBreakdown;

  ProfitLossModel({
    this.startDate,
    this.endDate,
    required this.totalRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.totalOperatingExpenses,
    required this.netProfit,
    required this.revenueBreakdown,
    required this.expenseBreakdown,
  });

  factory ProfitLossModel.fromJson(Map<String, dynamic> json) {
    final rev = json['revenueBreakdown'] as List? ?? [];
    final exp = json['expenseBreakdown'] as List? ?? [];
    return ProfitLossModel(
      startDate: json['startDate'],
      endDate: json['endDate'],
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      costOfGoodsSold: (json['costOfGoodsSold'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (json['grossProfit'] as num?)?.toDouble() ?? 0.0,
      totalOperatingExpenses:
          (json['totalOperatingExpenses'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0.0,
      revenueBreakdown: rev.map((e) => ReportLineItem.fromJson(e)).toList(),
      expenseBreakdown: exp.map((e) => ReportLineItem.fromJson(e)).toList(),
    );
  }
}

class SubLedgerPartyModel {
  final String id;
  final String name;
  final String? phone;
  final double currentBalance;

  SubLedgerPartyModel({
    required this.id,
    required this.name,
    this.phone,
    required this.currentBalance,
  });

  factory SubLedgerPartyModel.fromJson(Map<String, dynamic> json) {
    return SubLedgerPartyModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SubLedgerReportModel {
  final double total;
  final double controlBalance;
  final bool isReconciled;
  final double discrepancy;
  final List<SubLedgerPartyModel> parties;

  SubLedgerReportModel({
    required this.total,
    required this.controlBalance,
    required this.isReconciled,
    required this.discrepancy,
    required this.parties,
  });

  factory SubLedgerReportModel.fromJson(Map<String, dynamic> json, String partyListKey) {
    final rawParties = json[partyListKey] as List? ?? [];
    return SubLedgerReportModel(
      total: (json[partyListKey == 'customers' ? 'totalReceivables' : 'totalPayables'] as num?)?.toDouble() ?? 0.0,
      controlBalance: (json['generalLedgerControlBalance'] as num?)?.toDouble() ?? 0.0,
      isReconciled: json['isReconciled'] ?? false,
      discrepancy: (json['discrepancy'] as num?)?.toDouble() ?? 0.0,
      parties: rawParties.map((e) => SubLedgerPartyModel.fromJson(e)).toList(),
    );
  }
}
