import 'account_model.dart';

class LedgerEntryModel {
  final String id;
  final String accountId;
  final String accountCode;
  final String accountName;
  final AccountType accountType;
  final double debit;
  final double credit;

  LedgerEntryModel({
    required this.id,
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debit,
    required this.credit,
  });

  factory LedgerEntryModel.fromJson(Map<String, dynamic> json) {
    final acc = json['account'] ?? {};
    return LedgerEntryModel(
      id: json['id'] ?? '',
      accountId: json['accountId'] ?? acc['id'] ?? '',
      accountCode: acc['code'] ?? '',
      accountName: acc['name'] ?? '',
      accountType: AccountType.fromString(acc['type'] ?? 'ASSET'),
      debit: (json['debit'] is num)
          ? (json['debit'] as num).toDouble()
          : double.tryParse(json['debit']?.toString() ?? '0') ?? 0.0,
      credit: (json['credit'] is num)
          ? (json['credit'] as num).toDouble()
          : double.tryParse(json['credit']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'debit': debit,
        'credit': credit,
      };
}

class JournalEntryModel {
  final String id;
  final String entryNumber;
  final DateTime date;
  final String narration;
  final String? referenceType;
  final String? referenceId;
  final List<LedgerEntryModel> entries;

  JournalEntryModel({
    required this.id,
    required this.entryNumber,
    required this.date,
    required this.narration,
    this.referenceType,
    this.referenceId,
    required this.entries,
  });

  double get totalDebit => entries.fold(0.0, (sum, e) => sum + e.debit);
  double get totalCredit => entries.fold(0.0, (sum, e) => sum + e.credit);
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['ledgerEntries'] as List? ?? [];
    return JournalEntryModel(
      id: json['id'] ?? '',
      entryNumber: json['entryNumber'] ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date']) ?? DateTime.now()
          : DateTime.now(),
      narration: json['narration'] ?? '',
      referenceType: json['referenceType'],
      referenceId: json['referenceId'],
      entries: rawEntries.map((e) => LedgerEntryModel.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryNumber': entryNumber,
        'date': date.toIso8601String(),
        'narration': narration,
        'referenceType': referenceType,
        'referenceId': referenceId,
        'ledgerEntries': entries.map((e) => e.toJson()).toList(),
      };
}
