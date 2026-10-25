import 'package:flutter/material.dart';

class InventorySummaryModel {
  final int totalProducts;
  final double totalStockQuantity;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalValuation;
  final String valuationMethod;

  const InventorySummaryModel({
    required this.totalProducts,
    required this.totalStockQuantity,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalValuation,
    this.valuationMethod = 'WEIGHTED_AVERAGE_COST',
  });

  factory InventorySummaryModel.fromJson(Map<String, dynamic> json) {
    return InventorySummaryModel(
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      totalStockQuantity: (json['totalStockQuantity'] as num?)?.toDouble() ?? 0.0,
      lowStockCount: (json['lowStockCount'] as num?)?.toInt() ?? 0,
      outOfStockCount: (json['outOfStockCount'] as num?)?.toInt() ?? 0,
      totalValuation: (json['totalValuation'] as num?)?.toDouble() ?? 0.0,
      valuationMethod: json['valuationMethod']?.toString() ?? 'WEIGHTED_AVERAGE_COST',
    );
  }
}

class ProductInventoryModel {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? categoryName;
  final String? unitSymbol;
  final bool trackStock;
  final double minStockLevel;
  final double currentStock;
  final String stockStatus; // 'IN_STOCK' | 'LOW_STOCK' | 'OUT_OF_STOCK'
  final double unitCost;
  final double valuation;

  const ProductInventoryModel({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.categoryName,
    this.unitSymbol,
    required this.trackStock,
    required this.minStockLevel,
    required this.currentStock,
    required this.stockStatus,
    required this.unitCost,
    required this.valuation,
  });

  bool get isOutOfStock => stockStatus == 'OUT_OF_STOCK' || currentStock <= 0;
  bool get isLowStock => stockStatus == 'LOW_STOCK';

  Color get statusColor {
    if (isOutOfStock) return Colors.red;
    if (isLowStock) return Colors.orange.shade800;
    return Colors.green;
  }

  factory ProductInventoryModel.fromJson(Map<String, dynamic> json) {
    return ProductInventoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString(),
      barcode: json['barcode']?.toString(),
      categoryName: json['categoryName']?.toString(),
      unitSymbol: json['unitSymbol']?.toString(),
      trackStock: json['trackStock'] == true,
      minStockLevel: (json['minStockLevel'] as num?)?.toDouble() ?? 0.0,
      currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0.0,
      stockStatus: json['stockStatus']?.toString() ?? 'IN_STOCK',
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
      valuation: (json['valuation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class StockMovementModel {
  final String id;
  final String productId;
  final String movementType;
  final double quantity;
  final double unitCost;
  final String? referenceType;
  final String? referenceId;
  final String? notes;
  final DateTime createdAt;
  final String? warehouseName;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.unitCost,
    this.referenceType,
    this.referenceId,
    this.notes,
    required this.createdAt,
    this.warehouseName,
  });

  bool get isPositive => [
        'PURCHASE',
        'SALE_RETURN',
        'ADJUSTMENT_ADD',
      ].contains(movementType);

  Color get typeColor {
    switch (movementType) {
      case 'PURCHASE':
        return Colors.green;
      case 'SALE':
        return Colors.blue;
      case 'SALE_RETURN':
        return Colors.purple;
      case 'PURCHASE_RETURN':
        return Colors.red;
      case 'ADJUSTMENT_ADD':
        return Colors.teal;
      case 'ADJUSTMENT_SUB':
      case 'DAMAGE':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    final wh = json['warehouse'] as Map<String, dynamic>?;

    return StockMovementModel(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      movementType: json['movementType']?.toString() ?? 'ADJUSTMENT_ADD',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
      referenceType: json['referenceType']?.toString(),
      referenceId: json['referenceId']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      warehouseName: wh?['name']?.toString() ?? json['warehouseName']?.toString(),
    );
  }
}
