import { Test, TestingModule } from '@nestjs/testing';
import { SyncService } from './sync.service';
import { PrismaService } from '../database/prisma.service';
import { InvoicesService } from '../sales/invoices.service';
import { PurchasesService } from '../purchases-inventory/purchases.service';
import { PaymentsService } from '../payments-expenses/payments.service';
import { ExpensesService } from '../payments-expenses/expenses.service';
import { CustomersService } from '../master-data/customers/customers.service';
import { SuppliersService } from '../master-data/suppliers/suppliers.service';
import { ProductsService } from '../master-data/products/products.service';
import { SyncBatchDto, SyncEntityType, SyncOperationType } from './dto/sync-batch.dto';

describe('SyncService', () => {
  let service: SyncService;
  let prisma: any;
  let invoicesService: any;
  let purchasesService: any;
  let paymentsService: any;
  let expensesService: any;
  let customersService: any;
  let suppliersService: any;
  let productsService: any;

  const mockBusinessId = 'biz_sync_test_001';
  const mockUserId = 'usr_sync_001';

  beforeEach(async () => {
    prisma = {
      syncQueue: {
        findUnique: jest.fn(),
        upsert: jest.fn(),
      },
      invoice: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
      },
      purchase: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
      },
      payment: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
      },
      expense: {
        findFirst: jest.fn(),
      },
      customer: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
      },
      supplier: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
      },
      product: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
      },
    };

    invoicesService = {
      create: jest.fn(),
    };
    purchasesService = {
      create: jest.fn(),
    };
    paymentsService = {
      recordCustomerReceipt: jest.fn(),
      recordSupplierPayment: jest.fn(),
    };
    expensesService = {
      createExpense: jest.fn(),
    };
    customersService = {
      create: jest.fn(),
      update: jest.fn(),
    };
    suppliersService = {
      create: jest.fn(),
      update: jest.fn(),
    };
    productsService = {
      create: jest.fn(),
      update: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SyncService,
        { provide: PrismaService, useValue: prisma },
        { provide: InvoicesService, useValue: invoicesService },
        { provide: PurchasesService, useValue: purchasesService },
        { provide: PaymentsService, useValue: paymentsService },
        { provide: ExpensesService, useValue: expensesService },
        { provide: CustomersService, useValue: customersService },
        { provide: SuppliersService, useValue: suppliersService },
        { provide: ProductsService, useValue: productsService },
      ],
    }).compile();

    service = module.get<SyncService>(SyncService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('processBatch', () => {
    it('creates an invoice from offline client operation and acknowledges with canonical invoice number', async () => {
      prisma.syncQueue.findUnique.mockResolvedValue(null); // not already processed
      invoicesService.create.mockResolvedValue({
        data: {
          id: 'server_inv_101',
          invoiceNumber: 'INV-2026-27-0042',
          version: 1,
        },
      });
      prisma.syncQueue.upsert.mockResolvedValue({});

      const batchDto: SyncBatchDto = {
        operations: [
          {
            clientOperationId: 'client-op-uuid-1',
            entityType: SyncEntityType.INVOICE,
            operation: SyncOperationType.CREATE,
            entityId: 'offline-inv-001',
            payload: {
              customerId: 'cust_1',
              items: [{ productId: 'p1', quantity: 2, unitPrice: 500 }],
            },
          },
        ],
      };

      const result = await service.processBatch(mockBusinessId, batchDto, mockUserId);

      expect(result).toHaveLength(1);
      expect(result[0]).toEqual({
        clientOperationId: 'client-op-uuid-1',
        status: 'ACKNOWLEDGED',
        serverEntityId: 'server_inv_101',
        canonicalDocumentNumber: 'INV-2026-27-0042',
        serverVersion: 1,
        data: expect.objectContaining({ id: 'server_inv_101' }),
      });
      expect(invoicesService.create).toHaveBeenCalledWith(
        mockBusinessId,
        expect.objectContaining({ clientOperationId: 'client-op-uuid-1' }),
        mockUserId,
      );
      expect(prisma.syncQueue.upsert).toHaveBeenCalled();
    });

    it('returns existing record idempotently when clientOperationId is replayed', async () => {
      // Simulate previously processed queue item
      prisma.syncQueue.findUnique.mockResolvedValue({
        id: 'sq_1',
        businessId: mockBusinessId,
        clientOperationId: 'client-op-uuid-1',
        entityId: 'server_inv_101',
        status: 'PROCESSED',
      });

      prisma.invoice.findFirst.mockResolvedValue({
        id: 'server_inv_101',
        invoiceNumber: 'INV-2026-27-0042',
        version: 1,
      });

      const batchDto: SyncBatchDto = {
        operations: [
          {
            clientOperationId: 'client-op-uuid-1',
            entityType: SyncEntityType.INVOICE,
            operation: SyncOperationType.CREATE,
            entityId: 'offline-inv-001',
            payload: {},
          },
        ],
      };

      const result = await service.processBatch(mockBusinessId, batchDto, mockUserId);

      expect(result).toHaveLength(1);
      expect(result[0].status).toBe('ACKNOWLEDGED');
      expect(result[0].idempotentReplay).toBe(true);
      expect(result[0].canonicalDocumentNumber).toBe('INV-2026-27-0042');
      // InvoicesService.create should NOT be called again
      expect(invoicesService.create).not.toHaveBeenCalled();
    });

    it('detects conflict and does not silently overwrite when client version is outdated', async () => {
      prisma.syncQueue.findUnique.mockResolvedValue(null);
      prisma.customer.findFirst.mockResolvedValue({
        id: 'cust_001',
        name: 'Updated on Server First',
        version: 3, // Server version is 3
      });

      const batchDto: SyncBatchDto = {
        operations: [
          {
            clientOperationId: 'client-op-uuid-conflict',
            entityType: SyncEntityType.CUSTOMER,
            operation: SyncOperationType.UPDATE,
            entityId: 'cust_001',
            version: 1, // Client only had version 1
            payload: { name: 'Offline Edit From Device 2' },
          },
        ],
      };

      const result = await service.processBatch(mockBusinessId, batchDto, mockUserId);

      expect(result).toHaveLength(1);
      expect(result[0].status).toBe('CONFLICT');
      expect(result[0].serverVersion).toBe(3);
      expect(result[0].data).toEqual(expect.objectContaining({ name: 'Updated on Server First' }));
      // Customer update must NOT be called on conflict
      expect(customersService.update).not.toHaveBeenCalled();
    });

    it('returns FAILED status when operation payload throws validation error', async () => {
      prisma.syncQueue.findUnique.mockResolvedValue(null);
      invoicesService.create.mockRejectedValue(new Error('Tax calculation error'));

      const batchDto: SyncBatchDto = {
        operations: [
          {
            clientOperationId: 'client-op-fail',
            entityType: SyncEntityType.INVOICE,
            operation: SyncOperationType.CREATE,
            entityId: 'offline-inv-fail',
            payload: {},
          },
        ],
      };

      const result = await service.processBatch(mockBusinessId, batchDto, mockUserId);

      expect(result).toHaveLength(1);
      expect(result[0].status).toBe('FAILED');
      expect(result[0].errorMessage).toBe('Tax calculation error');
    });

    describe('Sync RBAC Authorization Enforcement', () => {
      it('MUST reject STAFF attempts to create invoices via sync batch', async () => {
        prisma.syncQueue.findUnique.mockResolvedValue(null);

        const batchDto: SyncBatchDto = {
          operations: [
            {
              clientOperationId: 'staff-inv-op',
              entityType: SyncEntityType.INVOICE,
              operation: SyncOperationType.CREATE,
              entityId: 'temp-inv-1',
              payload: { items: [] },
            },
          ],
        };

        const result = await service.processBatch(mockBusinessId, batchDto, mockUserId, 'STAFF');

        expect(result).toHaveLength(1);
        expect(result[0].status).toBe('FAILED');
        expect(result[0].errorMessage).toMatch(/Forbidden.*STAFF.*invoice/i);
        expect(invoicesService.create).not.toHaveBeenCalled();
      });

      it('MUST reject STAFF attempts to create products via sync batch', async () => {
        prisma.syncQueue.findUnique.mockResolvedValue(null);

        const batchDto: SyncBatchDto = {
          operations: [
            {
              clientOperationId: 'staff-prod-op',
              entityType: SyncEntityType.PRODUCT,
              operation: SyncOperationType.CREATE,
              entityId: 'temp-prod-1',
              payload: { name: 'Unauthorized product' },
            },
          ],
        };

        const result = await service.processBatch(mockBusinessId, batchDto, mockUserId, 'STAFF');

        expect(result).toHaveLength(1);
        expect(result[0].status).toBe('FAILED');
        expect(result[0].errorMessage).toMatch(/Forbidden.*STAFF.*product/i);
        expect(productsService.create).not.toHaveBeenCalled();
      });

      it('MUST allow MANAGER to create invoices via sync batch', async () => {
        prisma.syncQueue.findUnique.mockResolvedValue(null);
        invoicesService.create.mockResolvedValue({
          data: { id: 'mgr-inv-1', invoiceNumber: 'INV-2026-27-0099', version: 1 },
        });

        const batchDto: SyncBatchDto = {
          operations: [
            {
              clientOperationId: 'mgr-inv-op',
              entityType: SyncEntityType.INVOICE,
              operation: SyncOperationType.CREATE,
              entityId: 'temp-inv-2',
              payload: { items: [] },
            },
          ],
        };

        const result = await service.processBatch(mockBusinessId, batchDto, mockUserId, 'MANAGER');

        expect(result).toHaveLength(1);
        expect(result[0].status).toBe('ACKNOWLEDGED');
        expect(invoicesService.create).toHaveBeenCalled();
      });
    });
  });

  describe('pullChanges', () => {
    it('returns changes across entities updated since timestamp', async () => {
      prisma.invoice.findMany.mockResolvedValue([{ id: 'inv_1' }]);
      prisma.purchase.findMany.mockResolvedValue([]);
      prisma.payment.findMany.mockResolvedValue([]);
      prisma.customer.findMany.mockResolvedValue([]);
      prisma.supplier.findMany.mockResolvedValue([]);
      prisma.product.findMany.mockResolvedValue([]);

      const result = await service.pullChanges(mockBusinessId, { since: '2026-10-20T00:00:00.000Z' });

      expect(result).toBeDefined();
      expect(result.serverTime).toBeDefined();
      expect(result.changes.invoices).toHaveLength(1);
      expect(prisma.invoice.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            businessId: mockBusinessId,
            updatedAt: { gte: expect.any(Date) },
          }),
        }),
      );
    });
  });
});
