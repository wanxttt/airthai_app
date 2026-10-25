import 'dart:async';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../security/session_manager.dart';
import '../../features/master_data/models/master_data_models.dart';

class MasterDataResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  const MasterDataResult({required this.success, this.data, this.errorMessage});

  factory MasterDataResult.success(T data) =>
      MasterDataResult(success: true, data: data);

  factory MasterDataResult.failure(String message) =>
      MasterDataResult(success: false, errorMessage: message);
}

class MasterDataService {
  final ApiClient _apiClient;

  MasterDataService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  static final MasterDataService instance = MasterDataService();

  // In-memory mock store for offline / dev mock mode
  final List<CategoryModel> _mockCategories = [
    const CategoryModel(id: 'cat-1', name: 'Electronics', productCount: 2),
    const CategoryModel(id: 'cat-2', name: 'Office Supplies', productCount: 1),
    const CategoryModel(id: 'cat-3', name: 'Groceries', productCount: 1),
  ];

  final List<UnitModel> _mockUnits = [
    const UnitModel(id: 'unit-1', name: 'Piece', symbol: 'pcs', productCount: 3),
    const UnitModel(id: 'unit-2', name: 'Kilogram', symbol: 'kg', productCount: 1),
    const UnitModel(id: 'unit-3', name: 'Box', symbol: 'box', productCount: 0),
  ];

  final List<ProductModel> _mockProducts = [
    const ProductModel(
      id: 'prod-1',
      name: 'Wireless Mouse',
      sku: 'WM-001',
      barcode: '8901234567890',
      description: '2.4GHz optical wireless mouse',
      hsnCode: '8471',
      categoryId: 'cat-1',
      categoryName: 'Electronics',
      unitId: 'unit-1',
      unitSymbol: 'pcs',
      salePrice: 450.0,
      purchasePrice: 280.0,
      mrp: 599.0,
      gstRate: 18.0,
      trackStock: true,
      currentStock: 35.0,
      minStockLevel: 10.0,
      status: 'ACTIVE',
    ),
    const ProductModel(
      id: 'prod-2',
      name: 'USB-C Fast Charger 65W',
      sku: 'CHG-65W',
      barcode: '8901234567891',
      description: 'GaN Dual Port Type-C fast adapter',
      hsnCode: '8504',
      categoryId: 'cat-1',
      categoryName: 'Electronics',
      unitId: 'unit-1',
      unitSymbol: 'pcs',
      salePrice: 1200.0,
      purchasePrice: 750.0,
      mrp: 1499.0,
      gstRate: 18.0,
      trackStock: true,
      currentStock: 4.0,
      minStockLevel: 5.0,
      status: 'ACTIVE',
    ),
    const ProductModel(
      id: 'prod-3',
      name: 'A4 Copier Paper 75GSM',
      sku: 'PPR-A4',
      barcode: '8901234567892',
      description: '500 sheets ream',
      hsnCode: '4802',
      categoryId: 'cat-2',
      categoryName: 'Office Supplies',
      unitId: 'unit-1',
      unitSymbol: 'pcs',
      salePrice: 280.0,
      purchasePrice: 210.0,
      gstRate: 12.0,
      trackStock: true,
      currentStock: 120.0,
      minStockLevel: 25.0,
      status: 'ACTIVE',
    ),
  ];

  final List<CustomerModel> _mockCustomers = [
    const CustomerModel(
      id: 'cust-1',
      name: 'Sharma Traders Pvt Ltd',
      phone: '9876543210',
      email: 'contact@sharmatraders.in',
      gstin: '27AAAAA0000A1Z5',
      billingAddress: '42 MG Road',
      city: 'Mumbai',
      state: 'Maharashtra',
      openingBalance: 5000.0,
      currentBalance: 12500.0,
      creditLimit: 50000.0,
      creditPeriodDays: 30,
      status: 'ACTIVE',
    ),
    const CustomerModel(
      id: 'cust-2',
      name: 'Patel Enterprises',
      phone: '9811223344',
      email: 'sales@patelent.com',
      gstin: '24BBBBB1111B2Z6',
      billingAddress: 'Shop 12, APMC Market',
      city: 'Ahmedabad',
      state: 'Gujarat',
      openingBalance: 0.0,
      currentBalance: 0.0,
      creditLimit: 25000.0,
      creditPeriodDays: 15,
      status: 'ACTIVE',
    ),
  ];

  final List<SupplierModel> _mockSuppliers = [
    const SupplierModel(
      id: 'supp-1',
      name: 'National Electronics Wholesale',
      phone: '9822334455',
      email: 'orders@nationalelec.com',
      gstin: '27CCCCC2222C3Z7',
      pan: 'ABCDE1234F',
      address: 'Lamington Road',
      city: 'Mumbai',
      state: 'Maharashtra',
      bankName: 'HDFC Bank',
      accountNumber: '5010022334455',
      ifscCode: 'HDFC0000123',
      openingBalance: 25000.0,
      currentBalance: 48000.0,
      status: 'ACTIVE',
    ),
  ];

  // ==========================================
  // PRODUCTS CRUD
  // ==========================================

  Future<MasterDataResult<List<ProductModel>>> getProducts({
    String? search,
    String? categoryId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
        if (status != null && status.isNotEmpty) 'status': status,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final path = '${ApiConstants.products}?$queryString';

      final res = await _apiClient.get(
        path,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        final list = (res.data!['data'] as List<dynamic>?) ?? [];
        final products = list
            .map((item) => ProductModel.fromMap(item as Map<String, dynamic>))
            .toList();
        return MasterDataResult.success(products);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to load products.');
    } else {
      // Mock mode
      await Future.delayed(const Duration(milliseconds: 150));
      var list = List<ProductModel>.from(_mockProducts);

      if (status != null && status != 'ALL') {
        list = list.where((p) => p.status == status).toList();
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        list = list.where((p) => p.categoryId == categoryId).toList();
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        list = list
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                (p.sku?.toLowerCase().contains(q) ?? false) ||
                (p.barcode?.toLowerCase().contains(q) ?? false))
            .toList();
      }
      return MasterDataResult.success(list);
    }
  }

  Future<MasterDataResult<ProductModel>> createProduct(
      Map<String, dynamic> payload) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.post(
        ApiConstants.products,
        body: payload,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(ProductModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to create product.');
    } else {
      await Future.delayed(const Duration(milliseconds: 150));
      final newProd = ProductModel.fromMap({
        'id': 'prod-${DateTime.now().millisecondsSinceEpoch}',
        ...payload,
        'currentStock': payload['openingStock'] ?? 0.0,
        'status': 'ACTIVE',
      });
      _mockProducts.insert(0, newProd);
      return MasterDataResult.success(newProd);
    }
  }

  Future<MasterDataResult<ProductModel>> updateProduct(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.patch(
        '${ApiConstants.products}/$id',
        body: payload,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(ProductModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to update product.');
    } else {
      await Future.delayed(const Duration(milliseconds: 150));
      final idx = _mockProducts.indexWhere((p) => p.id == id);
      if (idx == -1) return MasterDataResult.failure('Product not found.');
      final existing = _mockProducts[idx];
      final updated = ProductModel.fromMap({
        ...existing.toMap(),
        ...payload,
        'id': id,
      });
      _mockProducts[idx] = updated;
      return MasterDataResult.success(updated);
    }
  }

  Future<MasterDataResult<ProductModel>> toggleArchiveProduct(String id) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.patch(
        '${ApiConstants.products}/$id/archive',
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(ProductModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to archive product.');
    } else {
      final idx = _mockProducts.indexWhere((p) => p.id == id);
      if (idx == -1) return MasterDataResult.failure('Product not found.');
      final current = _mockProducts[idx];
      final newStatus = current.status == 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE';
      final updated = ProductModel.fromMap({
        ...current.toMap(),
        'status': newStatus,
      });
      _mockProducts[idx] = updated;
      return MasterDataResult.success(updated);
    }
  }

  Future<MasterDataResult<bool>> deleteProduct(String id) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.delete(
        '${ApiConstants.products}/$id',
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess) {
        return MasterDataResult.success(true);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to delete product.');
    } else {
      _mockProducts.removeWhere((p) => p.id == id);
      return MasterDataResult.success(true);
    }
  }

  // ==========================================
  // CATEGORIES CRUD
  // ==========================================

  Future<MasterDataResult<List<CategoryModel>>> getCategories() async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.get(
        ApiConstants.categories,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        final list = (res.data!['data'] as List<dynamic>?) ??
            (res.data is List ? res.data as List<dynamic> : []);
        final categories = list
            .map((item) => CategoryModel.fromMap(item as Map<String, dynamic>))
            .toList();
        return MasterDataResult.success(categories);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to load categories.');
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      return MasterDataResult.success(List.from(_mockCategories));
    }
  }

  Future<MasterDataResult<CategoryModel>> createCategory(
    String name, {
    String? parentId,
  }) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.post(
        ApiConstants.categories,
        body: {'name': name, if (parentId != null) 'parentId': parentId},
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(CategoryModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to create category.');
    } else {
      final newCat = CategoryModel(
        id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        parentId: parentId,
      );
      _mockCategories.add(newCat);
      return MasterDataResult.success(newCat);
    }
  }

  Future<MasterDataResult<bool>> deleteCategory(String id) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.delete(
        '${ApiConstants.categories}/$id',
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess) {
        return MasterDataResult.success(true);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to delete category.');
    } else {
      _mockCategories.removeWhere((c) => c.id == id);
      return MasterDataResult.success(true);
    }
  }

  // ==========================================
  // UNITS CRUD
  // ==========================================

  Future<MasterDataResult<List<UnitModel>>> getUnits() async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.get(
        ApiConstants.units,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        final list = (res.data!['data'] as List<dynamic>?) ??
            (res.data is List ? res.data as List<dynamic> : []);
        final units = list
            .map((item) => UnitModel.fromMap(item as Map<String, dynamic>))
            .toList();
        return MasterDataResult.success(units);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to load units.');
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      return MasterDataResult.success(List.from(_mockUnits));
    }
  }

  Future<MasterDataResult<UnitModel>> createUnit(
    String name,
    String symbol,
  ) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.post(
        ApiConstants.units,
        body: {'name': name, 'symbol': symbol},
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(UnitModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to create unit.');
    } else {
      final newUnit = UnitModel(
        id: 'unit-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        symbol: symbol,
      );
      _mockUnits.add(newUnit);
      return MasterDataResult.success(newUnit);
    }
  }

  Future<MasterDataResult<bool>> deleteUnit(String id) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.delete(
        '${ApiConstants.units}/$id',
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess) {
        return MasterDataResult.success(true);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to delete unit.');
    } else {
      _mockUnits.removeWhere((u) => u.id == id);
      return MasterDataResult.success(true);
    }
  }

  // ==========================================
  // CUSTOMERS CRUD
  // ==========================================

  Future<MasterDataResult<List<CustomerModel>>> getCustomers({
    String? search,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final path = '${ApiConstants.customers}?$queryString';

      final res = await _apiClient.get(
        path,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        final list = (res.data!['data'] as List<dynamic>?) ?? [];
        final customers = list
            .map((item) => CustomerModel.fromMap(item as Map<String, dynamic>))
            .toList();
        return MasterDataResult.success(customers);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to load customers.');
    } else {
      await Future.delayed(const Duration(milliseconds: 150));
      var list = List<CustomerModel>.from(_mockCustomers);
      if (status != null && status != 'ALL') {
        list = list.where((c) => c.status == status).toList();
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        list = list
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                (c.phone?.toLowerCase().contains(q) ?? false) ||
                (c.gstin?.toLowerCase().contains(q) ?? false))
            .toList();
      }
      return MasterDataResult.success(list);
    }
  }

  Future<MasterDataResult<CustomerModel>> createCustomer(
      Map<String, dynamic> payload) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.post(
        ApiConstants.customers,
        body: payload,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(CustomerModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to create customer.');
    } else {
      await Future.delayed(const Duration(milliseconds: 150));
      final newCust = CustomerModel.fromMap({
        'id': 'cust-${DateTime.now().millisecondsSinceEpoch}',
        ...payload,
        'currentBalance': payload['openingBalance'] ?? 0.0,
        'status': 'ACTIVE',
      });
      _mockCustomers.insert(0, newCust);
      return MasterDataResult.success(newCust);
    }
  }

  Future<MasterDataResult<CustomerModel>> updateCustomer(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.patch(
        '${ApiConstants.customers}/$id',
        body: payload,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(CustomerModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to update customer.');
    } else {
      final idx = _mockCustomers.indexWhere((c) => c.id == id);
      if (idx == -1) return MasterDataResult.failure('Customer not found.');
      final current = _mockCustomers[idx];
      final updated = CustomerModel.fromMap({
        ...current.toMap(),
        ...payload,
        'id': id,
      });
      _mockCustomers[idx] = updated;
      return MasterDataResult.success(updated);
    }
  }

  Future<MasterDataResult<CustomerModel>> toggleArchiveCustomer(String id) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.patch(
        '${ApiConstants.customers}/$id/archive',
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(CustomerModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to archive customer.');
    } else {
      final idx = _mockCustomers.indexWhere((c) => c.id == id);
      if (idx == -1) return MasterDataResult.failure('Customer not found.');
      final current = _mockCustomers[idx];
      final newStatus = current.status == 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE';
      final updated = CustomerModel.fromMap({
        ...current.toMap(),
        'status': newStatus,
      });
      _mockCustomers[idx] = updated;
      return MasterDataResult.success(updated);
    }
  }

  Future<MasterDataResult<bool>> deleteCustomer(String id) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.delete(
        '${ApiConstants.customers}/$id',
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess) {
        return MasterDataResult.success(true);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to delete customer.');
    } else {
      _mockCustomers.removeWhere((c) => c.id == id);
      return MasterDataResult.success(true);
    }
  }

  // ==========================================
  // SUPPLIERS CRUD
  // ==========================================

  Future<MasterDataResult<List<SupplierModel>>> getSuppliers({
    String? search,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final path = '${ApiConstants.suppliers}?$queryString';

      final res = await _apiClient.get(
        path,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        final list = (res.data!['data'] as List<dynamic>?) ?? [];
        final suppliers = list
            .map((item) => SupplierModel.fromMap(item as Map<String, dynamic>))
            .toList();
        return MasterDataResult.success(suppliers);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to load suppliers.');
    } else {
      await Future.delayed(const Duration(milliseconds: 150));
      var list = List<SupplierModel>.from(_mockSuppliers);
      if (status != null && status != 'ALL') {
        list = list.where((s) => s.status == status).toList();
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        list = list
            .where((s) =>
                s.name.toLowerCase().contains(q) ||
                (s.phone?.toLowerCase().contains(q) ?? false) ||
                (s.gstin?.toLowerCase().contains(q) ?? false) ||
                (s.pan?.toLowerCase().contains(q) ?? false))
            .toList();
      }
      return MasterDataResult.success(list);
    }
  }

  Future<MasterDataResult<SupplierModel>> createSupplier(
      Map<String, dynamic> payload) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.post(
        ApiConstants.suppliers,
        body: payload,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(SupplierModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to create supplier.');
    } else {
      await Future.delayed(const Duration(milliseconds: 150));
      final newSupp = SupplierModel.fromMap({
        'id': 'supp-${DateTime.now().millisecondsSinceEpoch}',
        ...payload,
        'currentBalance': payload['openingBalance'] ?? 0.0,
        'status': 'ACTIVE',
      });
      _mockSuppliers.insert(0, newSupp);
      return MasterDataResult.success(newSupp);
    }
  }

  Future<MasterDataResult<SupplierModel>> updateSupplier(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.patch(
        '${ApiConstants.suppliers}/$id',
        body: payload,
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(SupplierModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to update supplier.');
    } else {
      final idx = _mockSuppliers.indexWhere((s) => s.id == id);
      if (idx == -1) return MasterDataResult.failure('Supplier not found.');
      final current = _mockSuppliers[idx];
      final updated = SupplierModel.fromMap({
        ...current.toMap(),
        ...payload,
        'id': id,
      });
      _mockSuppliers[idx] = updated;
      return MasterDataResult.success(updated);
    }
  }

  Future<MasterDataResult<SupplierModel>> toggleArchiveSupplier(String id) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.patch(
        '${ApiConstants.suppliers}/$id/archive',
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess && res.data != null) {
        return MasterDataResult.success(SupplierModel.fromMap(res.data!));
      }
      return MasterDataResult.failure(res.message ?? 'Failed to archive supplier.');
    } else {
      final idx = _mockSuppliers.indexWhere((s) => s.id == id);
      if (idx == -1) return MasterDataResult.failure('Supplier not found.');
      final current = _mockSuppliers[idx];
      final newStatus = current.status == 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE';
      final updated = SupplierModel.fromMap({
        ...current.toMap(),
        'status': newStatus,
      });
      _mockSuppliers[idx] = updated;
      return MasterDataResult.success(updated);
    }
  }

  Future<MasterDataResult<bool>> deleteSupplier(String id) async {
    if (SessionManager.instance.authMode == AuthMode.restBackend) {
      final res = await _apiClient.delete(
        '${ApiConstants.suppliers}/$id',
        token: SessionManager.instance.currentSession?.token,
      );

      if (res.isSuccess) {
        return MasterDataResult.success(true);
      }
      return MasterDataResult.failure(res.message ?? 'Failed to delete supplier.');
    } else {
      _mockSuppliers.removeWhere((s) => s.id == id);
      return MasterDataResult.success(true);
    }
  }
}

