import { ALL_PERMISSION_KEYS } from './permissions.seed';

export interface SystemRoleDefinition {
  name: string;
  description: string;
  permissions: string[];
}

export const DEFAULT_SYSTEM_ROLES: SystemRoleDefinition[] = [
  {
    name: 'OWNER',
    description: 'Business owner with unrestricted authority over all operations, finances, and settings.',
    permissions: ALL_PERMISSION_KEYS,
  },
  {
    name: 'ADMIN',
    description: 'System administrator managing branches, users, catalog, operations, and business setup.',
    permissions: ALL_PERMISSION_KEYS.filter((p) => !p.startsWith('audit.purge')),
  },
  {
    name: 'MANAGER',
    description: 'Store or operations manager overseeing sales, purchases, inventory, parties, and collections.',
    permissions: [
      'business.view',
      'users.view',
      'products.view',
      'products.create',
      'products.update',
      'stock.adjust',
      'customers.view',
      'customers.manage',
      'suppliers.view',
      'suppliers.manage',
      'invoices.view',
      'invoices.create',
      'purchases.view',
      'purchases.create',
      'payments.view',
      'payments.create',
      'expenses.view',
      'expenses.manage',
      'reports.sales',
    ],
  },
  {
    name: 'CASHIER',
    description: 'Front-desk operator authorized to issue sales invoices, collect payments, and view items.',
    permissions: [
      'products.view',
      'customers.view',
      'customers.manage',
      'invoices.view',
      'invoices.create',
      'payments.view',
      'payments.create',
    ],
  },
  {
    name: 'ACCOUNTANT',
    description: 'Financial professional managing accounting ledgers, expenses, payments, GST, and audit reports.',
    permissions: [
      'business.view',
      'products.view',
      'customers.view',
      'suppliers.view',
      'invoices.view',
      'purchases.view',
      'payments.view',
      'payments.create',
      'expenses.view',
      'expenses.manage',
      'accounting.view',
      'gst.reports',
      'reports.sales',
      'reports.financial',
      'audit.view',
    ],
  },
];

export async function seedRoles(prisma: any): Promise<void> {
  for (const roleDef of DEFAULT_SYSTEM_ROLES) {
    // Find existing system role where businessId is null and name matches
    const existingRole = await prisma.role.findFirst({
      where: {
        businessId: null,
        name: roleDef.name,
      },
    });

    if (existingRole) {
      await prisma.role.update({
        where: { id: existingRole.id },
        data: {
          description: roleDef.description,
          permissions: roleDef.permissions,
          isSystem: true,
        },
      });
    } else {
      await prisma.role.create({
        data: {
          businessId: null,
          name: roleDef.name,
          description: roleDef.description,
          permissions: roleDef.permissions,
          isSystem: true,
        },
      });
    }
  }
}
