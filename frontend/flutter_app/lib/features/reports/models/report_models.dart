// =========================================================================
// 1. SALES REPORT MODELS
// =========================================================================

class SalesReportSummary {
  final double totalInvoiced;
  final double subtotal;
  final double totalTax;
  final double totalDiscount;
  final double totalReceived;
  final double totalOutstanding;
  final int invoiceCount;
  final double averageInvoiceValue;

  SalesReportSummary({
    required this.totalInvoiced,
    required this.subtotal,
    required this.totalTax,
    required this.totalDiscount,
    required this.totalReceived,
    required this.totalOutstanding,
    required this.invoiceCount,
    required this.averageInvoiceValue,
  });

  factory SalesReportSummary.fromJson(Map<String, dynamic> json) {
    return SalesReportSummary(
      totalInvoiced: (json['totalInvoiced'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
      totalDiscount: (json['totalDiscount'] as num?)?.toDouble() ?? 0.0,
      totalReceived: (json['totalReceived'] as num?)?.toDouble() ?? 0.0,
      totalOutstanding: (json['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
      invoiceCount: json['invoiceCount'] ?? 0,
      averageInvoiceValue: (json['averageInvoiceValue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SalesReportItem {
  final String id;
  final String invoiceNumber;
  final String invoiceDate;
  final String? dueDate;
  final String customerName;
  final int itemCount;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double receivedAmount;
  final double balanceAmount;
  final String status;

  SalesReportItem({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.dueDate,
    required this.customerName,
    required this.itemCount,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.receivedAmount,
    required this.balanceAmount,
    required this.status,
  });

  factory SalesReportItem.fromJson(Map<String, dynamic> json) {
    return SalesReportItem(
      id: json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      invoiceDate: json['invoiceDate'] ?? '',
      dueDate: json['dueDate'],
      customerName: json['customerName'] ?? 'Walk-in Customer',
      itemCount: json['itemCount'] ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      receivedAmount: (json['receivedAmount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'ISSUED',
    );
  }
}

class SalesReportModel {
  final SalesReportSummary summary;
  final List<SalesReportItem> items;
  final int totalCount;

  SalesReportModel({
    required this.summary,
    required this.items,
    required this.totalCount,
  });

  factory SalesReportModel.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final rawItems = json['data'] as List? ?? [];
    return SalesReportModel(
      summary: SalesReportSummary.fromJson(json['summary'] ?? {}),
      items: rawItems.map((e) => SalesReportItem.fromJson(e)).toList(),
      totalCount: meta['total'] ?? rawItems.length,
    );
  }
}

// =========================================================================
// 2. PURCHASE REPORT MODELS
// =========================================================================

class PurchaseReportSummary {
  final double totalPurchased;
  final double subtotal;
  final double totalTax;
  final double totalPaid;
  final double totalOutstanding;
  final int billCount;

  PurchaseReportSummary({
    required this.totalPurchased,
    required this.subtotal,
    required this.totalTax,
    required this.totalPaid,
    required this.totalOutstanding,
    required this.billCount,
  });

  factory PurchaseReportSummary.fromJson(Map<String, dynamic> json) {
    return PurchaseReportSummary(
      totalPurchased: (json['totalPurchased'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalOutstanding: (json['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
      billCount: json['billCount'] ?? 0,
    );
  }
}

class PurchaseReportItem {
  final String id;
  final String billNumber;
  final String billDate;
  final String supplierName;
  final int itemCount;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final String status;
  final String paymentStatus;

  PurchaseReportItem({
    required this.id,
    required this.billNumber,
    required this.billDate,
    required this.supplierName,
    required this.itemCount,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.status,
    required this.paymentStatus,
  });

  factory PurchaseReportItem.fromJson(Map<String, dynamic> json) {
    return PurchaseReportItem(
      id: json['id'] ?? '',
      billNumber: json['billNumber'] ?? '',
      billDate: json['billDate'] ?? '',
      supplierName: json['supplierName'] ?? 'Supplier',
      itemCount: json['itemCount'] ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'RECEIVED',
      paymentStatus: json['paymentStatus'] ?? 'UNPAID',
    );
  }
}

class PurchaseReportModel {
  final PurchaseReportSummary summary;
  final List<PurchaseReportItem> items;
  final int totalCount;

  PurchaseReportModel({
    required this.summary,
    required this.items,
    required this.totalCount,
  });

  factory PurchaseReportModel.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final rawItems = json['data'] as List? ?? [];
    return PurchaseReportModel(
      summary: PurchaseReportSummary.fromJson(json['summary'] ?? {}),
      items: rawItems.map((e) => PurchaseReportItem.fromJson(e)).toList(),
      totalCount: meta['total'] ?? rawItems.length,
    );
  }
}

// =========================================================================
// 3. EXPENSE REPORT MODELS
// =========================================================================

class ExpenseCategoryBreakdown {
  final String categoryId;
  final String categoryName;
  final int count;
  final double amount;
  final double percentage;

  ExpenseCategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.count,
    required this.amount,
    required this.percentage,
  });

  factory ExpenseCategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryBreakdown(
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'] ?? 'General',
      count: json['count'] ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ExpenseReportSummary {
  final double totalExpenses;
  final double gstAmount;
  final double netExpenses;
  final int expenseCount;

  ExpenseReportSummary({
    required this.totalExpenses,
    required this.gstAmount,
    required this.netExpenses,
    required this.expenseCount,
  });

  factory ExpenseReportSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseReportSummary(
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0.0,
      netExpenses: (json['netExpenses'] as num?)?.toDouble() ?? 0.0,
      expenseCount: json['expenseCount'] ?? 0,
    );
  }
}

class ExpenseReportItem {
  final String id;
  final String expenseNumber;
  final String date;
  final String categoryName;
  final String? vendor;
  final double amount;
  final double gstAmount;
  final double netAmount;
  final String paymentMethod;
  final bool isTaxDeductible;

  ExpenseReportItem({
    required this.id,
    required this.expenseNumber,
    required this.date,
    required this.categoryName,
    this.vendor,
    required this.amount,
    required this.gstAmount,
    required this.netAmount,
    required this.paymentMethod,
    required this.isTaxDeductible,
  });

  factory ExpenseReportItem.fromJson(Map<String, dynamic> json) {
    return ExpenseReportItem(
      id: json['id'] ?? '',
      expenseNumber: json['expenseNumber'] ?? '',
      date: json['date'] ?? '',
      categoryName: json['categoryName'] ?? 'Expense',
      vendor: json['vendor'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] ?? 'CASH',
      isTaxDeductible: json['isTaxDeductible'] ?? true,
    );
  }
}

class ExpenseReportModel {
  final ExpenseReportSummary summary;
  final List<ExpenseCategoryBreakdown> categoryBreakdown;
  final List<ExpenseReportItem> items;
  final int totalCount;

  ExpenseReportModel({
    required this.summary,
    required this.categoryBreakdown,
    required this.items,
    required this.totalCount,
  });

  factory ExpenseReportModel.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final rawCats = json['categoryBreakdown'] as List? ?? [];
    final rawItems = json['data'] as List? ?? [];
    return ExpenseReportModel(
      summary: ExpenseReportSummary.fromJson(json['summary'] ?? {}),
      categoryBreakdown: rawCats.map((e) => ExpenseCategoryBreakdown.fromJson(e)).toList(),
      items: rawItems.map((e) => ExpenseReportItem.fromJson(e)).toList(),
      totalCount: meta['total'] ?? rawItems.length,
    );
  }
}

// =========================================================================
// 4. PAYMENTS & COLLECTIONS REPORT MODELS
// =========================================================================

class PaymentsReportSummary {
  final double totalReceipts;
  final int receiptsCount;
  final double totalDisbursements;
  final int disbursementsCount;
  final double netCashFlow;

  PaymentsReportSummary({
    required this.totalReceipts,
    required this.receiptsCount,
    required this.totalDisbursements,
    required this.disbursementsCount,
    required this.netCashFlow,
  });

  factory PaymentsReportSummary.fromJson(Map<String, dynamic> json) {
    return PaymentsReportSummary(
      totalReceipts: (json['totalReceipts'] as num?)?.toDouble() ?? 0.0,
      receiptsCount: json['receiptsCount'] ?? 0,
      totalDisbursements: (json['totalDisbursements'] as num?)?.toDouble() ?? 0.0,
      disbursementsCount: json['disbursementsCount'] ?? 0,
      netCashFlow: (json['netCashFlow'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PaymentReportItem {
  final String id;
  final String paymentNumber;
  final String paymentType;
  final String paymentDate;
  final String paymentMethod;
  final String? referenceNumber;
  final String partyName;
  final double amount;
  final int allocationCount;

  PaymentReportItem({
    required this.id,
    required this.paymentNumber,
    required this.paymentType,
    required this.paymentDate,
    required this.paymentMethod,
    this.referenceNumber,
    required this.partyName,
    required this.amount,
    required this.allocationCount,
  });

  factory PaymentReportItem.fromJson(Map<String, dynamic> json) {
    return PaymentReportItem(
      id: json['id'] ?? '',
      paymentNumber: json['paymentNumber'] ?? '',
      paymentType: json['paymentType'] ?? 'CUSTOMER_RECEIPT',
      paymentDate: json['paymentDate'] ?? '',
      paymentMethod: json['paymentMethod'] ?? 'CASH',
      referenceNumber: json['referenceNumber'],
      partyName: json['partyName'] ?? 'Party',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      allocationCount: json['allocationCount'] ?? 0,
    );
  }
}

class PaymentsReportModel {
  final PaymentsReportSummary summary;
  final List<PaymentReportItem> items;
  final int totalCount;

  PaymentsReportModel({
    required this.summary,
    required this.items,
    required this.totalCount,
  });

  factory PaymentsReportModel.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final rawItems = json['data'] as List? ?? [];
    return PaymentsReportModel(
      summary: PaymentsReportSummary.fromJson(json['summary'] ?? {}),
      items: rawItems.map((e) => PaymentReportItem.fromJson(e)).toList(),
      totalCount: meta['total'] ?? rawItems.length,
    );
  }
}

// =========================================================================
// 5. RECEIVABLES & AGEING REPORT MODELS
// =========================================================================

class AgeingSummary {
  final String asOfDate;
  final double totalReceivables;
  final double totalCustomerLedgerBalances;
  final double glControlAccountBalance;
  final bool isReconciled;
  final double discrepancy;
  final double bucket0to30;
  final double bucket31to60;
  final double bucket61to90;
  final double bucket90Plus;

  AgeingSummary({
    required this.asOfDate,
    required this.totalReceivables,
    required this.totalCustomerLedgerBalances,
    required this.glControlAccountBalance,
    required this.isReconciled,
    required this.discrepancy,
    required this.bucket0to30,
    required this.bucket31to60,
    required this.bucket61to90,
    required this.bucket90Plus,
  });

  factory AgeingSummary.fromJson(Map<String, dynamic> json) {
    return AgeingSummary(
      asOfDate: json['asOfDate'] ?? '',
      totalReceivables: (json['totalReceivables'] as num?)?.toDouble() ?? 0.0,
      totalCustomerLedgerBalances: (json['totalCustomerLedgerBalances'] as num?)?.toDouble() ?? 0.0,
      glControlAccountBalance: (json['glControlAccountBalance'] as num?)?.toDouble() ?? 0.0,
      isReconciled: json['isReconciled'] ?? false,
      discrepancy: (json['discrepancy'] as num?)?.toDouble() ?? 0.0,
      bucket0to30: (json['bucket0to30'] as num?)?.toDouble() ?? 0.0,
      bucket31to60: (json['bucket31to60'] as num?)?.toDouble() ?? 0.0,
      bucket61to90: (json['bucket61to90'] as num?)?.toDouble() ?? 0.0,
      bucket90Plus: (json['bucket90Plus'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomerAgeingItem {
  final String id;
  final String name;
  final String? phone;
  final double ledgerBalance;
  final int unpaidInvoicesCount;
  final double bucket0to30;
  final double bucket31to60;
  final double bucket61to90;
  final double bucket90Plus;
  final double totalAgeingBalance;
  final String? oldestInvoiceDate;

  CustomerAgeingItem({
    required this.id,
    required this.name,
    this.phone,
    required this.ledgerBalance,
    required this.unpaidInvoicesCount,
    required this.bucket0to30,
    required this.bucket31to60,
    required this.bucket61to90,
    required this.bucket90Plus,
    required this.totalAgeingBalance,
    this.oldestInvoiceDate,
  });

  factory CustomerAgeingItem.fromJson(Map<String, dynamic> json) {
    return CustomerAgeingItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      ledgerBalance: (json['ledgerBalance'] as num?)?.toDouble() ?? 0.0,
      unpaidInvoicesCount: json['unpaidInvoicesCount'] ?? 0,
      bucket0to30: (json['bucket0to30'] as num?)?.toDouble() ?? 0.0,
      bucket31to60: (json['bucket31to60'] as num?)?.toDouble() ?? 0.0,
      bucket61to90: (json['bucket61to90'] as num?)?.toDouble() ?? 0.0,
      bucket90Plus: (json['bucket90Plus'] as num?)?.toDouble() ?? 0.0,
      totalAgeingBalance: (json['totalAgeingBalance'] as num?)?.toDouble() ?? 0.0,
      oldestInvoiceDate: json['oldestInvoiceDate'],
    );
  }
}

class ReceivablesAgeingReportModel {
  final AgeingSummary summary;
  final List<CustomerAgeingItem> customers;

  ReceivablesAgeingReportModel({
    required this.summary,
    required this.customers,
  });

  factory ReceivablesAgeingReportModel.fromJson(Map<String, dynamic> json) {
    final rawCusts = json['customers'] as List? ?? [];
    return ReceivablesAgeingReportModel(
      summary: AgeingSummary.fromJson(json['summary'] ?? {}),
      customers: rawCusts.map((e) => CustomerAgeingItem.fromJson(e)).toList(),
    );
  }
}

// =========================================================================
// 6. PAYABLES & AGEING REPORT MODELS
// =========================================================================

class SupplierAgeingItem {
  final String id;
  final String name;
  final String? phone;
  final double ledgerBalance;
  final int unpaidBillsCount;
  final double bucket0to30;
  final double bucket31to60;
  final double bucket61to90;
  final double bucket90Plus;
  final double totalAgeingBalance;
  final String? oldestBillDate;

  SupplierAgeingItem({
    required this.id,
    required this.name,
    this.phone,
    required this.ledgerBalance,
    required this.unpaidBillsCount,
    required this.bucket0to30,
    required this.bucket31to60,
    required this.bucket61to90,
    required this.bucket90Plus,
    required this.totalAgeingBalance,
    this.oldestBillDate,
  });

  factory SupplierAgeingItem.fromJson(Map<String, dynamic> json) {
    return SupplierAgeingItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      ledgerBalance: (json['ledgerBalance'] as num?)?.toDouble() ?? 0.0,
      unpaidBillsCount: json['unpaidBillsCount'] ?? 0,
      bucket0to30: (json['bucket0to30'] as num?)?.toDouble() ?? 0.0,
      bucket31to60: (json['bucket31to60'] as num?)?.toDouble() ?? 0.0,
      bucket61to90: (json['bucket61to90'] as num?)?.toDouble() ?? 0.0,
      bucket90Plus: (json['bucket90Plus'] as num?)?.toDouble() ?? 0.0,
      totalAgeingBalance: (json['totalAgeingBalance'] as num?)?.toDouble() ?? 0.0,
      oldestBillDate: json['oldestBillDate'],
    );
  }
}

class PayablesAgeingReportModel {
  final AgeingSummary summary;
  final List<SupplierAgeingItem> suppliers;

  PayablesAgeingReportModel({
    required this.summary,
    required this.suppliers,
  });

  factory PayablesAgeingReportModel.fromJson(Map<String, dynamic> json) {
    final rawSupps = json['suppliers'] as List? ?? [];
    return PayablesAgeingReportModel(
      summary: AgeingSummary.fromJson(json['summary'] ?? {}),
      suppliers: rawSupps.map((e) => SupplierAgeingItem.fromJson(e)).toList(),
    );
  }
}

// =========================================================================
// 7. STOCK SUMMARY REPORT MODELS
// =========================================================================

class StockSummaryReportSummary {
  final int totalProducts;
  final double totalValuation;
  final int totalStockUnits;
  final int inStockCount;
  final int lowStockCount;
  final int outOfStockCount;

  StockSummaryReportSummary({
    required this.totalProducts,
    required this.totalValuation,
    required this.totalStockUnits,
    required this.inStockCount,
    required this.lowStockCount,
    required this.outOfStockCount,
  });

  factory StockSummaryReportSummary.fromJson(Map<String, dynamic> json) {
    return StockSummaryReportSummary(
      totalProducts: json['totalProducts'] ?? 0,
      totalValuation: (json['totalValuation'] as num?)?.toDouble() ?? 0.0,
      totalStockUnits: json['totalStockUnits'] ?? 0,
      inStockCount: json['inStockCount'] ?? 0,
      lowStockCount: json['lowStockCount'] ?? 0,
      outOfStockCount: json['outOfStockCount'] ?? 0,
    );
  }
}

class StockSummaryItem {
  final String id;
  final String name;
  final String? sku;
  final String categoryName;
  final String unitSymbol;
  final bool trackStock;
  final double minStockLevel;
  final double currentStock;
  final double unitCost;
  final double salePrice;
  final double valuation;
  final String stockStatus;

  StockSummaryItem({
    required this.id,
    required this.name,
    this.sku,
    required this.categoryName,
    required this.unitSymbol,
    required this.trackStock,
    required this.minStockLevel,
    required this.currentStock,
    required this.unitCost,
    required this.salePrice,
    required this.valuation,
    required this.stockStatus,
  });

  factory StockSummaryItem.fromJson(Map<String, dynamic> json) {
    return StockSummaryItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      sku: json['sku'],
      categoryName: json['categoryName'] ?? 'General',
      unitSymbol: json['unitSymbol'] ?? 'pcs',
      trackStock: json['trackStock'] ?? true,
      minStockLevel: (json['minStockLevel'] as num?)?.toDouble() ?? 0.0,
      currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0.0,
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
      salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0.0,
      valuation: (json['valuation'] as num?)?.toDouble() ?? 0.0,
      stockStatus: json['stockStatus'] ?? 'IN_STOCK',
    );
  }
}

class StockSummaryReportModel {
  final StockSummaryReportSummary summary;
  final List<StockSummaryItem> items;
  final int totalCount;

  StockSummaryReportModel({
    required this.summary,
    required this.items,
    required this.totalCount,
  });

  factory StockSummaryReportModel.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final rawItems = json['data'] as List? ?? [];
    return StockSummaryReportModel(
      summary: StockSummaryReportSummary.fromJson(json['summary'] ?? {}),
      items: rawItems.map((e) => StockSummaryItem.fromJson(e)).toList(),
      totalCount: meta['total'] ?? rawItems.length,
    );
  }
}

// =========================================================================
// 8. STOCK MOVEMENT REPORT MODELS
// =========================================================================

class StockMovementItem {
  final String id;
  final String createdAt;
  final String productName;
  final String? sku;
  final String unitSymbol;
  final String warehouseName;
  final String movementType;
  final double quantity;
  final double unitCost;
  final double totalCost;
  final String? referenceType;
  final String? notes;

  StockMovementItem({
    required this.id,
    required this.createdAt,
    required this.productName,
    this.sku,
    required this.unitSymbol,
    required this.warehouseName,
    required this.movementType,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.referenceType,
    this.notes,
  });

  factory StockMovementItem.fromJson(Map<String, dynamic> json) {
    return StockMovementItem(
      id: json['id'] ?? '',
      createdAt: json['createdAt'] ?? '',
      productName: json['productName'] ?? '',
      sku: json['sku'],
      unitSymbol: json['unitSymbol'] ?? 'pcs',
      warehouseName: json['warehouseName'] ?? 'Default Warehouse',
      movementType: json['movementType'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
      referenceType: json['referenceType'],
      notes: json['notes'],
    );
  }
}

class StockMovementReportModel {
  final List<StockMovementItem> items;
  final int totalCount;

  StockMovementReportModel({
    required this.items,
    required this.totalCount,
  });

  factory StockMovementReportModel.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final rawItems = json['data'] as List? ?? [];
    return StockMovementReportModel(
      items: rawItems.map((e) => StockMovementItem.fromJson(e)).toList(),
      totalCount: meta['total'] ?? rawItems.length,
    );
  }
}

// =========================================================================
// 9. PRODUCT PERFORMANCE REPORT MODELS
// =========================================================================

class ProductPerformanceItem {
  final String productId;
  final String name;
  final String? sku;
  final double unitsSold;
  final double totalRevenue;
  final double estimatedCost;
  final double estimatedGrossProfit;
  final double grossMarginPercentage;

  ProductPerformanceItem({
    required this.productId,
    required this.name,
    this.sku,
    required this.unitsSold,
    required this.totalRevenue,
    required this.estimatedCost,
    required this.estimatedGrossProfit,
    required this.grossMarginPercentage,
  });

  factory ProductPerformanceItem.fromJson(Map<String, dynamic> json) {
    return ProductPerformanceItem(
      productId: json['productId'] ?? '',
      name: json['name'] ?? '',
      sku: json['sku'],
      unitsSold: (json['unitsSold'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      estimatedGrossProfit: (json['estimatedGrossProfit'] as num?)?.toDouble() ?? 0.0,
      grossMarginPercentage: (json['grossMarginPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// =========================================================================
// 10. TAX & GST STATUTORY SUMMARY REPORT MODELS
// =========================================================================

class GstOutwardSupplies {
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double cessAmount;
  final double totalOutwardTaxLiability;

  GstOutwardSupplies({
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.cessAmount,
    required this.totalOutwardTaxLiability,
  });

  factory GstOutwardSupplies.fromJson(Map<String, dynamic> json) {
    return GstOutwardSupplies(
      taxableValue: (json['taxableValue'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (json['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (json['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (json['igstAmount'] as num?)?.toDouble() ?? 0.0,
      cessAmount: (json['cessAmount'] as num?)?.toDouble() ?? 0.0,
      totalOutwardTaxLiability: (json['totalOutwardTaxLiability'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GstInwardSupplies {
  final double purchasesTaxable;
  final double purchasesItc;
  final double expensesItc;
  final double totalEligibleItc;

  GstInwardSupplies({
    required this.purchasesTaxable,
    required this.purchasesItc,
    required this.expensesItc,
    required this.totalEligibleItc,
  });

  factory GstInwardSupplies.fromJson(Map<String, dynamic> json) {
    return GstInwardSupplies(
      purchasesTaxable: (json['purchasesTaxable'] as num?)?.toDouble() ?? 0.0,
      purchasesItc: (json['purchasesItc'] as num?)?.toDouble() ?? 0.0,
      expensesItc: (json['expensesItc'] as num?)?.toDouble() ?? 0.0,
      totalEligibleItc: (json['totalEligibleItc'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GstSummaryReportModel {
  final GstOutwardSupplies outwardSupplies;
  final GstInwardSupplies inwardSupplies;
  final double netGstPayable;
  final double itcCarryForward;
  final String disclaimer;

  GstSummaryReportModel({
    required this.outwardSupplies,
    required this.inwardSupplies,
    required this.netGstPayable,
    required this.itcCarryForward,
    required this.disclaimer,
  });

  factory GstSummaryReportModel.fromJson(Map<String, dynamic> json) {
    final d = json['data'] ?? json;
    return GstSummaryReportModel(
      outwardSupplies: GstOutwardSupplies.fromJson(d['outwardSupplies'] ?? {}),
      inwardSupplies: GstInwardSupplies.fromJson(d['inwardSupplies'] ?? {}),
      netGstPayable: (d['netGstPayable'] as num?)?.toDouble() ?? 0.0,
      itcCarryForward: (d['itcCarryForward'] as num?)?.toDouble() ?? 0.0,
      disclaimer: d['disclaimer'] ?? '',
    );
  }
}

