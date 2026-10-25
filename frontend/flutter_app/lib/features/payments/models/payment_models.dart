import 'package:flutter/material.dart';

class PaymentAllocationModel {
  final String id;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? purchaseId;
  final String? billNumber;
  final double amount;

  const PaymentAllocationModel({
    required this.id,
    this.invoiceId,
    this.invoiceNumber,
    this.purchaseId,
    this.billNumber,
    required this.amount,
  });

  factory PaymentAllocationModel.fromJson(Map<String, dynamic> json) {
    return PaymentAllocationModel(
      id: json['id'] as String? ?? '',
      invoiceId: json['invoiceId'] as String?,
      invoiceNumber: json['invoice']?['invoiceNumber'] as String? ?? json['invoiceNumber'] as String?,
      purchaseId: json['purchaseId'] as String?,
      billNumber: json['purchase']?['billNumber'] as String? ?? json['billNumber'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (invoiceId != null) 'invoiceId': invoiceId,
      if (purchaseId != null) 'purchaseId': purchaseId,
      'amount': amount,
    };
  }
}

class PaymentModel {
  final String id;
  final String paymentNumber;
  final String paymentType; // 'CUSTOMER_RECEIPT' | 'SUPPLIER_PAYMENT'
  final String? customerId;
  final String? customerName;
  final String? supplierId;
  final String? supplierName;
  final DateTime paymentDate;
  final double amount;
  final String paymentMethod; // 'CASH' | 'UPI' | 'BANK_TRANSFER' | 'CHEQUE' | 'CARD'
  final String? referenceNumber;
  final String? notes;
  final List<PaymentAllocationModel> allocations;

  const PaymentModel({
    required this.id,
    required this.paymentNumber,
    required this.paymentType,
    this.customerId,
    this.customerName,
    this.supplierId,
    this.supplierName,
    required this.paymentDate,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
    this.allocations = const [],
  });

  bool get isCustomerReceipt => paymentType == 'CUSTOMER_RECEIPT';
  bool get isSupplierPayment => paymentType == 'SUPPLIER_PAYMENT';

  String get partyName {
    if (isCustomerReceipt) {
      return customerName ?? 'Walk-in Customer';
    }
    return supplierName ?? 'Supplier';
  }

  String get formattedMethod {
    switch (paymentMethod.toUpperCase()) {
      case 'CASH':
        return 'Cash';
      case 'UPI':
        return 'UPI';
      case 'BANK_TRANSFER':
        return 'Bank Transfer / NEFT';
      case 'CHEQUE':
        return 'Cheque';
      case 'CARD':
        return 'Credit / Debit Card';
      default:
        return paymentMethod;
    }
  }

  Color get typeColor {
    return isCustomerReceipt ? const Color(0xFF10B981) : Colors.blueGrey;
  }

  double get totalAllocated {
    return allocations.fold(0.0, (sum, a) => sum + a.amount);
  }

  double get unallocatedAmount {
    final unalloc = amount - totalAllocated;
    return unalloc > 0.001 ? unalloc : 0.0;
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final allocList = (json['allocations'] as List<dynamic>?)
            ?.map((a) => PaymentAllocationModel.fromJson(a as Map<String, dynamic>))
            .toList() ??
        const [];

    return PaymentModel(
      id: json['id'] as String? ?? '',
      paymentNumber: json['paymentNumber'] as String? ?? '',
      paymentType: json['paymentType'] as String? ?? 'CUSTOMER_RECEIPT',
      customerId: json['customerId'] as String?,
      customerName: json['customer']?['name'] as String? ?? json['customerName'] as String?,
      supplierId: json['supplierId'] as String?,
      supplierName: json['supplier']?['name'] as String? ?? json['supplierName'] as String?,
      paymentDate: json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      referenceNumber: json['referenceNumber'] as String?,
      notes: json['notes'] as String?,
      allocations: allocList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentNumber': paymentNumber,
      'paymentType': paymentType,
      if (customerId != null) 'customerId': customerId,
      if (supplierId != null) 'supplierId': supplierId,
      'paymentDate': paymentDate.toIso8601String(),
      'amount': amount,
      'paymentMethod': paymentMethod,
      if (referenceNumber != null) 'referenceNumber': referenceNumber,
      if (notes != null) 'notes': notes,
      'allocations': allocations.map((a) => a.toJson()).toList(),
    };
  }
}

class OutstandingInvoiceModel {
  final String id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double totalAmount;
  final double receivedAmount;
  final double balanceAmount;
  final String status;

  const OutstandingInvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.totalAmount,
    required this.receivedAmount,
    required this.balanceAmount,
    required this.status,
  });

  factory OutstandingInvoiceModel.fromJson(Map<String, dynamic> json) {
    return OutstandingInvoiceModel(
      id: json['id'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      invoiceDate: json['invoiceDate'] != null
          ? DateTime.tryParse(json['invoiceDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      receivedAmount: (json['receivedAmount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'ISSUED',
    );
  }
}

class OutstandingBillModel {
  final String id;
  final String billNumber;
  final DateTime billDate;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final String paymentStatus;

  const OutstandingBillModel({
    required this.id,
    required this.billNumber,
    required this.billDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.paymentStatus,
  });

  factory OutstandingBillModel.fromJson(Map<String, dynamic> json) {
    return OutstandingBillModel(
      id: json['id'] as String? ?? '',
      billNumber: json['billNumber'] as String? ?? '',
      billDate: json['billDate'] != null
          ? DateTime.tryParse(json['billDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['paymentStatus'] as String? ?? 'UNPAID',
    );
  }
}
