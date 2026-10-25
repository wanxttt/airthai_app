/// Master Data Domain Models for AirthAI Client
///
/// Phase 2 / MVP Prompt 2: Products, Categories, Units, Customers, Suppliers

class ProductModel {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final String? hsnCode;
  final String itemType;
  final bool trackStock;
  final double gstRate;
  final double cessRate;
  final double purchasePrice;
  final double salePrice;
  final double? mrp;
  final double minStockLevel;
  final double currentStock;
  final String status;
  final String? categoryId;
  final String? categoryName;
  final String? unitId;
  final String? unitSymbol;

  const ProductModel({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.hsnCode,
    this.itemType = 'GOODS',
    this.trackStock = true,
    this.gstRate = 0.0,
    this.cessRate = 0.0,
    this.purchasePrice = 0.0,
    this.salePrice = 0.0,
    this.mrp,
    this.minStockLevel = 0.0,
    this.currentStock = 0.0,
    this.status = 'ACTIVE',
    this.categoryId,
    this.categoryName,
    this.unitId,
    this.unitSymbol,
  });

  bool get isArchived => status == 'ARCHIVED';
  bool get isLowStock => trackStock && currentStock <= minStockLevel && currentStock > 0;
  bool get isOutOfStock => trackStock && currentStock <= 0;

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sku: map['sku']?.toString(),
      barcode: map['barcode']?.toString(),
      description: map['description']?.toString(),
      hsnCode: map['hsnCode']?.toString(),
      itemType: map['itemType']?.toString() ?? 'GOODS',
      trackStock: map['trackStock'] as bool? ?? true,
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 0.0,
      cessRate: (map['cessRate'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0.0,
      mrp: (map['mrp'] as num?)?.toDouble(),
      minStockLevel: (map['minStockLevel'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['currentStock'] as num?)?.toDouble() ?? 0.0,
      status: map['status']?.toString() ?? 'ACTIVE',
      categoryId: map['categoryId']?.toString(),
      categoryName: map['category']?['name']?.toString() ?? map['categoryName']?.toString(),
      unitId: map['unitId']?.toString(),
      unitSymbol: map['unit']?['symbol']?.toString() ?? map['unitSymbol']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'description': description,
        'hsnCode': hsnCode,
        'itemType': itemType,
        'trackStock': trackStock,
        'gstRate': gstRate,
        'cessRate': cessRate,
        'purchasePrice': purchasePrice,
        'salePrice': salePrice,
        'mrp': mrp,
        'minStockLevel': minStockLevel,
        'currentStock': currentStock,
        'status': status,
        'categoryId': categoryId,
        'unitId': unitId,
      };
}

class CategoryModel {
  final String id;
  final String name;
  final String? parentId;
  final int productCount;

  const CategoryModel({
    required this.id,
    required this.name,
    this.parentId,
    this.productCount = 0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      parentId: map['parentId']?.toString(),
      productCount: (map['_count']?['products'] as num?)?.toInt() ??
          (map['productCount'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parentId': parentId,
      };
}

class UnitModel {
  final String id;
  final String name;
  final String symbol;
  final int productCount;

  const UnitModel({
    required this.id,
    required this.name,
    required this.symbol,
    this.productCount = 0,
  });

  factory UnitModel.fromMap(Map<String, dynamic> map) {
    return UnitModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      symbol: map['symbol']?.toString() ?? '',
      productCount: (map['_count']?['products'] as num?)?.toInt() ??
          (map['productCount'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'symbol': symbol,
      };
}

class CustomerModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? billingAddress;
  final String? shippingAddress;
  final String? city;
  final String? state;
  final double openingBalance;
  final double currentBalance;
  final double? creditLimit;
  final int creditPeriodDays;
  final String status;

  const CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.gstin,
    this.billingAddress,
    this.shippingAddress,
    this.city,
    this.state,
    this.openingBalance = 0.0,
    this.currentBalance = 0.0,
    this.creditLimit,
    this.creditPeriodDays = 0,
    this.status = 'ACTIVE',
  });

  bool get isArchived => status == 'ARCHIVED';

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      gstin: map['gstin']?.toString(),
      billingAddress: map['billingAddress']?.toString(),
      shippingAddress: map['shippingAddress']?.toString(),
      city: map['city']?.toString(),
      state: map['state']?.toString(),
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['currentBalance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (map['creditLimit'] as num?)?.toDouble(),
      creditPeriodDays: (map['creditPeriodDays'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'billingAddress': billingAddress,
        'shippingAddress': shippingAddress,
        'city': city,
        'state': state,
        'openingBalance': openingBalance,
        'creditLimit': creditLimit,
        'creditPeriodDays': creditPeriodDays,
      };
}

class SupplierModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? pan;
  final String? address;
  final String? city;
  final String? state;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final double openingBalance;
  final double currentBalance;
  final String status;

  const SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.gstin,
    this.pan,
    this.address,
    this.city,
    this.state,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.openingBalance = 0.0,
    this.currentBalance = 0.0,
    this.status = 'ACTIVE',
  });

  bool get isArchived => status == 'ARCHIVED';

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      gstin: map['gstin']?.toString(),
      pan: map['pan']?.toString(),
      address: map['address']?.toString(),
      city: map['city']?.toString(),
      state: map['state']?.toString(),
      bankName: map['bankName']?.toString(),
      accountNumber: map['accountNumber']?.toString(),
      ifscCode: map['ifscCode']?.toString(),
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['currentBalance'] as num?)?.toDouble() ?? 0.0,
      status: map['status']?.toString() ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'pan': pan,
        'address': address,
        'city': city,
        'state': state,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'ifscCode': ifscCode,
        'openingBalance': openingBalance,
      };
}

