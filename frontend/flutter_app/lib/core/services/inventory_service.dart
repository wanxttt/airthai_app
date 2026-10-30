import 'dart:async';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../security/session_manager.dart';
import '../../features/inventory/models/inventory_models.dart';
import 'sales_service.dart'; // For ServiceResult

class InventoryService {
  InventoryService._();
  static final InventoryService instance = InventoryService._();

  // Mock in-memory state for devMock testing
  final List<ProductInventoryModel> _mockProducts = [
    const ProductInventoryModel(
      id: 'prod_001',
      name: 'Industrial Safety Helmet - Yellow',
      sku: 'SAFE-001',
      barcode: '8901234567890',
      categoryName: 'Safety Equipment',
      unitSymbol: 'PCS',
      trackStock: true,
      minStockLevel: 20.0,
      currentStock: 45.0,
      stockStatus: 'IN_STOCK',
      unitCost: 280.0,
      valuation: 12600.0,
    ),
    const ProductInventoryModel(
      id: 'prod_002',
      name: 'Heavy-Duty Power Drill 750W',
      sku: 'TOOL-002',
      barcode: '8909876543210',
      categoryName: 'Power Tools',
      unitSymbol: 'PCS',
      trackStock: true,
      minStockLevel: 5.0,
      currentStock: 3.0,
      stockStatus: 'LOW_STOCK',
      unitCost: 2100.0,
      valuation: 6300.0,
    ),
    const ProductInventoryModel(
      id: 'prod_003',
      name: 'LED Spotlight 50W Cool White',
      sku: 'ELEC-003',
      categoryName: 'Electricals',
      unitSymbol: 'PCS',
      trackStock: true,
      minStockLevel: 10.0,
      currentStock: 0.0,
      stockStatus: 'OUT_OF_STOCK',
      unitCost: 400.0,
      valuation: 0.0,
    ),
  ];

  final Map<String, List<StockMovementModel>> _mockMovements = {
    'prod_001': [
      StockMovementModel(
        id: 'mov_001',
        productId: 'prod_001',
        movementType: 'ADJUSTMENT_ADD',
        quantity: 20.0,
        unitCost: 280.0,
        notes: 'Opening Stock',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        warehouseName: 'Main Warehouse',
      ),
      StockMovementModel(
        id: 'mov_002',
        productId: 'prod_001',
        movementType: 'PURCHASE',
        quantity: 50.0,
        unitCost: 280.0,
        referenceType: 'PURCHASE',
        referenceId: 'pur_001',
        notes: 'Received via bill BILL-2026-001',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        warehouseName: 'Main Warehouse',
      ),
      StockMovementModel(
        id: 'mov_003',
        productId: 'prod_001',
        movementType: 'SALE',
        quantity: 25.0,
        unitCost: 280.0,
        referenceType: 'INVOICE',
        referenceId: 'inv_001',
        notes: 'Sold on invoice INV-2026-27-0001',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        warehouseName: 'Main Warehouse',
      ),
    ],
  };

  /// Alias for [getSummary] for semantic consistency across inventory and reporting callers.
  Future<ServiceResult<InventorySummaryModel>> getStockSummary() => getSummary();

  Future<ServiceResult<InventorySummaryModel>> getSummary() async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get(ApiConstants.inventorySummary);
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final summary = InventorySummaryModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: summary, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load inventory summary',
        statusCode: response.statusCode,
      );
    }

    // Mock
    await Future.delayed(const Duration(milliseconds: 100));
    final totalProducts = _mockProducts.length;
    final totalQty = _mockProducts.fold(0.0, (acc, p) => acc + p.currentStock);
    final lowStock = _mockProducts.where((p) => p.isLowStock).length;
    final outOfStock = _mockProducts.where((p) => p.isOutOfStock).length;
    final totalVal = _mockProducts.fold(0.0, (acc, p) => acc + p.valuation);

    return ServiceResult(
      success: true,
      data: InventorySummaryModel(
        totalProducts: totalProducts,
        totalStockQuantity: totalQty,
        lowStockCount: lowStock,
        outOfStockCount: outOfStock,
        totalValuation: totalVal,
        valuationMethod: 'WEIGHTED_AVERAGE_COST',
      ),
    );
  }

  Future<ServiceResult<List<ProductInventoryModel>>> getProducts({
    String? search,
    String? stockStatus,
    String? categoryId,
  }) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        if (search != null && search.isNotEmpty) 'search': search,
        if (stockStatus != null && stockStatus != 'ALL') 'stockStatus': stockStatus,
        if (categoryId != null) 'categoryId': categoryId,
      };

      final response = await ApiClient.instance.get(
        ApiConstants.inventoryProducts,
        queryParams: queryParams,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data!['data'] as List<dynamic>?)
                ?.map((j) => ProductInventoryModel.fromJson(j as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: list, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load products inventory',
        statusCode: response.statusCode,
      );
    }

    // Mock
    await Future.delayed(const Duration(milliseconds: 120));
    var filtered = List<ProductInventoryModel>.from(_mockProducts);

    if (stockStatus != null && stockStatus != 'ALL') {
      filtered = filtered.where((p) => p.stockStatus == stockStatus).toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(s) ||
            (p.sku?.toLowerCase().contains(s) ?? false);
      }).toList();
    }

    return ServiceResult(success: true, data: filtered);
  }

  Future<ServiceResult<List<StockMovementModel>>> getProductMovements(String productId) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get(
        '${ApiConstants.inventoryProducts}/$productId/movements',
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final movementsList = (response.data!['data']['movements'] as List<dynamic>?)
                ?.map((j) => StockMovementModel.fromJson(j as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: movementsList, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load product movements',
        statusCode: response.statusCode,
      );
    }

    // Mock
    await Future.delayed(const Duration(milliseconds: 100));
    final list = _mockMovements[productId] ?? [];
    return ServiceResult(success: true, data: list);
  }

  Future<ServiceResult<StockMovementModel>> recordAdjustment(Map<String, dynamic> data) =>
      createAdjustment(data);

  Future<ServiceResult<StockMovementModel>> createAdjustment(Map<String, dynamic> data) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.inventoryAdjustments,
        body: data,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final mov = StockMovementModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: mov, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to record stock adjustment',
        statusCode: response.statusCode,
      );
    }

    // Mock
    await Future.delayed(const Duration(milliseconds: 150));
    final prodId = data['productId']?.toString();
    final idx = _mockProducts.indexWhere((p) => p.id == prodId);
    if (idx == -1) {
      return const ServiceResult(success: false, errorMessage: 'Product not found.');
    }

    final p = _mockProducts[idx];
    final qty = (data['quantity'] as num).toDouble();
    final movType = data['movementType']?.toString() ?? 'ADJUSTMENT_ADD';
    final isReduction = movType == 'ADJUSTMENT_SUB' || movType == 'DAMAGE';

    if (isReduction && p.currentStock < qty) {
      return const ServiceResult(
        success: false,
        errorMessage: 'Cannot reduce stock below zero: negative stock is disallowed.',
      );
    }

    final newStock = isReduction ? p.currentStock - qty : p.currentStock + qty;
    final newStatus = newStock <= 0
        ? 'OUT_OF_STOCK'
        : (newStock <= p.minStockLevel ? 'LOW_STOCK' : 'IN_STOCK');

    _mockProducts[idx] = ProductInventoryModel(
      id: p.id,
      name: p.name,
      sku: p.sku,
      barcode: p.barcode,
      categoryName: p.categoryName,
      unitSymbol: p.unitSymbol,
      trackStock: p.trackStock,
      minStockLevel: p.minStockLevel,
      currentStock: newStock,
      stockStatus: newStatus,
      unitCost: p.unitCost,
      valuation: newStock * p.unitCost,
    );

    final mov = StockMovementModel(
      id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
      productId: p.id,
      movementType: movType,
      quantity: qty,
      unitCost: p.unitCost,
      referenceType: 'MANUAL_ADJUSTMENT',
      notes: data['reason']?.toString(),
      createdAt: DateTime.now(),
      warehouseName: 'Main Warehouse',
    );

    _mockMovements.putIfAbsent(p.id, () => []).insert(0, mov);
    return ServiceResult(success: true, data: mov);
  }
}
