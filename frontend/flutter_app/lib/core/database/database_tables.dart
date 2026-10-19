/// AirthAI Local Database Table Definitions & Schema
///
/// Phase 2: Database + Domain Model
/// Authoritative offline-first SQLite representation mirroring the server-side
/// PostgreSQL Prisma schema (`backend/api/prisma/schema.prisma`).
///
/// Every local tenant table contains:
/// - `business_id`: Strict multi-tenant isolation.
/// - `sync_status`: 0=Synced, 1=Pending_Insert, 2=Pending_Update, 3=Pending_Delete, 4=Conflict.
/// - `client_operation_id`: Idempotency UUID generated at transaction origination.
/// - `server_version`: Optimistic locking / sync conflict detection version.
/// - `created_at` / `updated_at` / `deleted_at`: Timestamp tracking (with soft-delete support).
library;

// ============================================================================
// SYNC & DOMAIN ENUMS
// ============================================================================

enum SyncStatus {
  synced(0),
  pendingInsert(1),
  pendingUpdate(2),
  pendingDelete(3),
  conflict(4);

  final int code;
  const SyncStatus(this.code);

  static SyncStatus fromCode(int code) {
    return SyncStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => SyncStatus.synced,
    );
  }
}

enum LocalTaxType {
  unregistered,
  regular,
  composition;

  static LocalTaxType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'UNREGISTERED':
        return LocalTaxType.unregistered;
      case 'COMPOSITION':
        return LocalTaxType.composition;
      case 'REGULAR':
      default:
        return LocalTaxType.regular;
    }
  }

  String toDbString() => name.toUpperCase();
}

enum LocalBillFormat {
  a4Standard,
  a5Compact,
  thermal80mm,
  thermal58mm;

  static LocalBillFormat fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'A5_COMPACT':
        return LocalBillFormat.a5Compact;
      case 'THERMAL_80MM':
        return LocalBillFormat.thermal80mm;
      case 'THERMAL_58MM':
        return LocalBillFormat.thermal58mm;
      case 'A4_STANDARD':
      default:
        return LocalBillFormat.a4Standard;
    }
  }

  String toDbString() {
    switch (this) {
      case LocalBillFormat.a4Standard:
        return 'A4_STANDARD';
      case LocalBillFormat.a5Compact:
        return 'A5_COMPACT';
      case LocalBillFormat.thermal80mm:
        return 'THERMAL_80MM';
      case LocalBillFormat.thermal58mm:
        return 'THERMAL_58MM';
    }
  }
}

enum LocalItemType {
  goods,
  service;

  static LocalItemType fromString(String? val) {
    return val?.toUpperCase() == 'SERVICE'
        ? LocalItemType.service
        : LocalItemType.goods;
  }

  String toDbString() => name.toUpperCase();
}

enum LocalInvoiceStatus {
  draft,
  issued,
  partiallyPaid,
  paid,
  cancelled;

  static LocalInvoiceStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'DRAFT':
        return LocalInvoiceStatus.draft;
      case 'PARTIALLY_PAID':
        return LocalInvoiceStatus.partiallyPaid;
      case 'PAID':
        return LocalInvoiceStatus.paid;
      case 'CANCELLED':
        return LocalInvoiceStatus.cancelled;
      case 'ISSUED':
      default:
        return LocalInvoiceStatus.issued;
    }
  }

  String toDbString() {
    switch (this) {
      case LocalInvoiceStatus.draft:
        return 'DRAFT';
      case LocalInvoiceStatus.issued:
        return 'ISSUED';
      case LocalInvoiceStatus.partiallyPaid:
        return 'PARTIALLY_PAID';
      case LocalInvoiceStatus.paid:
        return 'PAID';
      case LocalInvoiceStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

enum LocalPurchaseStatus {
  ordered,
  received,
  cancelled;

  static LocalPurchaseStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'ORDERED':
        return LocalPurchaseStatus.ordered;
      case 'CANCELLED':
        return LocalPurchaseStatus.cancelled;
      case 'RECEIVED':
      default:
        return LocalPurchaseStatus.received;
    }
  }

  String toDbString() => name.toUpperCase();
}

enum LocalPaymentType {
  customerReceipt,
  supplierPayment;

  static LocalPaymentType fromString(String? val) {
    return val?.toUpperCase() == 'SUPPLIER_PAYMENT'
        ? LocalPaymentType.supplierPayment
        : LocalPaymentType.customerReceipt;
  }

  String toDbString() {
    return this == LocalPaymentType.supplierPayment
        ? 'SUPPLIER_PAYMENT'
        : 'CUSTOMER_RECEIPT';
  }
}

enum LocalPaymentMethod {
  cash,
  upi,
  bankTransfer,
  cheque,
  card;

  static LocalPaymentMethod fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'UPI':
        return LocalPaymentMethod.upi;
      case 'BANK_TRANSFER':
        return LocalPaymentMethod.bankTransfer;
      case 'CHEQUE':
        return LocalPaymentMethod.cheque;
      case 'CARD':
        return LocalPaymentMethod.card;
      case 'CASH':
      default:
        return LocalPaymentMethod.cash;
    }
  }

  String toDbString() {
    switch (this) {
      case LocalPaymentMethod.cash:
        return 'CASH';
      case LocalPaymentMethod.upi:
        return 'UPI';
      case LocalPaymentMethod.bankTransfer:
        return 'BANK_TRANSFER';
      case LocalPaymentMethod.cheque:
        return 'CHEQUE';
      case LocalPaymentMethod.card:
        return 'CARD';
    }
  }
}

enum LocalPaymentStatus {
  unpaid,
  partiallyPaid,
  paid;

  static LocalPaymentStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'PARTIALLY_PAID':
        return LocalPaymentStatus.partiallyPaid;
      case 'PAID':
        return LocalPaymentStatus.paid;
      case 'UNPAID':
      default:
        return LocalPaymentStatus.unpaid;
    }
  }

  String toDbString() {
    switch (this) {
      case LocalPaymentStatus.unpaid:
        return 'UNPAID';
      case LocalPaymentStatus.partiallyPaid:
        return 'PARTIALLY_PAID';
      case LocalPaymentStatus.paid:
        return 'PAID';
    }
  }
}

enum LocalStockMovementType {
  purchase,
  sale,
  saleReturn,
  purchaseReturn,
  adjustmentAdd,
  adjustmentSub,
  damage,
  transfer;

  static LocalStockMovementType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'PURCHASE':
        return LocalStockMovementType.purchase;
      case 'SALE':
        return LocalStockMovementType.sale;
      case 'SALE_RETURN':
        return LocalStockMovementType.saleReturn;
      case 'PURCHASE_RETURN':
        return LocalStockMovementType.purchaseReturn;
      case 'ADJUSTMENT_ADD':
        return LocalStockMovementType.adjustmentAdd;
      case 'ADJUSTMENT_SUB':
        return LocalStockMovementType.adjustmentSub;
      case 'DAMAGE':
        return LocalStockMovementType.damage;
      case 'TRANSFER':
        return LocalStockMovementType.transfer;
      default:
        return LocalStockMovementType.sale;
    }
  }

  String toDbString() {
    switch (this) {
      case LocalStockMovementType.purchase:
        return 'PURCHASE';
      case LocalStockMovementType.sale:
        return 'SALE';
      case LocalStockMovementType.saleReturn:
        return 'SALE_RETURN';
      case LocalStockMovementType.purchaseReturn:
        return 'PURCHASE_RETURN';
      case LocalStockMovementType.adjustmentAdd:
        return 'ADJUSTMENT_ADD';
      case LocalStockMovementType.adjustmentSub:
        return 'ADJUSTMENT_SUB';
      case LocalStockMovementType.damage:
        return 'DAMAGE';
      case LocalStockMovementType.transfer:
        return 'TRANSFER';
    }
  }
}

// ============================================================================
// SQLITE DDL SCHEMA DEFINITIONS
// ============================================================================

class LocalDatabaseDdl {
  const LocalDatabaseDdl._();

  static const List<String> createTables = [
    '''
    CREATE TABLE IF NOT EXISTS local_businesses (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      legal_name TEXT,
      gstin TEXT,
      pan TEXT,
      phone TEXT,
      email TEXT,
      address_line1 TEXT,
      address_line2 TEXT,
      city TEXT,
      state TEXT,
      state_code TEXT,
      pincode TEXT,
      currency TEXT NOT NULL DEFAULT 'INR',
      tax_type TEXT NOT NULL DEFAULT 'REGULAR',
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_business_settings (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL UNIQUE,
      track_inventory INTEGER NOT NULL DEFAULT 1,
      allow_negative_stock INTEGER NOT NULL DEFAULT 0,
      default_bill_format TEXT NOT NULL DEFAULT 'A4_STANDARD',
      enable_gst INTEGER NOT NULL DEFAULT 1,
      default_gst_rate REAL NOT NULL DEFAULT 18.00,
      financial_year_start TEXT NOT NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE CASCADE
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_customers (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      gstin TEXT,
      billing_address TEXT,
      shipping_address TEXT,
      city TEXT,
      state TEXT,
      state_code TEXT,
      pincode TEXT,
      opening_balance REAL NOT NULL DEFAULT 0.00,
      current_balance REAL NOT NULL DEFAULT 0.00,
      credit_limit REAL,
      credit_period_days INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'ACTIVE',
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_suppliers (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      gstin TEXT,
      pan TEXT,
      address TEXT,
      city TEXT,
      state TEXT,
      state_code TEXT,
      bank_name TEXT,
      account_number TEXT,
      ifsc_code TEXT,
      opening_balance REAL NOT NULL DEFAULT 0.00,
      current_balance REAL NOT NULL DEFAULT 0.00,
      status TEXT NOT NULL DEFAULT 'ACTIVE',
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_categories (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      name TEXT NOT NULL,
      parent_id TEXT,
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT,
      FOREIGN KEY (parent_id) REFERENCES local_categories(id) ON DELETE SET NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_units (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      name TEXT NOT NULL,
      symbol TEXT NOT NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_products (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      category_id TEXT,
      unit_id TEXT,
      name TEXT NOT NULL,
      sku TEXT,
      barcode TEXT,
      description TEXT,
      hsn_code TEXT,
      item_type TEXT NOT NULL DEFAULT 'GOODS',
      track_stock INTEGER NOT NULL DEFAULT 1,
      gst_rate REAL NOT NULL DEFAULT 0.00,
      cess_rate REAL NOT NULL DEFAULT 0.00,
      purchase_price REAL NOT NULL DEFAULT 0.00,
      sale_price REAL NOT NULL DEFAULT 0.00,
      mrp REAL,
      min_stock_level REAL NOT NULL DEFAULT 0.00,
      current_stock REAL NOT NULL DEFAULT 0.00,
      status TEXT NOT NULL DEFAULT 'ACTIVE',
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT,
      FOREIGN KEY (category_id) REFERENCES local_categories(id) ON DELETE RESTRICT,
      FOREIGN KEY (unit_id) REFERENCES local_units(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_product_variants (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      name TEXT NOT NULL,
      sku TEXT,
      barcode TEXT,
      sale_price REAL NOT NULL,
      purchase_price REAL NOT NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES local_products(id) ON DELETE CASCADE
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_warehouses (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      branch_id TEXT,
      name TEXT NOT NULL,
      address TEXT,
      is_default INTEGER NOT NULL DEFAULT 0,
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_stocks (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      warehouse_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      variant_id TEXT,
      quantity_on_hand REAL NOT NULL DEFAULT 0.00,
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE CASCADE,
      FOREIGN KEY (warehouse_id) REFERENCES local_warehouses(id) ON DELETE RESTRICT,
      FOREIGN KEY (product_id) REFERENCES local_products(id) ON DELETE RESTRICT,
      FOREIGN KEY (variant_id) REFERENCES local_product_variants(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_stock_movements (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      warehouse_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      variant_id TEXT,
      movement_type TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_cost REAL NOT NULL,
      reference_type TEXT,
      reference_id TEXT,
      notes TEXT,
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT,
      FOREIGN KEY (warehouse_id) REFERENCES local_warehouses(id) ON DELETE RESTRICT,
      FOREIGN KEY (product_id) REFERENCES local_products(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_invoices (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      branch_id TEXT NOT NULL,
      customer_id TEXT,
      invoice_number TEXT NOT NULL,
      invoice_date TEXT NOT NULL,
      due_date TEXT,
      status TEXT NOT NULL DEFAULT 'ISSUED',
      bill_format TEXT NOT NULL DEFAULT 'A4_STANDARD',
      place_of_supply TEXT NOT NULL,
      is_inter_state INTEGER NOT NULL,
      is_reverse_charge INTEGER NOT NULL DEFAULT 0,
      subtotal REAL NOT NULL,
      discount_type TEXT,
      discount_amount REAL NOT NULL DEFAULT 0.00,
      taxable_amount REAL NOT NULL,
      cgst_amount REAL NOT NULL DEFAULT 0.00,
      sgst_amount REAL NOT NULL DEFAULT 0.00,
      igst_amount REAL NOT NULL DEFAULT 0.00,
      cess_amount REAL NOT NULL DEFAULT 0.00,
      round_off REAL NOT NULL DEFAULT 0.00,
      total_amount REAL NOT NULL,
      received_amount REAL NOT NULL DEFAULT 0.00,
      balance_amount REAL NOT NULL,
      notes TEXT,
      terms TEXT,
      cancelled_at TEXT,
      cancellation_reason TEXT,
      client_operation_id TEXT NOT NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT,
      FOREIGN KEY (customer_id) REFERENCES local_customers(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_invoice_items (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      invoice_id TEXT NOT NULL,
      product_id TEXT,
      variant_id TEXT,
      description TEXT NOT NULL,
      hsn_code TEXT,
      quantity REAL NOT NULL,
      unit_price REAL NOT NULL,
      discount_amount REAL NOT NULL DEFAULT 0.00,
      taxable_amount REAL NOT NULL,
      gst_rate REAL NOT NULL,
      cgst_amount REAL NOT NULL DEFAULT 0.00,
      sgst_amount REAL NOT NULL DEFAULT 0.00,
      igst_amount REAL NOT NULL DEFAULT 0.00,
      cess_amount REAL NOT NULL DEFAULT 0.00,
      total_amount REAL NOT NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE CASCADE,
      FOREIGN KEY (invoice_id) REFERENCES local_invoices(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES local_products(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_purchases (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      branch_id TEXT NOT NULL,
      supplier_id TEXT NOT NULL,
      bill_number TEXT NOT NULL,
      bill_date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'RECEIVED',
      subtotal REAL NOT NULL,
      tax_amount REAL NOT NULL,
      total_amount REAL NOT NULL,
      paid_amount REAL NOT NULL DEFAULT 0.00,
      balance_amount REAL NOT NULL,
      payment_status TEXT NOT NULL DEFAULT 'UNPAID',
      notes TEXT,
      client_operation_id TEXT NOT NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT,
      FOREIGN KEY (supplier_id) REFERENCES local_suppliers(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_purchase_items (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      purchase_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      description TEXT NOT NULL,
      hsn_code TEXT,
      quantity REAL NOT NULL,
      unit_cost REAL NOT NULL,
      tax_rate REAL NOT NULL,
      tax_amount REAL NOT NULL,
      total_amount REAL NOT NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      client_operation_id TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE CASCADE,
      FOREIGN KEY (purchase_id) REFERENCES local_purchases(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES local_products(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_payments (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      payment_number TEXT NOT NULL,
      payment_type TEXT NOT NULL,
      customer_id TEXT,
      supplier_id TEXT,
      payment_date TEXT NOT NULL,
      amount REAL NOT NULL,
      payment_method TEXT NOT NULL,
      reference_number TEXT,
      notes TEXT,
      client_operation_id TEXT NOT NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE RESTRICT,
      FOREIGN KEY (customer_id) REFERENCES local_customers(id) ON DELETE RESTRICT,
      FOREIGN KEY (supplier_id) REFERENCES local_suppliers(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_payment_allocations (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      payment_id TEXT NOT NULL,
      invoice_id TEXT,
      purchase_id TEXT,
      amount REAL NOT NULL,
      client_operation_id TEXT NOT NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      server_version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      FOREIGN KEY (business_id) REFERENCES local_businesses(id) ON DELETE CASCADE,
      FOREIGN KEY (payment_id) REFERENCES local_payments(id) ON DELETE CASCADE,
      FOREIGN KEY (invoice_id) REFERENCES local_invoices(id) ON DELETE RESTRICT,
      FOREIGN KEY (purchase_id) REFERENCES local_purchases(id) ON DELETE RESTRICT,
      CHECK (
        (CASE WHEN invoice_id IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN purchase_id IS NOT NULL THEN 1 ELSE 0 END) = 1
      )
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS local_sync_queue (
      id TEXT PRIMARY KEY NOT NULL,
      business_id TEXT NOT NULL,
      client_operation_id TEXT NOT NULL UNIQUE,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'PENDING',
      retry_count INTEGER NOT NULL DEFAULT 0,
      error_message TEXT,
      created_at TEXT NOT NULL,
      processed_at TEXT
    );
    ''',
  ];

  static const List<String> createIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_customers_business ON local_customers(business_id, name);',
    'CREATE INDEX IF NOT EXISTS idx_customers_phone ON local_customers(business_id, phone);',
    'CREATE INDEX IF NOT EXISTS idx_suppliers_business ON local_suppliers(business_id, name);',
    'CREATE INDEX IF NOT EXISTS idx_products_business ON local_products(business_id, name);',
    'CREATE INDEX IF NOT EXISTS idx_products_sku ON local_products(business_id, sku);',
    'CREATE INDEX IF NOT EXISTS idx_products_barcode ON local_products(business_id, barcode);',
    'CREATE INDEX IF NOT EXISTS idx_stocks_product ON local_stocks(business_id, product_id);',
    'CREATE INDEX IF NOT EXISTS idx_invoices_number ON local_invoices(business_id, invoice_number);',
    'CREATE INDEX IF NOT EXISTS idx_invoices_date ON local_invoices(business_id, invoice_date);',
    'CREATE INDEX IF NOT EXISTS idx_invoices_customer ON local_invoices(business_id, customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_purchases_supplier ON local_purchases(business_id, supplier_id, bill_number);',
    'CREATE INDEX IF NOT EXISTS idx_payments_type ON local_payments(business_id, payment_type);',
    'CREATE INDEX IF NOT EXISTS idx_allocations_payment ON local_payment_allocations(payment_id);',
    'CREATE INDEX IF NOT EXISTS idx_allocations_invoice ON local_payment_allocations(invoice_id);',
    'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON local_sync_queue(status, created_at);',
  ];
}

// ============================================================================
// STRONGLY TYPED LOCAL DOMAIN ENTITY MODELS
// ============================================================================

/// Represents a business/tenant in the local database.
class LocalBusiness {
  final String id;
  final String name;
  final String? legalName;
  final String? gstin;
  final String? pan;
  final String? phone;
  final String? email;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? stateCode;
  final String? pincode;
  final String currency;
  final LocalTaxType taxType;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const LocalBusiness({
    required this.id,
    required this.name,
    this.legalName,
    this.gstin,
    this.pan,
    this.phone,
    this.email,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.stateCode,
    this.pincode,
    this.currency = 'INR',
    this.taxType = LocalTaxType.regular,
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'legal_name': legalName,
    'gstin': gstin,
    'pan': pan,
    'phone': phone,
    'email': email,
    'address_line1': addressLine1,
    'address_line2': addressLine2,
    'city': city,
    'state': state,
    'state_code': stateCode,
    'pincode': pincode,
    'currency': currency,
    'tax_type': taxType.toDbString(),
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalBusiness.fromMap(Map<String, dynamic> map) => LocalBusiness(
    id: map['id'] as String,
    name: map['name'] as String,
    legalName: map['legal_name'] as String?,
    gstin: map['gstin'] as String?,
    pan: map['pan'] as String?,
    phone: map['phone'] as String?,
    email: map['email'] as String?,
    addressLine1: map['address_line1'] as String?,
    addressLine2: map['address_line2'] as String?,
    city: map['city'] as String?,
    state: map['state'] as String?,
    stateCode: map['state_code'] as String?,
    pincode: map['pincode'] as String?,
    currency: (map['currency'] as String?) ?? 'INR',
    taxType: LocalTaxType.fromString(map['tax_type'] as String?),
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents business-level configuration settings in the local database.
class LocalBusinessSettings {
  final String id;
  final String businessId;
  final bool trackInventory;
  final bool allowNegativeStock;
  final LocalBillFormat defaultBillFormat;
  final bool enableGst;
  final double defaultGstRate;
  final DateTime financialYearStart;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime updatedAt;

  const LocalBusinessSettings({
    required this.id,
    required this.businessId,
    this.trackInventory = true,
    this.allowNegativeStock = false,
    this.defaultBillFormat = LocalBillFormat.a4Standard,
    this.enableGst = true,
    this.defaultGstRate = 18.00,
    required this.financialYearStart,
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'track_inventory': trackInventory ? 1 : 0,
    'allow_negative_stock': allowNegativeStock ? 1 : 0,
    'default_bill_format': defaultBillFormat.toDbString(),
    'enable_gst': enableGst ? 1 : 0,
    'default_gst_rate': defaultGstRate,
    'financial_year_start': financialYearStart.toIso8601String(),
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory LocalBusinessSettings.fromMap(Map<String, dynamic> map) => LocalBusinessSettings(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    trackInventory: (map['track_inventory'] as int?) == 1,
    allowNegativeStock: (map['allow_negative_stock'] as int?) == 1,
    defaultBillFormat: LocalBillFormat.fromString(map['default_bill_format'] as String?),
    enableGst: (map['enable_gst'] as int?) == 1,
    defaultGstRate: (map['default_gst_rate'] as num?)?.toDouble() ?? 18.00,
    financialYearStart: DateTime.parse(map['financial_year_start'] as String),
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

/// Represents a customer in the local database.
class LocalCustomer {
  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? billingAddress;
  final String? shippingAddress;
  final String? city;
  final String? state;
  final String? stateCode;
  final String? pincode;
  final double openingBalance;
  final double currentBalance;
  final double? creditLimit;
  final int creditPeriodDays;
  final String status;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const LocalCustomer({
    required this.id,
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.gstin,
    this.billingAddress,
    this.shippingAddress,
    this.city,
    this.state,
    this.stateCode,
    this.pincode,
    this.openingBalance = 0.00,
    this.currentBalance = 0.00,
    this.creditLimit,
    this.creditPeriodDays = 0,
    this.status = 'ACTIVE',
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'name': name,
    'phone': phone,
    'email': email,
    'gstin': gstin,
    'billing_address': billingAddress,
    'shipping_address': shippingAddress,
    'city': city,
    'state': state,
    'state_code': stateCode,
    'pincode': pincode,
    'opening_balance': openingBalance,
    'current_balance': currentBalance,
    'credit_limit': creditLimit,
    'credit_period_days': creditPeriodDays,
    'status': status,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalCustomer.fromMap(Map<String, dynamic> map) => LocalCustomer(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    name: map['name'] as String,
    phone: map['phone'] as String?,
    email: map['email'] as String?,
    gstin: map['gstin'] as String?,
    billingAddress: map['billing_address'] as String?,
    shippingAddress: map['shipping_address'] as String?,
    city: map['city'] as String?,
    state: map['state'] as String?,
    stateCode: map['state_code'] as String?,
    pincode: map['pincode'] as String?,
    openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.00,
    currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.00,
    creditLimit: (map['credit_limit'] as num?)?.toDouble(),
    creditPeriodDays: (map['credit_period_days'] as int?) ?? 0,
    status: (map['status'] as String?) ?? 'ACTIVE',
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents a supplier in the local database.
class LocalSupplier {
  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? pan;
  final String? address;
  final String? city;
  final String? state;
  final String? stateCode;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final double openingBalance;
  final double currentBalance;
  final String status;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const LocalSupplier({
    required this.id,
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.gstin,
    this.pan,
    this.address,
    this.city,
    this.state,
    this.stateCode,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.openingBalance = 0.00,
    this.currentBalance = 0.00,
    this.status = 'ACTIVE',
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'name': name,
    'phone': phone,
    'email': email,
    'gstin': gstin,
    'pan': pan,
    'address': address,
    'city': city,
    'state': state,
    'state_code': stateCode,
    'bank_name': bankName,
    'account_number': accountNumber,
    'ifsc_code': ifscCode,
    'opening_balance': openingBalance,
    'current_balance': currentBalance,
    'status': status,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalSupplier.fromMap(Map<String, dynamic> map) => LocalSupplier(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    name: map['name'] as String,
    phone: map['phone'] as String?,
    email: map['email'] as String?,
    gstin: map['gstin'] as String?,
    pan: map['pan'] as String?,
    address: map['address'] as String?,
    city: map['city'] as String?,
    state: map['state'] as String?,
    stateCode: map['state_code'] as String?,
    bankName: map['bank_name'] as String?,
    accountNumber: map['account_number'] as String?,
    ifscCode: map['ifsc_code'] as String?,
    openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.00,
    currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.00,
    status: (map['status'] as String?) ?? 'ACTIVE',
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents a product category in the local database.
class LocalCategory {
  final String id;
  final String businessId;
  final String name;
  final String? parentId;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime? deletedAt;

  const LocalCategory({
    required this.id,
    required this.businessId,
    required this.name,
    this.parentId,
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.createdAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'name': name,
    'parent_id': parentId,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalCategory.fromMap(Map<String, dynamic> map) => LocalCategory(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    name: map['name'] as String,
    parentId: map['parent_id'] as String?,
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents a unit of measurement in the local database.
class LocalUnit {
  final String id;
  final String businessId;
  final String name;
  final String symbol;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime? deletedAt;

  const LocalUnit({
    required this.id,
    required this.businessId,
    required this.name,
    required this.symbol,
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.createdAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'name': name,
    'symbol': symbol,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalUnit.fromMap(Map<String, dynamic> map) => LocalUnit(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    name: map['name'] as String,
    symbol: map['symbol'] as String,
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents a product or service in the local database.
class LocalProduct {
  final String id;
  final String businessId;
  final String? categoryId;
  final String? unitId;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final String? hsnCode;
  final LocalItemType itemType;
  final bool trackStock;
  final double gstRate;
  final double cessRate;
  final double purchasePrice;
  final double salePrice;
  final double? mrp;
  final double minStockLevel;
  final double currentStock;
  final String status;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const LocalProduct({
    required this.id,
    required this.businessId,
    this.categoryId,
    this.unitId,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.hsnCode,
    this.itemType = LocalItemType.goods,
    this.trackStock = true,
    this.gstRate = 0.00,
    this.cessRate = 0.00,
    this.purchasePrice = 0.00,
    this.salePrice = 0.00,
    this.mrp,
    this.minStockLevel = 0.00,
    this.currentStock = 0.00,
    this.status = 'ACTIVE',
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'category_id': categoryId,
    'unit_id': unitId,
    'name': name,
    'sku': sku,
    'barcode': barcode,
    'description': description,
    'hsn_code': hsnCode,
    'item_type': itemType.toDbString(),
    'track_stock': trackStock ? 1 : 0,
    'gst_rate': gstRate,
    'cess_rate': cessRate,
    'purchase_price': purchasePrice,
    'sale_price': salePrice,
    'mrp': mrp,
    'min_stock_level': minStockLevel,
    'current_stock': currentStock,
    'status': status,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalProduct.fromMap(Map<String, dynamic> map) => LocalProduct(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    categoryId: map['category_id'] as String?,
    unitId: map['unit_id'] as String?,
    name: map['name'] as String,
    sku: map['sku'] as String?,
    barcode: map['barcode'] as String?,
    description: map['description'] as String?,
    hsnCode: map['hsn_code'] as String?,
    itemType: LocalItemType.fromString(map['item_type'] as String?),
    trackStock: (map['track_stock'] as int?) == 1,
    gstRate: (map['gst_rate'] as num?)?.toDouble() ?? 0.00,
    cessRate: (map['cess_rate'] as num?)?.toDouble() ?? 0.00,
    purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.00,
    salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0.00,
    mrp: (map['mrp'] as num?)?.toDouble(),
    minStockLevel: (map['min_stock_level'] as num?)?.toDouble() ?? 0.00,
    currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0.00,
    status: (map['status'] as String?) ?? 'ACTIVE',
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents a warehouse in the local database.
class LocalWarehouse {
  final String id;
  final String businessId;
  final String? branchId;
  final String name;
  final String? address;
  final bool isDefault;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime? deletedAt;

  const LocalWarehouse({
    required this.id,
    required this.businessId,
    this.branchId,
    required this.name,
    this.address,
    this.isDefault = false,
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.createdAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'branch_id': branchId,
    'name': name,
    'address': address,
    'is_default': isDefault ? 1 : 0,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalWarehouse.fromMap(Map<String, dynamic> map) => LocalWarehouse(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    branchId: map['branch_id'] as String?,
    name: map['name'] as String,
    address: map['address'] as String?,
    isDefault: (map['is_default'] as int?) == 1,
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents current stock for a product in a warehouse.
class LocalStock {
  final String id;
  final String businessId;
  final String warehouseId;
  final String productId;
  final String? variantId;
  final double quantityOnHand;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime updatedAt;

  const LocalStock({
    required this.id,
    required this.businessId,
    required this.warehouseId,
    required this.productId,
    this.variantId,
    this.quantityOnHand = 0.00,
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'warehouse_id': warehouseId,
    'product_id': productId,
    'variant_id': variantId,
    'quantity_on_hand': quantityOnHand,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory LocalStock.fromMap(Map<String, dynamic> map) => LocalStock(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    warehouseId: map['warehouse_id'] as String,
    productId: map['product_id'] as String,
    variantId: map['variant_id'] as String?,
    quantityOnHand: (map['quantity_on_hand'] as num?)?.toDouble() ?? 0.00,
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

/// Represents an immutable inventory movement audit log.
class LocalStockMovement {
  final String id;
  final String businessId;
  final String warehouseId;
  final String productId;
  final String? variantId;
  final LocalStockMovementType movementType;
  final double quantity;
  final double unitCost;
  final String? referenceType;
  final String? referenceId;
  final String? notes;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;
  final DateTime createdAt;

  const LocalStockMovement({
    required this.id,
    required this.businessId,
    required this.warehouseId,
    required this.productId,
    this.variantId,
    required this.movementType,
    required this.quantity,
    required this.unitCost,
    this.referenceType,
    this.referenceId,
    this.notes,
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'warehouse_id': warehouseId,
    'product_id': productId,
    'variant_id': variantId,
    'movement_type': movementType.toDbString(),
    'quantity': quantity,
    'unit_cost': unitCost,
    'reference_type': referenceType,
    'reference_id': referenceId,
    'notes': notes,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
  };

  factory LocalStockMovement.fromMap(Map<String, dynamic> map) => LocalStockMovement(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    warehouseId: map['warehouse_id'] as String,
    productId: map['product_id'] as String,
    variantId: map['variant_id'] as String?,
    movementType: LocalStockMovementType.fromString(map['movement_type'] as String?),
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0.00,
    unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.00,
    referenceType: map['reference_type'] as String?,
    referenceId: map['reference_id'] as String?,
    notes: map['notes'] as String?,
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// Represents a sales tax invoice in the local database.
class LocalInvoice {
  final String id;
  final String businessId;
  final String branchId;
  final String? customerId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final LocalInvoiceStatus status;
  final LocalBillFormat billFormat;
  final String placeOfSupply;
  final bool isInterState;
  final bool isReverseCharge;
  final double subtotal;
  final String? discountType;
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
  final String clientOperationId;
  final SyncStatus syncStatus;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const LocalInvoice({
    required this.id,
    required this.businessId,
    required this.branchId,
    this.customerId,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.dueDate,
    this.status = LocalInvoiceStatus.issued,
    this.billFormat = LocalBillFormat.a4Standard,
    required this.placeOfSupply,
    required this.isInterState,
    this.isReverseCharge = false,
    required this.subtotal,
    this.discountType,
    this.discountAmount = 0.00,
    required this.taxableAmount,
    this.cgstAmount = 0.00,
    this.sgstAmount = 0.00,
    this.igstAmount = 0.00,
    this.cessAmount = 0.00,
    this.roundOff = 0.00,
    required this.totalAmount,
    this.receivedAmount = 0.00,
    required this.balanceAmount,
    this.notes,
    this.terms,
    this.cancelledAt,
    this.cancellationReason,
    required this.clientOperationId,
    this.syncStatus = SyncStatus.synced,
    this.serverVersion = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'branch_id': branchId,
    'customer_id': customerId,
    'invoice_number': invoiceNumber,
    'invoice_date': invoiceDate.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'status': status.toDbString(),
    'bill_format': billFormat.toDbString(),
    'place_of_supply': placeOfSupply,
    'is_inter_state': isInterState ? 1 : 0,
    'is_reverse_charge': isReverseCharge ? 1 : 0,
    'subtotal': subtotal,
    'discount_type': discountType,
    'discount_amount': discountAmount,
    'taxable_amount': taxableAmount,
    'cgst_amount': cgstAmount,
    'sgst_amount': sgstAmount,
    'igst_amount': igstAmount,
    'cess_amount': cessAmount,
    'round_off': roundOff,
    'total_amount': totalAmount,
    'received_amount': receivedAmount,
    'balance_amount': balanceAmount,
    'notes': notes,
    'terms': terms,
    'cancelled_at': cancelledAt?.toIso8601String(),
    'cancellation_reason': cancellationReason,
    'client_operation_id': clientOperationId,
    'sync_status': syncStatus.code,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalInvoice.fromMap(Map<String, dynamic> map) => LocalInvoice(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    branchId: map['branch_id'] as String,
    customerId: map['customer_id'] as String?,
    invoiceNumber: map['invoice_number'] as String,
    invoiceDate: DateTime.parse(map['invoice_date'] as String),
    dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
    status: LocalInvoiceStatus.fromString(map['status'] as String?),
    billFormat: LocalBillFormat.fromString(map['bill_format'] as String?),
    placeOfSupply: (map['place_of_supply'] as String?) ?? '27',
    isInterState: (map['is_inter_state'] as int?) == 1,
    isReverseCharge: (map['is_reverse_charge'] as int?) == 1,
    subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.00,
    discountType: map['discount_type'] as String?,
    discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.00,
    taxableAmount: (map['taxable_amount'] as num?)?.toDouble() ?? 0.00,
    cgstAmount: (map['cgst_amount'] as num?)?.toDouble() ?? 0.00,
    sgstAmount: (map['sgst_amount'] as num?)?.toDouble() ?? 0.00,
    igstAmount: (map['igst_amount'] as num?)?.toDouble() ?? 0.00,
    cessAmount: (map['cess_amount'] as num?)?.toDouble() ?? 0.00,
    roundOff: (map['round_off'] as num?)?.toDouble() ?? 0.00,
    totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.00,
    receivedAmount: (map['received_amount'] as num?)?.toDouble() ?? 0.00,
    balanceAmount: (map['balance_amount'] as num?)?.toDouble() ?? 0.00,
    notes: map['notes'] as String?,
    terms: map['terms'] as String?,
    cancelledAt: map['cancelled_at'] != null ? DateTime.parse(map['cancelled_at'] as String) : null,
    cancellationReason: map['cancellation_reason'] as String?,
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents an item line of an invoice in the local database.
class LocalInvoiceItem {
  final String id;
  final String businessId;
  final String invoiceId;
  final String? productId;
  final String? variantId;
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
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;

  const LocalInvoiceItem({
    required this.id,
    required this.businessId,
    required this.invoiceId,
    this.productId,
    this.variantId,
    required this.description,
    this.hsnCode,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0.00,
    required this.taxableAmount,
    required this.gstRate,
    this.cgstAmount = 0.00,
    this.sgstAmount = 0.00,
    this.igstAmount = 0.00,
    this.cessAmount = 0.00,
    required this.totalAmount,
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'invoice_id': invoiceId,
    'product_id': productId,
    'variant_id': variantId,
    'description': description,
    'hsn_code': hsnCode,
    'quantity': quantity,
    'unit_price': unitPrice,
    'discount_amount': discountAmount,
    'taxable_amount': taxableAmount,
    'gst_rate': gstRate,
    'cgst_amount': cgstAmount,
    'sgst_amount': sgstAmount,
    'igst_amount': igstAmount,
    'cess_amount': cessAmount,
    'total_amount': totalAmount,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
  };

  factory LocalInvoiceItem.fromMap(Map<String, dynamic> map) => LocalInvoiceItem(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    invoiceId: map['invoice_id'] as String,
    productId: map['product_id'] as String?,
    variantId: map['variant_id'] as String?,
    description: map['description'] as String,
    hsnCode: map['hsn_code'] as String?,
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0.00,
    unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.00,
    discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.00,
    taxableAmount: (map['taxable_amount'] as num?)?.toDouble() ?? 0.00,
    gstRate: (map['gst_rate'] as num?)?.toDouble() ?? 0.00,
    cgstAmount: (map['cgst_amount'] as num?)?.toDouble() ?? 0.00,
    sgstAmount: (map['sgst_amount'] as num?)?.toDouble() ?? 0.00,
    igstAmount: (map['igst_amount'] as num?)?.toDouble() ?? 0.00,
    cessAmount: (map['cess_amount'] as num?)?.toDouble() ?? 0.00,
    totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.00,
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
  );
}

/// Represents a vendor purchase in the local database.
class LocalPurchase {
  final String id;
  final String businessId;
  final String branchId;
  final String supplierId;
  final String billNumber;
  final DateTime billDate;
  final LocalPurchaseStatus status;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final LocalPaymentStatus paymentStatus;
  final String? notes;
  final String clientOperationId;
  final SyncStatus syncStatus;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const LocalPurchase({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.supplierId,
    required this.billNumber,
    required this.billDate,
    this.status = LocalPurchaseStatus.received,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    this.paidAmount = 0.00,
    required this.balanceAmount,
    this.paymentStatus = LocalPaymentStatus.unpaid,
    this.notes,
    required this.clientOperationId,
    this.syncStatus = SyncStatus.synced,
    this.serverVersion = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'branch_id': branchId,
    'supplier_id': supplierId,
    'bill_number': billNumber,
    'bill_date': billDate.toIso8601String(),
    'status': status.toDbString(),
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'balance_amount': balanceAmount,
    'payment_status': paymentStatus.toDbString(),
    'notes': notes,
    'client_operation_id': clientOperationId,
    'sync_status': syncStatus.code,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalPurchase.fromMap(Map<String, dynamic> map) => LocalPurchase(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    branchId: map['branch_id'] as String,
    supplierId: map['supplier_id'] as String,
    billNumber: map['bill_number'] as String,
    billDate: DateTime.parse(map['bill_date'] as String),
    status: LocalPurchaseStatus.fromString(map['status'] as String?),
    subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.00,
    taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.00,
    totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.00,
    paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.00,
    balanceAmount: (map['balance_amount'] as num?)?.toDouble() ?? 0.00,
    paymentStatus: LocalPaymentStatus.fromString(map['payment_status'] as String?),
    notes: map['notes'] as String?,
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents an item line of a purchase in the local database.
class LocalPurchaseItem {
  final String id;
  final String businessId;
  final String purchaseId;
  final String productId;
  final String description;
  final String? hsnCode;
  final double quantity;
  final double unitCost;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final SyncStatus syncStatus;
  final String clientOperationId;
  final int serverVersion;

  const LocalPurchaseItem({
    required this.id,
    required this.businessId,
    required this.purchaseId,
    required this.productId,
    required this.description,
    this.hsnCode,
    required this.quantity,
    required this.unitCost,
    required this.taxRate,
    required this.taxAmount,
    required this.totalAmount,
    this.syncStatus = SyncStatus.synced,
    required this.clientOperationId,
    this.serverVersion = 1,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'purchase_id': purchaseId,
    'product_id': productId,
    'description': description,
    'hsn_code': hsnCode,
    'quantity': quantity,
    'unit_cost': unitCost,
    'tax_rate': taxRate,
    'tax_amount': taxAmount,
    'total_amount': totalAmount,
    'sync_status': syncStatus.code,
    'client_operation_id': clientOperationId,
    'server_version': serverVersion,
  };

  factory LocalPurchaseItem.fromMap(Map<String, dynamic> map) => LocalPurchaseItem(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    purchaseId: map['purchase_id'] as String,
    productId: map['product_id'] as String,
    description: map['description'] as String,
    hsnCode: map['hsn_code'] as String?,
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0.00,
    unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.00,
    taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.00,
    taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.00,
    totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.00,
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    serverVersion: (map['server_version'] as int?) ?? 1,
  );
}

/// Represents a settlement payment or receipt in the local database.
class LocalPayment {
  final String id;
  final String businessId;
  final String paymentNumber;
  final LocalPaymentType paymentType;
  final String? customerId;
  final String? supplierId;
  final DateTime paymentDate;
  final double amount;
  final LocalPaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? notes;
  final String clientOperationId;
  final SyncStatus syncStatus;
  final int serverVersion;
  final DateTime createdAt;
  final DateTime? deletedAt;

  const LocalPayment({
    required this.id,
    required this.businessId,
    required this.paymentNumber,
    required this.paymentType,
    this.customerId,
    this.supplierId,
    required this.paymentDate,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
    required this.clientOperationId,
    this.syncStatus = SyncStatus.synced,
    this.serverVersion = 1,
    required this.createdAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'payment_number': paymentNumber,
    'payment_type': paymentType.toDbString(),
    'customer_id': customerId,
    'supplier_id': supplierId,
    'payment_date': paymentDate.toIso8601String(),
    'amount': amount,
    'payment_method': paymentMethod.toDbString(),
    'reference_number': referenceNumber,
    'notes': notes,
    'client_operation_id': clientOperationId,
    'sync_status': syncStatus.code,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory LocalPayment.fromMap(Map<String, dynamic> map) => LocalPayment(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    paymentNumber: map['payment_number'] as String,
    paymentType: LocalPaymentType.fromString(map['payment_type'] as String?),
    customerId: map['customer_id'] as String?,
    supplierId: map['supplier_id'] as String?,
    paymentDate: DateTime.parse(map['payment_date'] as String),
    amount: (map['amount'] as num?)?.toDouble() ?? 0.00,
    paymentMethod: LocalPaymentMethod.fromString(map['payment_method'] as String?),
    referenceNumber: map['reference_number'] as String?,
    notes: map['notes'] as String?,
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
  );
}

/// Represents a settlement allocation link against an invoice or purchase.
class LocalPaymentAllocation {
  final String id;
  final String businessId;
  final String paymentId;
  final String? invoiceId;
  final String? purchaseId;
  final double amount;
  final String clientOperationId;
  final SyncStatus syncStatus;
  final int serverVersion;
  final DateTime createdAt;

  const LocalPaymentAllocation({
    required this.id,
    required this.businessId,
    required this.paymentId,
    this.invoiceId,
    this.purchaseId,
    required this.amount,
    required this.clientOperationId,
    this.syncStatus = SyncStatus.synced,
    this.serverVersion = 1,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'payment_id': paymentId,
    'invoice_id': invoiceId,
    'purchase_id': purchaseId,
    'amount': amount,
    'client_operation_id': clientOperationId,
    'sync_status': syncStatus.code,
    'server_version': serverVersion,
    'created_at': createdAt.toIso8601String(),
  };

  factory LocalPaymentAllocation.fromMap(Map<String, dynamic> map) => LocalPaymentAllocation(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    paymentId: map['payment_id'] as String,
    invoiceId: map['invoice_id'] as String?,
    purchaseId: map['purchase_id'] as String?,
    amount: (map['amount'] as num?)?.toDouble() ?? 0.00,
    clientOperationId: (map['client_operation_id'] as String?) ?? '',
    syncStatus: SyncStatus.fromCode((map['sync_status'] as int?) ?? 0),
    serverVersion: (map['server_version'] as int?) ?? 1,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// Represents an offline-first mutation queued for background synchronization.
class LocalSyncQueueItem {
  final String id;
  final String businessId;
  final String clientOperationId;
  final String entityType;
  final String entityId;
  final String operation;
  final String payload;
  final String status;
  final int retryCount;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? processedAt;

  const LocalSyncQueueItem({
    required this.id,
    required this.businessId,
    required this.clientOperationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.status = 'PENDING',
    this.retryCount = 0,
    this.errorMessage,
    required this.createdAt,
    this.processedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'client_operation_id': clientOperationId,
    'entity_type': entityType,
    'entity_id': entityId,
    'operation': operation,
    'payload': payload,
    'status': status,
    'retry_count': retryCount,
    'error_message': errorMessage,
    'created_at': createdAt.toIso8601String(),
    'processed_at': processedAt?.toIso8601String(),
  };

  factory LocalSyncQueueItem.fromMap(Map<String, dynamic> map) => LocalSyncQueueItem(
    id: map['id'] as String,
    businessId: map['business_id'] as String,
    clientOperationId: map['client_operation_id'] as String,
    entityType: map['entity_type'] as String,
    entityId: map['entity_id'] as String,
    operation: map['operation'] as String,
    payload: map['payload'] as String,
    status: (map['status'] as String?) ?? 'PENDING',
    retryCount: (map['retry_count'] as int?) ?? 0,
    errorMessage: map['error_message'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    processedAt: map['processed_at'] != null ? DateTime.parse(map['processed_at'] as String) : null,
  );
}
