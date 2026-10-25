import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/service_result.dart';
import '../security/session_manager.dart';
import '../../features/payments/models/payment_models.dart';

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  int _nextReceiptSeq = 3;
  int _nextPaymentSeq = 2;

  // In-memory mock payments for DevMock mode
  final List<PaymentModel> _mockPayments = [
    PaymentModel(
      id: 'pay_mock_rec_001',
      paymentNumber: 'REC-2026-27-0001',
      paymentType: 'CUSTOMER_RECEIPT',
      customerId: 'cust_001',
      customerName: 'Shree Ganesh Hardware',
      paymentDate: DateTime.now().subtract(const Duration(days: 2)),
      amount: 5000.0,
      paymentMethod: 'UPI',
      referenceNumber: 'UPI/AXIS/2026102301',
      notes: 'Advance part-payment via GPay',
      allocations: [
        const PaymentAllocationModel(
          id: 'alloc_mock_001',
          invoiceId: 'inv_mock_001',
          invoiceNumber: 'INV-2026-27-0001',
          amount: 5000.0,
        ),
      ],
    ),
    PaymentModel(
      id: 'pay_mock_rec_002',
      paymentNumber: 'REC-2026-27-0002',
      paymentType: 'CUSTOMER_RECEIPT',
      customerId: 'cust_002',
      customerName: 'Om Sai Electricals',
      paymentDate: DateTime.now().subtract(const Duration(days: 1)),
      amount: 15000.0,
      paymentMethod: 'BANK_TRANSFER',
      referenceNumber: 'NEFT/HDFC/889922',
      notes: 'Full invoice settlement',
      allocations: [
        const PaymentAllocationModel(
          id: 'alloc_mock_002',
          invoiceId: 'inv_mock_002',
          invoiceNumber: 'INV-2026-27-0002',
          amount: 15000.0,
        ),
      ],
    ),
    PaymentModel(
      id: 'pay_mock_pay_001',
      paymentNumber: 'PAY-2026-27-0001',
      paymentType: 'SUPPLIER_PAYMENT',
      supplierId: 'supp_001',
      supplierName: 'Apex Industrial Parts Ltd',
      paymentDate: DateTime.now().subtract(const Duration(days: 3)),
      amount: 10000.0,
      paymentMethod: 'BANK_TRANSFER',
      referenceNumber: 'RTGS/SBI/445566',
      notes: 'Part payment for initial machinery purchase',
      allocations: [
        const PaymentAllocationModel(
          id: 'alloc_mock_003',
          purchaseId: 'pur_mock_001',
          billNumber: 'PB-2026-27-0001',
          amount: 10000.0,
        ),
      ],
    ),
  ];

  /// Get list of payments with optional filters
  Future<ServiceResult<List<PaymentModel>>> getPayments({
    String? paymentType,
    String? customerId,
    String? supplierId,
    String? paymentMethod,
    String? search,
    int page = 1,
  }) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        'page': page.toString(),
        if (paymentType != null && paymentType.isNotEmpty) 'paymentType': paymentType,
        if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
        if (supplierId != null && supplierId.isNotEmpty) 'supplierId': supplierId,
        if (paymentMethod != null && paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await ApiClient.instance.get(
        ApiConstants.payments,
        queryParams: queryParams,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data!['data'] as List<dynamic>?)
                ?.map((j) => PaymentModel.fromJson(j as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: list, statusCode: response.statusCode);
      }

      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load payments',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 100));
    var filtered = List<PaymentModel>.from(_mockPayments);

    if (paymentType != null && paymentType.isNotEmpty) {
      filtered = filtered.where((p) => p.paymentType == paymentType).toList();
    }
    if (customerId != null && customerId.isNotEmpty) {
      filtered = filtered.where((p) => p.customerId == customerId).toList();
    }
    if (supplierId != null && supplierId.isNotEmpty) {
      filtered = filtered.where((p) => p.supplierId == supplierId).toList();
    }
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      filtered = filtered.where((p) => p.paymentMethod == paymentMethod).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      filtered = filtered.where((p) {
        return p.paymentNumber.toLowerCase().contains(s) ||
            p.partyName.toLowerCase().contains(s) ||
            (p.referenceNumber?.toLowerCase().contains(s) ?? false) ||
            (p.notes?.toLowerCase().contains(s) ?? false);
      }).toList();
    }

    filtered.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return ServiceResult(success: true, data: filtered, statusCode: 200);
  }

  /// Get single payment details
  Future<ServiceResult<PaymentModel>> getPayment(String id) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get('${ApiConstants.payments}/$id');
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final payment = PaymentModel.fromJson(response.data!);
        return ServiceResult(success: true, data: payment, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Payment not found',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 80));
    final match = _mockPayments.where((p) => p.id == id).firstOrNull;
    if (match != null) {
      return ServiceResult(success: true, data: match, statusCode: 200);
    }
    return const ServiceResult(success: false, errorMessage: 'Payment not found', statusCode: 404);
  }

  /// Record Customer Receipt
  Future<ServiceResult<PaymentModel>> recordCustomerReceipt(Map<String, dynamic> payload) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.customerReceipts,
        body: payload,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final payment = PaymentModel.fromJson(response.data!);
        return ServiceResult(success: true, data: payment, statusCode: response.statusCode);
      }

      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to record customer receipt',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 150));
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0) {
      return const ServiceResult(
        success: false,
        errorMessage: 'Receipt amount must be greater than zero.',
        statusCode: 400,
      );
    }

    final rawAllocations = (payload['allocations'] as List<dynamic>?) ?? [];
    double totalAllocated = 0.0;
    final allocations = <PaymentAllocationModel>[];

    for (var i = 0; i < rawAllocations.length; i++) {
      final a = rawAllocations[i] as Map<String, dynamic>;
      final aAmount = (a['amount'] as num?)?.toDouble() ?? 0.0;
      if (aAmount > 0) {
        totalAllocated += aAmount;
        allocations.add(PaymentAllocationModel(
          id: 'alloc_mock_new_${DateTime.now().millisecondsSinceEpoch}_$i',
          invoiceId: a['invoiceId'] as String?,
          invoiceNumber: a['invoiceNumber'] as String? ?? 'INV-ALLOC-$i',
          amount: aAmount,
        ));
      }
    }

    if (totalAllocated > amount) {
      return ServiceResult(
        success: false,
        errorMessage:
            'Total allocated (₹${totalAllocated.toStringAsFixed(2)}) exceeds receipt amount (₹${amount.toStringAsFixed(2)}).',
        statusCode: 400,
      );
    }

    final seq = _nextReceiptSeq++;
    final paymentNumber = 'REC-2026-27-${seq.toString().padLeft(4, '0')}';

    final newPayment = PaymentModel(
      id: 'pay_rec_${DateTime.now().millisecondsSinceEpoch}',
      paymentNumber: paymentNumber,
      paymentType: 'CUSTOMER_RECEIPT',
      customerId: payload['customerId'] as String?,
      customerName: payload['customerName'] as String? ?? 'Valued Customer',
      paymentDate: payload['paymentDate'] != null
          ? DateTime.tryParse(payload['paymentDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      amount: amount,
      paymentMethod: payload['paymentMethod'] as String? ?? 'CASH',
      referenceNumber: payload['referenceNumber'] as String?,
      notes: payload['notes'] as String?,
      allocations: allocations,
    );

    _mockPayments.insert(0, newPayment);
    return ServiceResult(success: true, data: newPayment, statusCode: 201);
  }

  /// Record Supplier Payment
  Future<ServiceResult<PaymentModel>> recordSupplierPayment(Map<String, dynamic> payload) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.supplierPayments,
        body: payload,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final payment = PaymentModel.fromJson(response.data!);
        return ServiceResult(success: true, data: payment, statusCode: response.statusCode);
      }

      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to record supplier payment',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 150));
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0) {
      return const ServiceResult(
        success: false,
        errorMessage: 'Payment amount must be greater than zero.',
        statusCode: 400,
      );
    }

    final rawAllocations = (payload['allocations'] as List<dynamic>?) ?? [];
    double totalAllocated = 0.0;
    final allocations = <PaymentAllocationModel>[];

    for (var i = 0; i < rawAllocations.length; i++) {
      final a = rawAllocations[i] as Map<String, dynamic>;
      final aAmount = (a['amount'] as num?)?.toDouble() ?? 0.0;
      if (aAmount > 0) {
        totalAllocated += aAmount;
        allocations.add(PaymentAllocationModel(
          id: 'alloc_mock_new_${DateTime.now().millisecondsSinceEpoch}_$i',
          purchaseId: a['purchaseId'] as String?,
          billNumber: a['billNumber'] as String? ?? 'PB-ALLOC-$i',
          amount: aAmount,
        ));
      }
    }

    if (totalAllocated > amount) {
      return ServiceResult(
        success: false,
        errorMessage:
            'Total allocated (₹${totalAllocated.toStringAsFixed(2)}) exceeds payment amount (₹${amount.toStringAsFixed(2)}).',
        statusCode: 400,
      );
    }

    final seq = _nextPaymentSeq++;
    final paymentNumber = 'PAY-2026-27-${seq.toString().padLeft(4, '0')}';

    final newPayment = PaymentModel(
      id: 'pay_supp_${DateTime.now().millisecondsSinceEpoch}',
      paymentNumber: paymentNumber,
      paymentType: 'SUPPLIER_PAYMENT',
      supplierId: payload['supplierId'] as String?,
      supplierName: payload['supplierName'] as String? ?? 'Key Supplier',
      paymentDate: payload['paymentDate'] != null
          ? DateTime.tryParse(payload['paymentDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      amount: amount,
      paymentMethod: payload['paymentMethod'] as String? ?? 'BANK_TRANSFER',
      referenceNumber: payload['referenceNumber'] as String?,
      notes: payload['notes'] as String?,
      allocations: allocations,
    );

    _mockPayments.insert(0, newPayment);
    return ServiceResult(success: true, data: newPayment, statusCode: 201);
  }

  /// Void / Reverse a payment
  Future<ServiceResult<bool>> voidPayment(String id, String reason) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        '${ApiConstants.payments}/$id/void',
        body: {'reason': reason},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const ServiceResult(success: true, data: true, statusCode: 200);
      }

      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to void payment',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 100));
    _mockPayments.removeWhere((p) => p.id == id);
    return const ServiceResult(success: true, data: true, statusCode: 200);
  }

  /// Get outstanding invoices for a customer
  Future<ServiceResult<List<OutstandingInvoiceModel>>> getCustomerOutstanding(String customerId) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get('${ApiConstants.customerOutstanding}/$customerId');
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data!['outstandingInvoices'] as List<dynamic>?)
                ?.map((i) => OutstandingInvoiceModel.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: list, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load customer outstanding invoices',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 80));
    final mockInvoices = [
      OutstandingInvoiceModel(
        id: 'inv_mock_001',
        invoiceNumber: 'INV-2026-27-0001',
        invoiceDate: DateTime.now().subtract(const Duration(days: 5)),
        totalAmount: 17700.0,
        receivedAmount: 5000.0,
        balanceAmount: 12700.0,
        status: 'PARTIALLY_PAID',
      ),
      OutstandingInvoiceModel(
        id: 'inv_mock_003',
        invoiceNumber: 'INV-2026-27-0003',
        invoiceDate: DateTime.now().subtract(const Duration(days: 2)),
        totalAmount: 8500.0,
        receivedAmount: 0.0,
        balanceAmount: 8500.0,
        status: 'ISSUED',
      ),
    ];
    return ServiceResult(success: true, data: mockInvoices, statusCode: 200);
  }

  /// Get outstanding purchase bills for a supplier
  Future<ServiceResult<List<OutstandingBillModel>>> getSupplierOutstanding(String supplierId) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get('${ApiConstants.supplierOutstanding}/$supplierId');
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data!['outstandingBills'] as List<dynamic>?)
                ?.map((b) => OutstandingBillModel.fromJson(b as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: list, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load supplier outstanding bills',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 80));
    final mockBills = [
      OutstandingBillModel(
        id: 'pur_mock_001',
        billNumber: 'PB-2026-27-0001',
        billDate: DateTime.now().subtract(const Duration(days: 8)),
        totalAmount: 59000.0,
        paidAmount: 10000.0,
        balanceAmount: 49000.0,
        paymentStatus: 'PARTIALLY_PAID',
      ),
      OutstandingBillModel(
        id: 'pur_mock_002',
        billNumber: 'PB-2026-27-0002',
        billDate: DateTime.now().subtract(const Duration(days: 3)),
        totalAmount: 23600.0,
        paidAmount: 0.0,
        balanceAmount: 23600.0,
        paymentStatus: 'UNPAID',
      ),
    ];
    return ServiceResult(success: true, data: mockBills, statusCode: 200);
  }
}
