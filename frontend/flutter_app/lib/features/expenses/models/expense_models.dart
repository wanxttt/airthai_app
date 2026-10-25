class ExpenseCategoryModel {
  final String id;
  final String name;

  const ExpenseCategoryModel({
    required this.id,
    required this.name,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class ExpenseModel {
  final String id;
  final String expenseNumber;
  final String categoryId;
  final String categoryName;
  final DateTime date;
  final double amount;
  final String paymentMethod;
  final String? vendor;
  final String? gstin;
  final double gstAmount;
  final bool isTaxDeductible;
  final String? receiptUrl;
  final String? notes;

  const ExpenseModel({
    required this.id,
    required this.expenseNumber,
    required this.categoryId,
    required this.categoryName,
    required this.date,
    required this.amount,
    required this.paymentMethod,
    this.vendor,
    this.gstin,
    this.gstAmount = 0.0,
    this.isTaxDeductible = true,
    this.receiptUrl,
    this.notes,
  });

  String get formattedMethod {
    switch (paymentMethod.toUpperCase()) {
      case 'CASH':
        return 'Cash';
      case 'UPI':
        return 'UPI';
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'CHEQUE':
        return 'Cheque';
      case 'CARD':
        return 'Card';
      default:
        return paymentMethod;
    }
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String? ?? '',
      expenseNumber: json['expenseNumber'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      categoryName: json['category']?['name'] as String? ?? json['categoryName'] as String? ?? 'General',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      vendor: json['vendor'] as String?,
      gstin: json['gstin'] as String?,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0.0,
      isTaxDeductible: json['isTaxDeductible'] as bool? ?? true,
      receiptUrl: json['receiptUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expenseNumber': expenseNumber,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'date': date.toIso8601String(),
      'amount': amount,
      'paymentMethod': paymentMethod,
      if (vendor != null) 'vendor': vendor,
      if (gstin != null) 'gstin': gstin,
      'gstAmount': gstAmount,
      'isTaxDeductible': isTaxDeductible,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
      if (notes != null) 'notes': notes,
    };
  }
}

class ExpenseCategorySummary {
  final String categoryId;
  final String categoryName;
  final double amount;
  final int count;

  const ExpenseCategorySummary({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.count,
  });

  factory ExpenseCategorySummary.fromJson(Map<String, dynamic> json) {
    return ExpenseCategorySummary(
      categoryId: json['categoryId'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExpenseSummaryModel {
  final double totalExpenses;
  final double totalGstAmount;
  final double totalTaxDeductible;
  final int count;
  final List<ExpenseCategorySummary> categoryBreakdown;

  const ExpenseSummaryModel({
    required this.totalExpenses,
    required this.totalGstAmount,
    required this.totalTaxDeductible,
    required this.count,
    this.categoryBreakdown = const [],
  });

  factory ExpenseSummaryModel.fromJson(Map<String, dynamic> json) {
    final breakdown = (json['categoryBreakdown'] as List<dynamic>?)
            ?.map((c) => ExpenseCategorySummary.fromJson(c as Map<String, dynamic>))
            .toList() ??
        const [];

    return ExpenseSummaryModel(
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      totalGstAmount: (json['totalGstAmount'] as num?)?.toDouble() ?? 0.0,
      totalTaxDeductible: (json['totalTaxDeductible'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      categoryBreakdown: breakdown,
    );
  }
}
