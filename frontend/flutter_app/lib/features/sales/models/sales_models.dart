import 'package:flutter/material.dart';

class InvoiceItemModel {
  final String id;
  final String? productId;
  final String description;
  final String? hsnCode;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double taxableAmount;
  final double gstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double cessAmount;
  final double totalAmount;

  const InvoiceItemModel({
    required this.id,
    this.productId,
    required this.description,
    this.hsnCode,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0.0,
    required this.taxableAmount,
    required this.gstRate,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
    this.cessAmount = 0.0,
    required this.totalAmount,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString(),
      description: json['description']?.toString() ?? '',
      hsnCode: json['hsnCode']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (json['taxableAmount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
      cgstAmount: (json['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (json['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (json['igstAmount'] as num?)?.toDouble() ?? 0.0,
      cessAmount: (json['cessAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (productId != null) 'productId': productId,
        'description': description,
        if (hsnCode != null) 'hsnCode': hsnCode,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountAmount': discountAmount,
        'gstRate': gstRate,
      };
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String status;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerGstin;
  final String placeOfSupply;
  final bool isInterState;
  final bool isReverseCharge;
  final double subtotal;
  final double discountAmount;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double cessAmount;
  final double roundOff;
  final double totalAmount;
  final double receivedAmount;
  final double balanceAmount;
  final String? notes;
  final String? terms;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final List<InvoiceItemModel> items;

  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.dueDate,
    required this.status,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerGstin,
    required this.placeOfSupply,
    required this.isInterState,
    this.isReverseCharge = false,
    required this.subtotal,
    this.discountAmount = 0.0,
    required this.taxableAmount,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
    this.cessAmount = 0.0,
    this.roundOff = 0.0,
    required this.totalAmount,
    this.receivedAmount = 0.0,
    required this.balanceAmount,
    this.notes,
    this.terms,
    this.cancelledAt,
    this.cancellationReason,
    this.items = const [],
  });

  bool get isPaid => status == 'PAID' || balanceAmount <= 0.0;
  bool get isCancelled => status == 'CANCELLED';
  bool get isIssued => status == 'ISSUED';
  bool get isDraft => status == 'DRAFT';

  Color get statusColor {
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'ISSUED':
        return Colors.blue;
      case 'PARTIALLY_PAID':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      case 'DRAFT':
      default:
        return Colors.grey;
    }
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final customerData = json['customer'] as Map<String, dynamic>?;
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((it) => InvoiceItemModel.fromJson(it as Map<String, dynamic>))
            .toList() ??
        [];

    return InvoiceModel(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      invoiceDate: json['invoiceDate'] != null
          ? DateTime.tryParse(json['invoiceDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'].toString())
          : null,
      status: json['status']?.toString() ?? 'ISSUED',
      customerId: json['customerId']?.toString() ?? customerData?['id']?.toString(),
      customerName: customerData?['name']?.toString() ?? json['customerName']?.toString(),
      customerPhone: customerData?['phone']?.toString() ?? json['customerPhone']?.toString(),
      customerGstin: customerData?['gstin']?.toString() ?? json['customerGstin']?.toString(),
      placeOfSupply: json['placeOfSupply']?.toString() ?? '27',
      isInterState: json['isInterState'] == true,
      isReverseCharge: json['isReverseCharge'] == true,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (json['taxableAmount'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (json['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (json['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (json['igstAmount'] as num?)?.toDouble() ?? 0.0,
      cessAmount: (json['cessAmount'] as num?)?.toDouble() ?? 0.0,
      roundOff: (json['roundOff'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      receivedAmount: (json['receivedAmount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      terms: json['terms']?.toString(),
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'].toString())
          : null,
      cancellationReason: json['cancellationReason']?.toString(),
      items: itemsList,
    );
  }
}

class QuotationItemModel {
  final String id;
  final String? productId;
  final String description;
  final String? hsnCode;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;

  const QuotationItemModel({
    required this.id,
    this.productId,
    required this.description,
    this.hsnCode,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0.0,
    required this.taxAmount,
    required this.totalAmount,
  });

  factory QuotationItemModel.fromJson(Map<String, dynamic> json) {
    return QuotationItemModel(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString(),
      description: json['description']?.toString() ?? '',
      hsnCode: json['hsnCode']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class QuotationModel {
  final String id;
  final String quotationNumber;
  final DateTime date;
  final DateTime? validUntil;
  final String status;
  final String? customerId;
  final String? customerName;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final String? notes;
  final List<QuotationItemModel> items;

  const QuotationModel({
    required this.id,
    required this.quotationNumber,
    required this.date,
    this.validUntil,
    required this.status,
    this.customerId,
    this.customerName,
    required this.subtotal,
    this.discountAmount = 0.0,
    required this.taxAmount,
    required this.totalAmount,
    this.notes,
    this.items = const [],
  });

  bool get isConverted => status == 'CONVERTED';

  Color get statusColor {
    switch (status) {
      case 'CONVERTED':
        return Colors.green;
      case 'ACCEPTED':
        return Colors.blue;
      case 'REJECTED':
        return Colors.red;
      case 'SENT':
        return Colors.orange;
      case 'DRAFT':
      default:
        return Colors.grey;
    }
  }

  factory QuotationModel.fromJson(Map<String, dynamic> json) {
    final customerData = json['customer'] as Map<String, dynamic>?;
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((it) => QuotationItemModel.fromJson(it as Map<String, dynamic>))
            .toList() ??
        [];

    return QuotationModel(
      id: json['id']?.toString() ?? '',
      quotationNumber: json['quotationNumber']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      validUntil: json['validUntil'] != null
          ? DateTime.tryParse(json['validUntil'].toString())
          : null,
      status: json['status']?.toString() ?? 'DRAFT',
      customerId: json['customerId']?.toString() ?? customerData?['id']?.toString(),
      customerName: customerData?['name']?.toString() ?? json['customerName']?.toString(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      items: itemsList,
    );
  }
}
