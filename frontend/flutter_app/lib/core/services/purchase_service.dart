import 'dart:async';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../security/session_manager.dart';
import '../../features/purchases/models/purchase_models.dart';
import 'sales_service.dart'; // For ServiceResult

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  // Mock in-memory state for devMock testing
  final List<PurchaseModel> _mockPurchases = [
    PurchaseModel(
      id: 'pur_mock_001',
      billNumber: 'BILL-2026-001',
      billDate: DateTime.now().subtract(const Duration(days: 5)),
      status: 'RECEIVED',
      supplierId: 'supp_001',
      supplierName: 'Tata Steel Distribution',
      supplierGstin: '27AAACT2345C1Z8',
      subtotal: 50000.0,
      taxAmount: 9000.0,
      totalAmount: 59000.0,
      paidAmount: 0.0,
      balanceAmount: 59000.0,
      paymentStatus: 'UNPAID',
      notes: 'Delivered at Main Warehouse',
      items: [
        const PurchaseItemModel(
          id: 'pitem_001',
          productId: 'prod_001',
          description: 'Industrial Safety Helmet - Yellow',
          quantity: 100.0,
          unitCost: 280.0,
          taxRate: 18.0,
          taxAmount: 5040.0,
          totalAmount: 33040.0,
        ),
        const PurchaseItemModel(
          id: 'pitem_002',
          productId: 'prod_002',
          description: 'Heavy-Duty Power Drill 750W',
          quantity: 10.0,
          unitCost: 2200.0,
          taxRate: 18.0,
          taxAmount: 3960.0,
          totalAmount: 25960.0,
        ),
      ],
    ),
    PurchaseModel(
      id: 'pur_mock_002',
      billNumber: 'PO-2026-088',
      billDate: DateTime.now().subtract(const Duration(days: 1)),
      status: 'ORDERED',
      supplierId: 'supp_002',
      supplierName: 'Bharat Petroleum Commercial',
      subtotal: 12000.0,
      taxAmount: 2160.0,
      totalAmount: 14160.0,
      paidAmount: 0.0,
      balanceAmount: 14160.0,
      paymentStatus: 'UNPAID',
      notes: 'Expected delivery by Friday',
      items: [
        const PurchaseItemModel(
          id: 'pitem_003',
          productId: 'prod_003',
          description: 'LED Spotlight 50W Cool White',
          quantity: 30.0,
          unitCost: 400.0,
          taxRate: 18.0,
          taxAmount: 2160.0,
          totalAmount: 14160.0,
        ),
      ],
    ),
  ];

  Future<ServiceResult<List<PurchaseModel>>> getPurchases({
    String? search,
    String? status,
    String? supplierId,
    int page = 1,
  }) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        'page': page.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status != 'ALL') 'status': status,
        if (supplierId != null) 'supplierId': supplierId,
      };

      final response = await ApiClient.instance.get(
        ApiConstants.purchases,
        queryParams: queryParams,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data!['data'] as List<dynamic>?)
                ?.map((j) => PurchaseModel.fromJson(j as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: list, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load purchase bills',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock
    await Future.delayed(const Duration(milliseconds: 150));
    var filtered = List<PurchaseModel>.from(_mockPurchases);

    if (status != null && status != 'ALL') {
      filtered = filtered.where((p) => p.status == status).toList();
    }

    if (supplierId != null) {
      filtered = filtered.where((p) => p.supplierId == supplierId).toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      filtered = filtered.where((p) {
        return p.billNumber.toLowerCase().contains(s) ||
            (p.supplierName?.toLowerCase().contains(s) ?? false);
      }).toList();
    }

    filtered.sort((a, b) => b.billDate.compareTo(a.billDate));
    return ServiceResult(success: true, data: filtered);
  }

  Future<ServiceResult<PurchaseModel>> getPurchase(String id) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get('${ApiConstants.purchases}/$id');
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final data = PurchaseModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: data, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Purchase bill not found',
        statusCode: response.statusCode,
      );
    }

    await Future.delayed(const Duration(milliseconds: 100));
    final item = _mockPurchases.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Purchase not found'),
    );
    return ServiceResult(success: true, data: item);
  }

  Future<ServiceResult<PurchaseModel>> createPurchase(Map<String, dynamic> data) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.purchases,
        body: data,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final p = PurchaseModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: p, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to create purchase',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock
    await Future.delayed(const Duration(milliseconds: 200));
    final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
    if (itemsRaw.isEmpty) {
      return const ServiceResult(success: false, errorMessage: 'At least one line item required.');
    }

    double subtotal = 0.0;
    double taxAmount = 0.0;
    final parsedItems = <PurchaseItemModel>[];

    for (int i = 0; i < itemsRaw.length; i++) {
      final it = itemsRaw[i] as Map<String, dynamic>;
      final qty = (it['quantity'] as num).toDouble();
      final cost = (it['unitCost'] as num).toDouble();
      final gross = qty * cost;
      final rate = (it['taxRate'] as num?)?.toDouble() ?? 18.0;
      final tax = gross * (rate / 100.0);
      final total = gross + tax;

      subtotal += gross;
      taxAmount += tax;

      parsedItems.add(
        PurchaseItemModel(
          id: 'pitem_mock_${DateTime.now().millisecondsSinceEpoch}_$i',
          productId: it['productId']?.toString() ?? '',
          description: it['description']?.toString() ?? '',
          hsnCode: it['hsnCode']?.toString(),
          quantity: qty,
          unitCost: cost,
          taxRate: rate,
          taxAmount: tax,
          totalAmount: total,
        ),
      );
    }

    final totalAmount = subtotal + taxAmount;
    final status = data['status']?.toString() ?? 'RECEIVED';

    final newPurchase = PurchaseModel(
      id: 'pur_mock_${DateTime.now().millisecondsSinceEpoch}',
      billNumber: data['billNumber']?.toString() ?? 'BILL-${DateTime.now().millisecondsSinceEpoch}',
      billDate: data['billDate'] != null
          ? DateTime.tryParse(data['billDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: status,
      supplierId: data['supplierId']?.toString() ?? '',
      supplierName: data['supplierName']?.toString() ?? 'Supplier',
      subtotal: subtotal,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      balanceAmount: totalAmount,
      paymentStatus: 'UNPAID',
      notes: data['notes']?.toString(),
      items: parsedItems,
    );

    _mockPurchases.insert(0, newPurchase);
    return ServiceResult(success: true, data: newPurchase);
  }

  Future<ServiceResult<PurchaseModel>> receivePurchase(String id) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.patch('${ApiConstants.purchases}/$id/receive');
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final p = PurchaseModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: p, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to receive purchase',
        statusCode: response.statusCode,
      );
    }

    // Mock
    final idx = _mockPurchases.indexWhere((p) => p.id == id);
    if (idx == -1) {
      return const ServiceResult(success: false, errorMessage: 'Purchase not found.');
    }

    final old = _mockPurchases[idx];
    final updated = PurchaseModel(
      id: old.id,
      billNumber: old.billNumber,
      billDate: old.billDate,
      status: 'RECEIVED',
      supplierId: old.supplierId,
      supplierName: old.supplierName,
      supplierGstin: old.supplierGstin,
      subtotal: old.subtotal,
      taxAmount: old.taxAmount,
      totalAmount: old.totalAmount,
      paidAmount: old.paidAmount,
      balanceAmount: old.balanceAmount,
      paymentStatus: old.paymentStatus,
      notes: old.notes,
      items: old.items,
    );

    _mockPurchases[idx] = updated;
    return ServiceResult(success: true, data: updated);
  }

  Future<ServiceResult<PurchaseModel>> cancelPurchase(String id, [String reason = 'Cancelled by user']) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.patch(
        '${ApiConstants.purchases}/$id/cancel',
        body: {'reason': reason},
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final p = PurchaseModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: p, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to cancel purchase',
        statusCode: response.statusCode,
      );
    }

    // Mock
    final idx = _mockPurchases.indexWhere((p) => p.id == id);
    if (idx == -1) {
      return const ServiceResult(success: false, errorMessage: 'Purchase not found.');
    }

    final old = _mockPurchases[idx];
    if (old.status == 'CANCELLED') {
      return const ServiceResult(success: false, errorMessage: 'Purchase is already cancelled.');
    }

    final updated = PurchaseModel(
      id: old.id,
      billNumber: old.billNumber,
      billDate: old.billDate,
      status: 'CANCELLED',
      supplierId: old.supplierId,
      supplierName: old.supplierName,
      supplierGstin: old.supplierGstin,
      subtotal: old.subtotal,
      taxAmount: old.taxAmount,
      totalAmount: old.totalAmount,
      paidAmount: old.paidAmount,
      balanceAmount: 0.0,
      paymentStatus: old.paymentStatus,
      notes: (old.notes != null && old.notes!.isNotEmpty ? '${old.notes} | ' : '') + 'Cancelled: $reason',
      items: old.items,
    );

    _mockPurchases[idx] = updated;
    return ServiceResult(success: true, data: updated);
  }
}
