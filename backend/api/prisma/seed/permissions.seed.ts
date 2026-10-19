export interface PermissionDefinition {
  key: string;
  module: string;
  description: string;
}

export const SYSTEM_PERMISSIONS: PermissionDefinition[] = [
  // Business Settings
  { key: 'business.view', module: 'Business', description: 'View business profile and settings' },
  { key: 'business.update', module: 'Business', description: 'Update business profile, tax settings, and logo' },
  { key: 'branches.manage', module: 'Business', description: 'Create and manage branches and warehouses' },

  // User Management
  { key: 'users.view', module: 'Users', description: 'View business members and their roles' },
  { key: 'users.manage', module: 'Users', description: 'Invite, update, and remove members' },
  { key: 'roles.manage', module: 'Users', description: 'Create and edit custom roles and permissions' },

  // Products & Inventory
  { key: 'products.view', module: 'Inventory', description: 'View products, prices, and stock levels' },
  { key: 'products.create', module: 'Inventory', description: 'Add new items and categories' },
  { key: 'products.update', module: 'Inventory', description: 'Modify prices, HSN, and item details' },
  { key: 'products.delete', module: 'Inventory', description: 'Archive products' },
  { key: 'stock.adjust', module: 'Inventory', description: 'Perform manual stock adjustments and audits' },

  // Customers & Suppliers
  { key: 'customers.view', module: 'Parties', description: 'View customers and outstanding balances' },
  { key: 'customers.manage', module: 'Parties', description: 'Create and edit customer records' },
  { key: 'suppliers.view', module: 'Parties', description: 'View suppliers and payables' },
  { key: 'suppliers.manage', module: 'Parties', description: 'Create and edit supplier records' },

  // Sales & Invoicing
  { key: 'invoices.view', module: 'Sales', description: 'View sales invoices and quotations' },
  { key: 'invoices.create', module: 'Sales', description: 'Create and issue sales invoices' },
  { key: 'invoices.cancel', module: 'Sales', description: 'Cancel issued invoices and process sales returns' },

  // Purchases
  { key: 'purchases.view', module: 'Purchases', description: 'View purchase bills and vendor orders' },
  { key: 'purchases.create', module: 'Purchases', description: 'Record inward purchase bills' },
  { key: 'purchases.cancel', module: 'Purchases', description: 'Cancel purchase bills and vendor returns' },

  // Payments & Expenses
  { key: 'payments.view', module: 'Money', description: 'View payment receipts and vouchers' },
  { key: 'payments.create', module: 'Money', description: 'Record customer collections and vendor payments' },
  { key: 'expenses.view', module: 'Money', description: 'View operating expenses' },
  { key: 'expenses.manage', module: 'Money', description: 'Record and edit operating expenses' },

  // Accounting & GST
  { key: 'accounting.view', module: 'Accounting', description: 'View chart of accounts, journal, and ledger' },
  { key: 'gst.reports', module: 'Accounting', description: 'View and export GSTR-1 and GSTR-3B summary tables' },

  // Reports
  { key: 'reports.sales', module: 'Reports', description: 'View sales, profit, and revenue analytics' },
  { key: 'reports.financial', module: 'Reports', description: 'View Balance Sheet and Profit & Loss reports' },

  // Audit
  { key: 'audit.view', module: 'Audit', description: 'Inspect audit trail and operational event logs' },
];

export const ALL_PERMISSION_KEYS = SYSTEM_PERMISSIONS.map((p) => p.key);
