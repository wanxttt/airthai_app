import 'package:flutter/material.dart';

class PurchaseItemModel {
  final String id;
  final String productId;
  final String description;
  final String? hsnCode;
  final double quantity;
  final double unitCost;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;

  const PurchaseItemModel({
    required this.id,
    required this.productId,
    required this.description,
    this.hsnCode,
    required this.quantity,
    required this.unitCost,
    this.taxRate = 18.0,
    required this.taxAmount,
    required this.totalAmount,
  });

  factory PurchaseItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseItemModel(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      hsnCode: json['hsnCode']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 18.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'description': description,
        if (hsnCode != null) 'hsnCode': hsnCode,
        'quantity': quantity,
        'unitCost': unitCost,
        'taxRate': taxRate,
      };
}

class PurchaseModel {
  final String id;
  final String billNumber;
  final DateTime billDate;
  final String status;
  final String supplierId;
  final String? supplierName;
  final String? supplierGstin;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final String paymentStatus;
  final String? notes;
  final List<PurchaseItemModel> items;

  const PurchaseModel({
    required this.id,
    required this.billNumber,
    required this.billDate,
    required this.status,
    required this.supplierId,
    this.supplierName,
    this.supplierGstin,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.balanceAmount,
    this.paymentStatus = 'UNPAID',
    this.notes,
    this.items = const [],
  });

  bool get isReceived => status == 'RECEIVED';
  bool get isOrdered => status == 'ORDERED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isUnpaid => balanceAmount > 0;

  Color get statusColor {
    switch (status) {
      case 'RECEIVED':
        return Colors.green;
      case 'ORDERED':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    final supplierData = json['supplier'] as Map<String, dynamic>?;
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((it) => PurchaseItemModel.fromJson(it as Map<String, dynamic>))
            .toList() ??
        [];

    return PurchaseModel(
      id: json['id']?.toString() ?? '',
      billNumber: json['billNumber']?.toString() ?? '',
      billDate: json['billDate'] != null
          ? DateTime.tryParse(json['billDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status']?.toString() ?? 'RECEIVED',
      supplierId: json['supplierId']?.toString() ?? supplierData?['id']?.toString() ?? '',
      supplierName: supplierData?['name']?.toString() ?? json['supplierName']?.toString(),
      supplierGstin: supplierData?['gstin']?.toString() ?? json['supplierGstin']?.toString(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['paymentStatus']?.toString() ?? 'UNPAID',
      notes: json['notes']?.toString(),
      items: itemsList,
    );
  }
}
