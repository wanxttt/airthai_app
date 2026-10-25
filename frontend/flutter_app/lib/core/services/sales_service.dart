import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../security/session_manager.dart';
import '../../features/sales/models/sales_models.dart';

import '../network/service_result.dart';
export '../network/service_result.dart';

class SalesService {
  SalesService._();
  static final SalesService instance = SalesService._();

  // Mock in-memory state for devMock testing
  final List<InvoiceModel> _mockInvoices = [
    InvoiceModel(
      id: 'inv_mock_001',
      invoiceNumber: 'INV-2026-27-0001',
      invoiceDate: DateTime.now().subtract(const Duration(days: 3)),
      dueDate: DateTime.now().add(const Duration(days: 27)),
      status: 'ISSUED',
      customerId: 'cust_001',
      customerName: 'Shree Ganesh Hardware',
      customerPhone: '9876543210',
      customerGstin: '27AABCS1234A1Z5',
      placeOfSupply: '27',
      isInterState: false,
      subtotal: 15000.0,
      taxableAmount: 15000.0,
      cgstAmount: 1350.0,
      sgstAmount: 1350.0,
      igstAmount: 0.0,
      roundOff: 0.0,
      totalAmount: 17700.0,
      receivedAmount: 0.0,
      balanceAmount: 17700.0,
      notes: 'Payment due in 30 days',
      items: [
        const InvoiceItemModel(
          id: 'item_001',
          productId: 'prod_001',
          description: 'Industrial Safety Helmet - Yellow',
          hsnCode: '650610',
          quantity: 20.0,
          unitPrice: 450.0,
          taxableAmount: 9000.0,
          gstRate: 18.0,
          cgstAmount: 810.0,
          sgstAmount: 810.0,
          totalAmount: 10620.0,
        ),
        const InvoiceItemModel(
          id: 'item_002',
          productId: 'prod_002',
          description: 'Heavy-Duty Power Drill 750W',
          hsnCode: '846721',
          quantity: 2.0,
          unitPrice: 3000.0,
          taxableAmount: 6000.0,
          gstRate: 18.0,
          cgstAmount: 540.0,
          sgstAmount: 540.0,
          totalAmount: 7080.0,
        ),
      ],
    ),
    InvoiceModel(
      id: 'inv_mock_002',
      invoiceNumber: 'INV-2026-27-0002',
      invoiceDate: DateTime.now().subtract(const Duration(days: 10)),
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
      status: 'PAID',
      customerId: 'cust_002',
      customerName: 'Mehta Electronics & Spares',
      customerPhone: '9899887766',
      customerGstin: '24AAECM4567B1Z8',
      placeOfSupply: '24', // Gujarat - Inter-state
      isInterState: true,
      subtotal: 4800.0,
      taxableAmount: 4800.0,
      cgstAmount: 0.0,
      sgstAmount: 0.0,
      igstAmount: 864.0,
      roundOff: 0.0,
      totalAmount: 5664.0,
      receivedAmount: 5664.0,
      balanceAmount: 0.0,
      notes: 'Paid via NEFT on 18-Oct-2026',
      items: [
        const InvoiceItemModel(
          id: 'item_003',
          productId: 'prod_003',
          description: 'LED Spotlight 50W Cool White',
          hsnCode: '940540',
          quantity: 8.0,
          unitPrice: 600.0,
          taxableAmount: 4800.0,
          gstRate: 18.0,
          igstAmount: 864.0,
          totalAmount: 5664.0,
        ),
      ],
    ),
  ];

  final List<QuotationModel> _mockQuotations = [
    QuotationModel(
      id: 'quo_mock_001',
      quotationNumber: 'QUO-2026-27-0001',
      date: DateTime.now().subtract(const Duration(days: 2)),
      validUntil: DateTime.now().add(const Duration(days: 12)),
      status: 'DRAFT',
      customerId: 'cust_001',
      customerName: 'Shree Ganesh Hardware',
      subtotal: 25000.0,
      taxAmount: 4500.0,
      totalAmount: 29500.0,
      notes: 'Special MSME bulk discount valid until end of month.',
      items: [
        const QuotationItemModel(
          id: 'qitem_001',
          productId: 'prod_001',
          description: 'Industrial Safety Helmet - Bulk Pack',
          quantity: 50.0,
          unitPrice: 400.0,
          taxAmount: 3600.0,
          totalAmount: 23600.0,
        ),
      ],
    ),
  ];

  int _nextInvoiceSeq = 3;
  int _nextQuoSeq = 2;

  // -------------------------------------------------------------
  // INVOICES
  // -------------------------------------------------------------

  Future<ServiceResult<List<InvoiceModel>>> getInvoices({
    String? search,
    String? status,
    String? customerId,
    int page = 1,
  }) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        'page': page.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status != 'ALL') 'status': status,
        if (customerId != null) 'customerId': customerId,
      };

      final response = await ApiClient.instance.get(
        ApiConstants.invoices,
        queryParams: queryParams,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data!['data'] as List<dynamic>?)
                ?.map((j) => InvoiceModel.fromJson(j as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: list, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load invoices',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock
    await Future.delayed(const Duration(milliseconds: 150));
    var filtered = List<InvoiceModel>.from(_mockInvoices);

    if (status != null && status != 'ALL') {
      filtered = filtered.where((i) => i.status == status).toList();
    }

    if (customerId != null) {
      filtered = filtered.where((i) => i.customerId == customerId).toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      filtered = filtered.where((i) {
        return i.invoiceNumber.toLowerCase().contains(s) ||
            (i.customerName?.toLowerCase().contains(s) ?? false) ||
            (i.customerPhone?.contains(s) ?? false);
      }).toList();
    }

    filtered.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
    return ServiceResult(success: true, data: filtered);
  }

  Future<ServiceResult<InvoiceModel>> getInvoice(String id) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get('${ApiConstants.invoices}/$id');
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final data = InvoiceModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: data, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Invoice not found',
        statusCode: response.statusCode,
      );
    }

    // Mock
    await Future.delayed(const Duration(milliseconds: 100));
    final invoice = _mockInvoices.firstWhere(
      (i) => i.id == id,
      orElse: () => throw Exception('Invoice not found'),
    );
    return ServiceResult(success: true, data: invoice);
  }

  Future<ServiceResult<InvoiceModel>> createInvoice(Map<String, dynamic> data) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.invoices,
        body: data,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final invoice = InvoiceModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: invoice, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to create invoice',
        statusCode: response.statusCode,
      );
    }

    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 200));

    final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
    if (itemsRaw.isEmpty) {
      return const ServiceResult(success: false, errorMessage: 'At least one line item is required.');
    }

    final placeOfSupply = data['placeOfSupply']?.toString() ?? '27';
    final isInterState = placeOfSupply != '27';

    double subtotal = 0.0;
    double taxable = 0.0;
    double cgst = 0.0;
    double sgst = 0.0;
    double igst = 0.0;

    final parsedItems = <InvoiceItemModel>[];
    for (int idx = 0; idx < itemsRaw.length; idx++) {
      final it = itemsRaw[idx] as Map<String, dynamic>;
      final qty = (it['quantity'] as num).toDouble();
      final price = (it['unitPrice'] as num).toDouble();
      final discount = (it['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final lineGross = qty * price;
      final lineTaxable = (lineGross - discount).clamp(0.0, double.infinity);
      final rate = (it['gstRate'] as num?)?.toDouble() ?? 18.0;

      double lineCgst = 0.0;
      double lineSgst = 0.0;
      double lineIgst = 0.0;

      if (isInterState) {
        lineIgst = lineTaxable * (rate / 100);
      } else {
        lineCgst = lineTaxable * (rate / 200);
        lineSgst = lineTaxable * (rate / 200);
      }

      final lineTotal = lineTaxable + lineCgst + lineSgst + lineIgst;

      subtotal += lineGross;
      taxable += lineTaxable;
      cgst += lineCgst;
      sgst += lineSgst;
      igst += lineIgst;

      parsedItems.add(
        InvoiceItemModel(
          id: 'item_mock_${DateTime.now().millisecondsSinceEpoch}_$idx',
          productId: it['productId']?.toString(),
          description: it['description']?.toString() ?? '',
          hsnCode: it['hsnCode']?.toString(),
          quantity: qty,
          unitPrice: price,
          discountAmount: discount,
          taxableAmount: lineTaxable,
          gstRate: rate,
          cgstAmount: lineCgst,
          sgstAmount: lineSgst,
          igstAmount: lineIgst,
          totalAmount: lineTotal,
        ),
      );
    }

    final invDiscount = (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final totalTax = cgst + sgst + igst;
    final rawTotal = (taxable - invDiscount) + totalTax;
    final roundedTotal = rawTotal.roundToDouble();
    final roundOff = roundedTotal - rawTotal;

    final seqStr = _nextInvoiceSeq.toString().padLeft(4, '0');
    _nextInvoiceSeq++;

    final newInvoice = InvoiceModel(
      id: 'inv_mock_${DateTime.now().millisecondsSinceEpoch}',
      invoiceNumber: 'INV-2026-27-$seqStr',
      invoiceDate: data['invoiceDate'] != null
          ? DateTime.tryParse(data['invoiceDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dueDate: data['dueDate'] != null
          ? DateTime.tryParse(data['dueDate'].toString())
          : null,
      status: 'ISSUED',
      customerId: data['customerId']?.toString(),
      customerName: data['customerName']?.toString() ?? 'Walk-in Customer',
      customerPhone: data['customerPhone']?.toString(),
      placeOfSupply: placeOfSupply,
      isInterState: isInterState,
      subtotal: subtotal,
      discountAmount: invDiscount,
      taxableAmount: taxable - invDiscount,
      cgstAmount: cgst,
      sgstAmount: sgst,
      igstAmount: igst,
      roundOff: roundOff,
      totalAmount: roundedTotal,
      balanceAmount: roundedTotal,
      notes: data['notes']?.toString(),
      terms: data['terms']?.toString(),
      items: parsedItems,
    );

    _mockInvoices.insert(0, newInvoice);
    return ServiceResult(success: true, data: newInvoice);
  }

  Future<ServiceResult<InvoiceModel>> cancelInvoice(String id, String reason) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.patch(
        '${ApiConstants.invoices}/$id/cancel',
        body: {'reason': reason},
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final invoice = InvoiceModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: invoice, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to cancel invoice',
        statusCode: response.statusCode,
      );
    }

    // Mock
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _mockInvoices.indexWhere((i) => i.id == id);
    if (idx == -1) {
      return const ServiceResult(success: false, errorMessage: 'Invoice not found.');
    }

    final old = _mockInvoices[idx];
    if (old.status == 'CANCELLED') {
      return const ServiceResult(success: false, errorMessage: 'Invoice is already cancelled.');
    }

    final updated = InvoiceModel(
      id: old.id,
      invoiceNumber: old.invoiceNumber,
      invoiceDate: old.invoiceDate,
      dueDate: old.dueDate,
      status: 'CANCELLED',
      customerId: old.customerId,
      customerName: old.customerName,
      customerPhone: old.customerPhone,
      customerGstin: old.customerGstin,
      placeOfSupply: old.placeOfSupply,
      isInterState: old.isInterState,
      subtotal: old.subtotal,
      discountAmount: old.discountAmount,
      taxableAmount: old.taxableAmount,
      cgstAmount: old.cgstAmount,
      sgstAmount: old.sgstAmount,
      igstAmount: old.igstAmount,
      cessAmount: old.cessAmount,
      roundOff: old.roundOff,
      totalAmount: old.totalAmount,
      receivedAmount: old.receivedAmount,
      balanceAmount: 0.0,
      notes: old.notes,
      terms: old.terms,
      cancelledAt: DateTime.now(),
      cancellationReason: reason,
      items: old.items,
    );

    _mockInvoices[idx] = updated;
    return ServiceResult(success: true, data: updated);
  }

  // -------------------------------------------------------------
  // QUOTATIONS
  // -------------------------------------------------------------

  Future<ServiceResult<List<QuotationModel>>> getQuotations({
    String? search,
    String? status,
  }) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status != 'ALL') 'status': status,
      };

      final response = await ApiClient.instance.get(
        ApiConstants.quotations,
        queryParams: queryParams,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data!['data'] as List<dynamic>?)
                ?.map((j) => QuotationModel.fromJson(j as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: list, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load quotations',
        statusCode: response.statusCode,
      );
    }

    // Mock
    await Future.delayed(const Duration(milliseconds: 150));
    var filtered = List<QuotationModel>.from(_mockQuotations);

    if (status != null && status != 'ALL') {
      filtered = filtered.where((q) => q.status == status).toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      filtered = filtered.where((q) {
        return q.quotationNumber.toLowerCase().contains(s) ||
            (q.customerName?.toLowerCase().contains(s) ?? false);
      }).toList();
    }

    return ServiceResult(success: true, data: filtered);
  }

  Future<ServiceResult<QuotationModel>> createQuotation(Map<String, dynamic> data) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.quotations,
        body: data,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final quotation = QuotationModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: quotation, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to create quotation',
        statusCode: response.statusCode,
      );
    }

    // Mock
    await Future.delayed(const Duration(milliseconds: 150));
    final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
    if (itemsRaw.isEmpty) {
      return const ServiceResult(success: false, errorMessage: 'At least one item required.');
    }

    double subtotal = 0.0;
    double taxAmount = 0.0;
    final parsedItems = <QuotationItemModel>[];

    for (int i = 0; i < itemsRaw.length; i++) {
      final it = itemsRaw[i] as Map<String, dynamic>;
      final qty = (it['quantity'] as num).toDouble();
      final price = (it['unitPrice'] as num).toDouble();
      final gross = qty * price;
      final discount = (it['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final taxable = (gross - discount).clamp(0.0, double.infinity);
      final rate = (it['gstRate'] as num?)?.toDouble() ?? 18.0;
      final tax = taxable * (rate / 100);
      final total = taxable + tax;

      subtotal += gross;
      taxAmount += tax;

      parsedItems.add(
        QuotationItemModel(
          id: 'qitem_${DateTime.now().millisecondsSinceEpoch}_$i',
          productId: it['productId']?.toString(),
          description: it['description']?.toString() ?? '',
          quantity: qty,
          unitPrice: price,
          discountAmount: discount,
          taxAmount: tax,
          totalAmount: total,
        ),
      );
    }

    final seqStr = _nextQuoSeq.toString().padLeft(4, '0');
    _nextQuoSeq++;

    final newQuo = QuotationModel(
      id: 'quo_mock_${DateTime.now().millisecondsSinceEpoch}',
      quotationNumber: 'QUO-2026-27-$seqStr',
      date: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 15)),
      status: 'DRAFT',
      customerId: data['customerId']?.toString(),
      customerName: data['customerName']?.toString() ?? 'Prospect',
      subtotal: subtotal,
      discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: taxAmount,
      totalAmount: subtotal + taxAmount,
      notes: data['notes']?.toString(),
      items: parsedItems,
    );

    _mockQuotations.insert(0, newQuo);
    return ServiceResult(success: true, data: newQuo);
  }

  Future<ServiceResult<InvoiceModel>> convertQuotationToInvoice(String id) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        '${ApiConstants.quotations}/$id/convert-to-invoice',
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final invoice = InvoiceModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: invoice, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to convert quotation',
        statusCode: response.statusCode,
      );
    }

    // Mock
    final quoIdx = _mockQuotations.indexWhere((q) => q.id == id);
    if (quoIdx == -1) {
      return const ServiceResult(success: false, errorMessage: 'Quotation not found.');
    }

    final quo = _mockQuotations[quoIdx];
    if (quo.isConverted) {
      return const ServiceResult(success: false, errorMessage: 'Quotation is already converted.');
    }

    // Mark quotation converted
    _mockQuotations[quoIdx] = QuotationModel(
      id: quo.id,
      quotationNumber: quo.quotationNumber,
      date: quo.date,
      validUntil: quo.validUntil,
      status: 'CONVERTED',
      customerId: quo.customerId,
      customerName: quo.customerName,
      subtotal: quo.subtotal,
      discountAmount: quo.discountAmount,
      taxAmount: quo.taxAmount,
      totalAmount: quo.totalAmount,
      notes: quo.notes,
      items: quo.items,
    );

    // Create Invoice from quotation data
    return await createInvoice({
      'customerId': quo.customerId,
      'customerName': quo.customerName,
      'notes': 'Converted from Quotation ${quo.quotationNumber}. ${quo.notes ?? ''}',
      'items': quo.items.map((it) => {
            'productId': it.productId,
            'description': it.description,
            'quantity': it.quantity,
            'unitPrice': it.unitPrice,
            'discountAmount': it.discountAmount,
            'gstRate': 18.0,
          }).toList(),
    });
  }
}

