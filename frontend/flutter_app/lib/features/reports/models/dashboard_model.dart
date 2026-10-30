class DashboardMetricsModel {
  final DashboardPeriodInfo period;
  final DashboardSalesMetrics sales;
  final DashboardPurchasesMetrics purchases;
  final DashboardExpensesMetrics expenses;
  final DashboardCashFlowMetrics cashFlow;
  final DashboardOutstandingMetrics outstanding;
  final DashboardInventoryMetrics inventory;
  final DashboardProfitabilityMetrics profitability;
  final DashboardRecentActivity recentActivity;
  final List<DashboardAlert> alerts;

  DashboardMetricsModel({
    required this.period,
    required this.sales,
    required this.purchases,
    required this.expenses,
    required this.cashFlow,
    required this.outstanding,
    required this.inventory,
    required this.profitability,
    required this.recentActivity,
    required this.alerts,
  });

  factory DashboardMetricsModel.fromJson(Map<String, dynamic> json) {
    return DashboardMetricsModel(
      period: DashboardPeriodInfo.fromJson(json['period'] ?? {}),
      sales: DashboardSalesMetrics.fromJson(json['sales'] ?? {}),
      purchases: DashboardPurchasesMetrics.fromJson(json['purchases'] ?? {}),
      expenses: DashboardExpensesMetrics.fromJson(json['expenses'] ?? {}),
      cashFlow: DashboardCashFlowMetrics.fromJson(json['cashFlow'] ?? {}),
      outstanding: DashboardOutstandingMetrics.fromJson(json['outstanding'] ?? {}),
      inventory: DashboardInventoryMetrics.fromJson(json['inventory'] ?? {}),
      profitability: DashboardProfitabilityMetrics.fromJson(json['profitability'] ?? {}),
      recentActivity: DashboardRecentActivity.fromJson(json['recentActivity'] ?? {}),
      alerts: (json['alerts'] as List? ?? [])
          .map((a) => DashboardAlert.fromJson(a))
          .toList(),
    );
  }
}

class DashboardPeriodInfo {
  final String selectedPeriod;
  final String startDate;
  final String endDate;

  DashboardPeriodInfo({
    required this.selectedPeriod,
    required this.startDate,
    required this.endDate,
  });

  factory DashboardPeriodInfo.fromJson(Map<String, dynamic> json) {
    return DashboardPeriodInfo(
      selectedPeriod: json['selectedPeriod'] ?? 'This Month',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
    );
  }
}

class DashboardSalesMetrics {
  final double totalSales;
  final double subtotal;
  final double taxAmount;
  final int invoiceCount;
  final double averageInvoiceValue;
  final double previousTotalSales;
  final double growthPercentage;

  DashboardSalesMetrics({
    required this.totalSales,
    required this.subtotal,
    required this.taxAmount,
    required this.invoiceCount,
    required this.averageInvoiceValue,
    required this.previousTotalSales,
    required this.growthPercentage,
  });

  factory DashboardSalesMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardSalesMetrics(
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      invoiceCount: json['invoiceCount'] ?? 0,
      averageInvoiceValue: (json['averageInvoiceValue'] as num?)?.toDouble() ?? 0.0,
      previousTotalSales: (json['previousTotalSales'] as num?)?.toDouble() ?? 0.0,
      growthPercentage: (json['growthPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardPurchasesMetrics {
  final double totalPurchases;
  final double subtotal;
  final double taxAmount;
  final int purchaseCount;
  final double previousTotalPurchases;
  final double growthPercentage;

  DashboardPurchasesMetrics({
    required this.totalPurchases,
    required this.subtotal,
    required this.taxAmount,
    required this.purchaseCount,
    required this.previousTotalPurchases,
    required this.growthPercentage,
  });

  factory DashboardPurchasesMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardPurchasesMetrics(
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      purchaseCount: json['purchaseCount'] ?? 0,
      previousTotalPurchases: (json['previousTotalPurchases'] as num?)?.toDouble() ?? 0.0,
      growthPercentage: (json['growthPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardExpensesMetrics {
  final double totalExpenses;
  final double gstAmount;
  final double netExpenses;
  final int expenseCount;
  final double previousTotalExpenses;

  DashboardExpensesMetrics({
    required this.totalExpenses,
    required this.gstAmount,
    required this.netExpenses,
    required this.expenseCount,
    required this.previousTotalExpenses,
  });

  factory DashboardExpensesMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardExpensesMetrics(
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0.0,
      netExpenses: (json['netExpenses'] as num?)?.toDouble() ?? 0.0,
      expenseCount: json['expenseCount'] ?? 0,
      previousTotalExpenses: (json['previousTotalExpenses'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardCashFlowMetrics {
  final double totalCollections;
  final double totalDisbursements;
  final double netCashFlow;

  DashboardCashFlowMetrics({
    required this.totalCollections,
    required this.totalDisbursements,
    required this.netCashFlow,
  });

  factory DashboardCashFlowMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardCashFlowMetrics(
      totalCollections: (json['totalCollections'] as num?)?.toDouble() ?? 0.0,
      totalDisbursements: (json['totalDisbursements'] as num?)?.toDouble() ?? 0.0,
      netCashFlow: (json['netCashFlow'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardOutstandingMetrics {
  final double receivables;
  final double payables;
  final double overdueReceivables;
  final double overduePayables;

  DashboardOutstandingMetrics({
    required this.receivables,
    required this.payables,
    required this.overdueReceivables,
    required this.overduePayables,
  });

  factory DashboardOutstandingMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardOutstandingMetrics(
      receivables: (json['receivables'] as num?)?.toDouble() ?? 0.0,
      payables: (json['payables'] as num?)?.toDouble() ?? 0.0,
      overdueReceivables: (json['overdueReceivables'] as num?)?.toDouble() ?? 0.0,
      overduePayables: (json['overduePayables'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardInventoryMetrics {
  final double totalValuation;
  final int totalProducts;
  final int inStockCount;
  final int lowStockCount;
  final int outOfStockCount;

  DashboardInventoryMetrics({
    required this.totalValuation,
    required this.totalProducts,
    required this.inStockCount,
    required this.lowStockCount,
    required this.outOfStockCount,
  });

  factory DashboardInventoryMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardInventoryMetrics(
      totalValuation: (json['totalValuation'] as num?)?.toDouble() ?? 0.0,
      totalProducts: json['totalProducts'] ?? 0,
      inStockCount: json['inStockCount'] ?? 0,
      lowStockCount: json['lowStockCount'] ?? 0,
      outOfStockCount: json['outOfStockCount'] ?? 0,
    );
  }
}

class DashboardProfitabilityMetrics {
  final double grossProfit;
  final double operatingExpenses;
  final double netProfit;
  final double netProfitMargin;
  final String calculationAssumptions;

  DashboardProfitabilityMetrics({
    required this.grossProfit,
    required this.operatingExpenses,
    required this.netProfit,
    required this.netProfitMargin,
    required this.calculationAssumptions,
  });

  factory DashboardProfitabilityMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardProfitabilityMetrics(
      grossProfit: (json['grossProfit'] as num?)?.toDouble() ?? 0.0,
      operatingExpenses: (json['operatingExpenses'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0.0,
      netProfitMargin: (json['netProfitMargin'] as num?)?.toDouble() ?? 0.0,
      calculationAssumptions: json['calculationAssumptions'] ?? '',
    );
  }
}

class DashboardRecentActivity {
  final List<RecentInvoiceItem> invoices;
  final List<RecentPurchaseItem> purchases;
  final List<RecentExpenseItem> expenses;

  DashboardRecentActivity({
    required this.invoices,
    required this.purchases,
    required this.expenses,
  });

  factory DashboardRecentActivity.fromJson(Map<String, dynamic> json) {
    return DashboardRecentActivity(
      invoices: (json['invoices'] as List? ?? [])
          .map((i) => RecentInvoiceItem.fromJson(i))
          .toList(),
      purchases: (json['purchases'] as List? ?? [])
          .map((p) => RecentPurchaseItem.fromJson(p))
          .toList(),
      expenses: (json['expenses'] as List? ?? [])
          .map((e) => RecentExpenseItem.fromJson(e))
          .toList(),
    );
  }
}

class RecentInvoiceItem {
  final String id;
  final String invoiceNumber;
  final String customerName;
  final double totalAmount;
  final double balanceAmount;
  final String status;
  final String date;

  RecentInvoiceItem({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.totalAmount,
    required this.balanceAmount,
    required this.status,
    required this.date,
  });

  factory RecentInvoiceItem.fromJson(Map<String, dynamic> json) {
    return RecentInvoiceItem(
      id: json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      customerName: json['customerName'] ?? 'Walk-in Customer',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'ISSUED',
      date: json['date'] ?? '',
    );
  }
}

class RecentPurchaseItem {
  final String id;
  final String billNumber;
  final String supplierName;
  final double totalAmount;
  final double balanceAmount;
  final String status;
  final String date;

  RecentPurchaseItem({
    required this.id,
    required this.billNumber,
    required this.supplierName,
    required this.totalAmount,
    required this.balanceAmount,
    required this.status,
    required this.date,
  });

  factory RecentPurchaseItem.fromJson(Map<String, dynamic> json) {
    return RecentPurchaseItem(
      id: json['id'] ?? '',
      billNumber: json['billNumber'] ?? '',
      supplierName: json['supplierName'] ?? 'Supplier',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'RECEIVED',
      date: json['date'] ?? '',
    );
  }
}

class RecentExpenseItem {
  final String id;
  final String expenseNumber;
  final String categoryName;
  final String? vendor;
  final double amount;
  final String date;

  RecentExpenseItem({
    required this.id,
    required this.expenseNumber,
    required this.categoryName,
    this.vendor,
    required this.amount,
    required this.date,
  });

  factory RecentExpenseItem.fromJson(Map<String, dynamic> json) {
    return RecentExpenseItem(
      id: json['id'] ?? '',
      expenseNumber: json['expenseNumber'] ?? '',
      categoryName: json['categoryName'] ?? 'Expense',
      vendor: json['vendor'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] ?? '',
    );
  }
}

class DashboardAlert {
  final String id;
  final String type;
  final String severity;
  final String title;
  final String message;
  final int? count;
  final double? amount;

  DashboardAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.count,
    this.amount,
  });

  factory DashboardAlert.fromJson(Map<String, dynamic> json) {
    return DashboardAlert(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      severity: json['severity'] ?? 'info',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      count: json['count'],
      amount: (json['amount'] as num?)?.toDouble(),
    );
  }
}

