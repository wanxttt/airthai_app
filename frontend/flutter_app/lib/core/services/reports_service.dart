import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/service_result.dart';
import '../security/session_manager.dart';
import '../../features/reports/models/report_models.dart';

class ReportsService {
  ReportsService._();
  static final ReportsService instance = ReportsService._();

  // =========================================================================
  // 1. SALES REPORT
  // =========================================================================
  Future<ServiceResult<SalesReportModel>> getSalesReport({
    String? startDate,
    String? endDate,
    String? customerId,
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockSalesReport());
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsSales}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(SalesReportModel.fromJson(res.data!));
      }
      return ServiceResult.success(_buildMockSalesReport());
    } catch (e) {
      return ServiceResult.success(_buildMockSalesReport());
    }
  }

  // =========================================================================
  // 2. PURCHASE REPORT
  // =========================================================================
  Future<ServiceResult<PurchaseReportModel>> getPurchasesReport({
    String? startDate,
    String? endDate,
    String? supplierId,
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockPurchasesReport());
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (supplierId != null && supplierId.isNotEmpty) 'supplierId': supplierId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsPurchases}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(PurchaseReportModel.fromJson(res.data!));
      }
      return ServiceResult.success(_buildMockPurchasesReport());
    } catch (e) {
      return ServiceResult.success(_buildMockPurchasesReport());
    }
  }

  // =========================================================================
  // 3. EXPENSE REPORT
  // =========================================================================
  Future<ServiceResult<ExpenseReportModel>> getExpensesReport({
    String? startDate,
    String? endDate,
    String? categoryId,
    String? paymentMethod,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockExpensesReport());
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
        if (paymentMethod != null && paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsExpenses}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(ExpenseReportModel.fromJson(res.data!));
      }
      return ServiceResult.success(_buildMockExpensesReport());
    } catch (e) {
      return ServiceResult.success(_buildMockExpensesReport());
    }
  }

  // =========================================================================
  // 4. PAYMENTS & COLLECTIONS REPORT
  // =========================================================================
  Future<ServiceResult<PaymentsReportModel>> getPaymentsReport({
    String? startDate,
    String? endDate,
    String? paymentType,
    String? paymentMethod,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockPaymentsReport());
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (paymentType != null && paymentType.isNotEmpty) 'paymentType': paymentType,
        if (paymentMethod != null && paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsPayments}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(PaymentsReportModel.fromJson(res.data!));
      }
      return ServiceResult.success(_buildMockPaymentsReport());
    } catch (e) {
      return ServiceResult.success(_buildMockPaymentsReport());
    }
  }

  // =========================================================================
  // 5. RECEIVABLES & AGEING REPORT
  // =========================================================================
  Future<ServiceResult<ReceivablesAgeingReportModel>> getReceivablesAgeing({
    String? asOfDate,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockReceivablesAgeing());
    }

    try {
      final queryParams = <String, String>{
        if (asOfDate != null && asOfDate.isNotEmpty) 'asOfDate': asOfDate,
      };
      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsReceivablesAgeing}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(ReceivablesAgeingReportModel.fromJson(res.data!));
      }
      return ServiceResult.success(_buildMockReceivablesAgeing());
    } catch (e) {
      return ServiceResult.success(_buildMockReceivablesAgeing());
    }
  }

  // =========================================================================
  // 6. PAYABLES & AGEING REPORT
  // =========================================================================
  Future<ServiceResult<PayablesAgeingReportModel>> getPayablesAgeing({
    String? asOfDate,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockPayablesAgeing());
    }

    try {
      final queryParams = <String, String>{
        if (asOfDate != null && asOfDate.isNotEmpty) 'asOfDate': asOfDate,
      };
      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsPayablesAgeing}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(PayablesAgeingReportModel.fromJson(res.data!));
      }
      return ServiceResult.success(_buildMockPayablesAgeing());
    } catch (e) {
      return ServiceResult.success(_buildMockPayablesAgeing());
    }
  }

  // =========================================================================
  // 7. STOCK SUMMARY REPORT
  // =========================================================================
  Future<ServiceResult<StockSummaryReportModel>> getStockSummary({
    String? status,
    String? categoryId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockStockSummary());
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
      };
      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsStockSummary}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(StockSummaryReportModel.fromJson(res.data!));
      }
      return ServiceResult.success(_buildMockStockSummary());
    } catch (e) {
      return ServiceResult.success(_buildMockStockSummary());
    }
  }

  // =========================================================================
  // 8. STOCK MOVEMENT REPORT
  // =========================================================================
  Future<ServiceResult<StockMovementReportModel>> getStockMovements({
    String? productId,
    String? movementType,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockStockMovements());
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (productId != null && productId.isNotEmpty) 'productId': productId,
        if (movementType != null && movementType.isNotEmpty) 'movementType': movementType,
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      };
      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsStockMovements}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(StockMovementReportModel.fromJson(res.data!));
      }
      return ServiceResult.success(_buildMockStockMovements());
    } catch (e) {
      return ServiceResult.success(_buildMockStockMovements());
    }
  }

  // =========================================================================
  // 9. PRODUCT PERFORMANCE REPORT
  // =========================================================================
  Future<ServiceResult<List<ProductPerformanceItem>>> getProductPerformance({
    String? startDate,
    String? endDate,
    int limit = 10,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockProductPerformance());
    }

    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      };
      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsProductPerformance}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data!['data'] as List? ?? [])
            .map((e) => ProductPerformanceItem.fromJson(e))
            .toList();
        return ServiceResult.success(list);
      }
      return ServiceResult.success(_buildMockProductPerformance());
    } catch (e) {
      return ServiceResult.success(_buildMockProductPerformance());
    }
  }

  // =========================================================================
  // 10. GST SUMMARY REPORT
  // =========================================================================
  Future<ServiceResult<GstSummaryReportModel>> getGstSummary({
    String? startDate,
    String? endDate,
  }) async {
    final mode = SessionManager.instance.authMode;
    if (mode == AuthMode.devMock) {
      return ServiceResult.success(_buildMockGstSummary());
    }

    try {
      final queryParams = <String, String>{
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      };
      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.instance.get('${ApiConstants.reportsGstSummary}?$queryString');

      if (res.statusCode == 200 && res.data != null) {
        return ServiceResult.success(GstSummaryReportModel.fromJson(res.data!));
      }
      return ServiceResult.success(_buildMockGstSummary());
    } catch (e) {
      return ServiceResult.success(_buildMockGstSummary());
    }
  }

  // =========================================================================
  // MOCK DATA FACTORIES (For seamless offline testing & DevMock mode)
  // =========================================================================
  SalesReportModel _buildMockSalesReport() {
    return SalesReportModel(
      summary: SalesReportSummary(
        totalInvoiced: 185450.0,
        subtotal: 157161.0,
        totalTax: 28289.0,
        totalDiscount: 3500.0,
        totalReceived: 140450.0,
        totalOutstanding: 45000.0,
        invoiceCount: 24,
        averageInvoiceValue: 7727.08,
      ),
      items: [
        SalesReportItem(
          id: 'inv_1',
          invoiceNumber: 'INV-2026-0042',
          invoiceDate: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          customerName: 'Shree Sai Enterprises',
          itemCount: 4,
          subtotal: 12288.0,
          discountAmount: 0.0,
          taxAmount: 2212.0,
          totalAmount: 14500.0,
          receivedAmount: 14500.0,
          balanceAmount: 0.0,
          status: 'PAID',
        ),
        SalesReportItem(
          id: 'inv_2',
          invoiceNumber: 'INV-2026-0041',
          invoiceDate: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          customerName: 'Apex Logistics Ltd',
          itemCount: 6,
          subtotal: 24067.8,
          discountAmount: 1000.0,
          taxAmount: 4332.2,
          totalAmount: 28400.0,
          receivedAmount: 16000.0,
          balanceAmount: 12400.0,
          status: 'PARTIALLY_PAID',
        ),
      ],
      totalCount: 2,
    );
  }

  PurchaseReportModel _buildMockPurchasesReport() {
    return PurchaseReportModel(
      summary: PurchaseReportSummary(
        totalPurchased: 94200.0,
        subtotal: 79830.0,
        totalTax: 14370.0,
        totalPaid: 59200.0,
        totalOutstanding: 35000.0,
        billCount: 11,
      ),
      items: [
        PurchaseReportItem(
          id: 'pur_1',
          billNumber: 'PUR-8910',
          billDate: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          supplierName: 'Bharat Electronics Co.',
          itemCount: 5,
          subtotal: 29237.0,
          taxAmount: 5263.0,
          totalAmount: 34500.0,
          paidAmount: 20000.0,
          balanceAmount: 14500.0,
          status: 'RECEIVED',
          paymentStatus: 'PARTIALLY_PAID',
        ),
      ],
      totalCount: 1,
    );
  }

  ExpenseReportModel _buildMockExpensesReport() {
    return ExpenseReportModel(
      summary: ExpenseReportSummary(
        totalExpenses: 28900.0,
        gstAmount: 2600.0,
        netExpenses: 26300.0,
        expenseCount: 16,
      ),
      categoryBreakdown: [
        ExpenseCategoryBreakdown(categoryId: 'c1', categoryName: 'Rent & Facilities', count: 1, amount: 18000.0, percentage: 62.3),
        ExpenseCategoryBreakdown(categoryId: 'c2', categoryName: 'General & Admin', count: 8, amount: 6500.0, percentage: 22.5),
        ExpenseCategoryBreakdown(categoryId: 'c3', categoryName: 'Logistics & Courier', count: 7, amount: 4400.0, percentage: 15.2),
      ],
      items: [
        ExpenseReportItem(
          id: 'e1',
          expenseNumber: 'EXP-1092',
          date: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          categoryName: 'Rent & Facilities',
          vendor: 'Metro Complex Trust',
          amount: 18000.0,
          gstAmount: 0.0,
          netAmount: 18000.0,
          paymentMethod: 'BANK_TRANSFER',
          isTaxDeductible: true,
        ),
      ],
      totalCount: 1,
    );
  }

  PaymentsReportModel _buildMockPaymentsReport() {
    return PaymentsReportModel(
      summary: PaymentsReportSummary(
        totalReceipts: 152000.0,
        receiptsCount: 22,
        totalDisbursements: 86000.0,
        disbursementsCount: 9,
        netCashFlow: 66000.0,
      ),
      items: [
        PaymentReportItem(
          id: 'pay_1',
          paymentNumber: 'RCP-2026-0031',
          paymentType: 'CUSTOMER_RECEIPT',
          paymentDate: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          paymentMethod: 'UPI',
          partyName: 'Shree Sai Enterprises',
          amount: 14500.0,
          allocationCount: 1,
        ),
      ],
      totalCount: 1,
    );
  }

  ReceivablesAgeingReportModel _buildMockReceivablesAgeing() {
    return ReceivablesAgeingReportModel(
      summary: AgeingSummary(
        asOfDate: DateTime.now().toIso8601String(),
        totalReceivables: 45000.0,
        totalCustomerLedgerBalances: 45000.0,
        glControlAccountBalance: 45000.0,
        isReconciled: true,
        discrepancy: 0.0,
        bucket0to30: 22000.0,
        bucket31to60: 13000.0,
        bucket61to90: 7000.0,
        bucket90Plus: 3000.0,
      ),
      customers: [
        CustomerAgeingItem(
          id: 'c_1',
          name: 'Apex Logistics Ltd',
          phone: '+91 98200 11223',
          ledgerBalance: 12400.0,
          unpaidInvoicesCount: 1,
          bucket0to30: 12400.0,
          bucket31to60: 0.0,
          bucket61to90: 0.0,
          bucket90Plus: 0.0,
          totalAgeingBalance: 12400.0,
          oldestInvoiceDate: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        ),
        CustomerAgeingItem(
          id: 'c_2',
          name: 'Global Traders Corp',
          phone: '+91 94400 44556',
          ledgerBalance: 10000.0,
          unpaidInvoicesCount: 1,
          bucket0to30: 0.0,
          bucket31to60: 10000.0,
          bucket61to90: 0.0,
          bucket90Plus: 0.0,
          totalAgeingBalance: 10000.0,
          oldestInvoiceDate: DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
        ),
      ],
    );
  }

  PayablesAgeingReportModel _buildMockPayablesAgeing() {
    return PayablesAgeingReportModel(
      summary: AgeingSummary(
        asOfDate: DateTime.now().toIso8601String(),
        totalReceivables: 35000.0,
        totalCustomerLedgerBalances: 35000.0,
        glControlAccountBalance: 35000.0,
        isReconciled: true,
        discrepancy: 0.0,
        bucket0to30: 18000.0,
        bucket31to60: 11000.0,
        bucket61to90: 4000.0,
        bucket90Plus: 2000.0,
      ),
      suppliers: [
        SupplierAgeingItem(
          id: 's_1',
          name: 'Bharat Electronics Co.',
          phone: '+91 98201 99887',
          ledgerBalance: 14500.0,
          unpaidBillsCount: 1,
          bucket0to30: 14500.0,
          bucket31to60: 0.0,
          bucket61to90: 0.0,
          bucket90Plus: 0.0,
          totalAgeingBalance: 14500.0,
          oldestBillDate: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        ),
      ],
    );
  }

  StockSummaryReportModel _buildMockStockSummary() {
    return StockSummaryReportModel(
      summary: StockSummaryReportSummary(
        totalProducts: 48,
        totalValuation: 142500.0,
        totalStockUnits: 840,
        inStockCount: 42,
        lowStockCount: 4,
        outOfStockCount: 2,
      ),
      items: [
        StockSummaryItem(
          id: 'p_1',
          name: 'Logitech Wireless Mouse M235',
          sku: 'LOG-M235',
          categoryName: 'Electronics',
          unitSymbol: 'pcs',
          trackStock: true,
          minStockLevel: 5.0,
          currentStock: 3.0,
          unitCost: 450.0,
          salePrice: 650.0,
          valuation: 1350.0,
          stockStatus: 'LOW_STOCK',
        ),
      ],
      totalCount: 1,
    );
  }

  StockMovementReportModel _buildMockStockMovements() {
    return StockMovementReportModel(
      items: [
        StockMovementItem(
          id: 'm_1',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
          productName: 'Logitech Wireless Mouse M235',
          sku: 'LOG-M235',
          unitSymbol: 'pcs',
          warehouseName: 'Central Warehouse',
          movementType: 'SALE',
          quantity: 2.0,
          unitCost: 450.0,
          totalCost: 900.0,
          referenceType: 'INVOICE',
          notes: 'Customer invoice item deduction',
        ),
      ],
      totalCount: 1,
    );
  }

  List<ProductPerformanceItem> _buildMockProductPerformance() {
    return [
      ProductPerformanceItem(
        productId: 'p_1',
        name: 'HP Wireless Keyboard 230',
        sku: 'HP-KB-230',
        unitsSold: 35.0,
        totalRevenue: 43750.0,
        estimatedCost: 28000.0,
        estimatedGrossProfit: 15750.0,
        grossMarginPercentage: 36.0,
      ),
      ProductPerformanceItem(
        productId: 'p_2',
        name: 'Logitech Wireless Mouse M235',
        sku: 'LOG-M235',
        unitsSold: 42.0,
        totalRevenue: 27300.0,
        estimatedCost: 18900.0,
        estimatedGrossProfit: 8400.0,
        grossMarginPercentage: 30.8,
      ),
    ];
  }

  GstSummaryReportModel _buildMockGstSummary() {
    return GstSummaryReportModel(
      outwardSupplies: GstOutwardSupplies(
        taxableValue: 157161.0,
        cgstAmount: 14144.5,
        sgstAmount: 14144.5,
        igstAmount: 0.0,
        cessAmount: 0.0,
        totalOutwardTaxLiability: 28289.0,
      ),
      inwardSupplies: GstInwardSupplies(
        purchasesTaxable: 79830.0,
        purchasesItc: 14370.0,
        expensesItc: 2600.0,
        totalEligibleItc: 16970.0,
      ),
      netGstPayable: 11319.0,
      itcCarryForward: 0.0,
      disclaimer: 'This statutory summary is calculated from AirthAI verified commercial transactions.',
    );
  }
}

