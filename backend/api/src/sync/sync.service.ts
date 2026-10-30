import { Injectable, Logger, ConflictException, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { InvoicesService } from '../sales/invoices.service';
import { PurchasesService } from '../purchases-inventory/purchases.service';
import { PaymentsService } from '../payments-expenses/payments.service';
import { ExpensesService } from '../payments-expenses/expenses.service';
import { CustomersService } from '../master-data/customers/customers.service';
import { SuppliersService } from '../master-data/suppliers/suppliers.service';
import { ProductsService } from '../master-data/products/products.service';
import {
  SyncBatchDto,
  SyncEntityType,
  SyncOperationItemDto,
  SyncOperationType,
  SyncPullDto,
} from './dto/sync-batch.dto';

export interface SyncAckItem {
  clientOperationId: string;
  status: 'ACKNOWLEDGED' | 'CONFLICT' | 'FAILED';
  serverEntityId?: string;
  canonicalDocumentNumber?: string;
  serverVersion?: number;
  data?: any;
  errorMessage?: string;
  idempotentReplay?: boolean;
}

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly invoicesService: InvoicesService,
    private readonly purchasesService: PurchasesService,
    private readonly paymentsService: PaymentsService,
    private readonly expensesService: ExpensesService,
    private readonly customersService: CustomersService,
    private readonly suppliersService: SuppliersService,
    private readonly productsService: ProductsService,
  ) {}

  /**
   * Process a batch of sync operations idempotently with conflict detection and role enforcement.
   */
  async processBatch(
    businessId: string,
    dto: SyncBatchDto,
    userId?: string,
    userRole?: string,
  ): Promise<SyncAckItem[]> {
    const results: SyncAckItem[] = [];

    for (const op of dto.operations) {
      try {
        const result = await this.processOperation(businessId, op, userId, userRole);
        results.push(result);
      } catch (err: any) {
        this.logger.error(`Failed processing sync operation ${op.clientOperationId}: ${err.message}`, err.stack);
        results.push({
          clientOperationId: op.clientOperationId,
          status: 'FAILED',
          errorMessage: err.message || 'Unknown processing error',
        });
      }
    }

    return results;
  }

  /**
   * Process a single sync operation with idempotency, conflict protection, and RBAC enforcement.
   */
  async processOperation(
    businessId: string,
    op: SyncOperationItemDto,
    userId?: string,
    userRole?: string,
  ): Promise<SyncAckItem> {
    // 1. Idempotency Check in SyncQueue
    const existingQueue = await this.prisma.syncQueue.findUnique({
      where: {
        businessId_clientOperationId: {
          businessId,
          clientOperationId: op.clientOperationId,
        },
      },
    });

    if (existingQueue && existingQueue.status === 'PROCESSED') {
      const existingEntity = await this.fetchEntity(businessId, op.entityType, existingQueue.entityId);
      return {
        clientOperationId: op.clientOperationId,
        status: 'ACKNOWLEDGED',
        serverEntityId: existingQueue.entityId,
        canonicalDocumentNumber: this.extractDocNumber(op.entityType, existingEntity),
        serverVersion: existingEntity?.version ?? 1,
        data: existingEntity,
        idempotentReplay: true,
      };
    }

    // 2. Handle Operation by Type with Role Verification
    if (op.operation === SyncOperationType.CREATE) {
      return this.handleCreate(businessId, op, userId, userRole);
    } else if (op.operation === SyncOperationType.UPDATE) {
      return this.handleUpdate(businessId, op, userRole);
    } else {
      throw new BadRequestException(`Unsupported operation ${op.operation}`);
    }
  }

  private async handleCreate(
    businessId: string,
    op: SyncOperationItemDto,
    userId?: string,
    userRole?: string,
  ): Promise<SyncAckItem> {
    let createdEntity: any;
    let docNumber: string | undefined;
    let serverId: string;

    const role = userRole || 'OWNER';
    const isManagerOrAdmin = ['OWNER', 'ADMIN', 'MANAGER'].includes(role);

    const payload = { ...op.payload, clientOperationId: op.clientOperationId };

    switch (op.entityType) {
      case SyncEntityType.INVOICE: {
        if (!isManagerOrAdmin) {
          return {
            clientOperationId: op.clientOperationId,
            status: 'FAILED',
            errorMessage: `Forbidden: Role ${role} is not authorized to create invoices via sync.`,
          };
        }
        const invRes = await this.invoicesService.create(businessId, payload as any, userId);
        createdEntity = invRes.data || invRes;
        docNumber = createdEntity.invoiceNumber;
        serverId = createdEntity.id;
        break;
      }
      case SyncEntityType.PURCHASE: {
        if (!isManagerOrAdmin) {
          return {
            clientOperationId: op.clientOperationId,
            status: 'FAILED',
            errorMessage: `Forbidden: Role ${role} is not authorized to create purchases via sync.`,
          };
        }
        const purRes = await this.purchasesService.create(businessId, payload as any, userId);
        createdEntity = purRes.data || purRes;
        docNumber = createdEntity.billNumber;
        serverId = createdEntity.id;
        break;
      }
      case SyncEntityType.PAYMENT: {
        const isSupplier = (payload as any).paymentType === 'SUPPLIER_PAYMENT' || !!(payload as any).supplierId;
        if (isSupplier) {
          if (!isManagerOrAdmin) {
            return {
              clientOperationId: op.clientOperationId,
              status: 'FAILED',
              errorMessage: `Forbidden: Role ${role} is not authorized to record supplier payments via sync.`,
            };
          }
          createdEntity = await this.paymentsService.recordSupplierPayment(businessId, payload as any, userId);
        } else {
          if (!isManagerOrAdmin) {
            return {
              clientOperationId: op.clientOperationId,
              status: 'FAILED',
              errorMessage: `Forbidden: Role ${role} is not authorized to record customer receipts via sync.`,
            };
          }
          createdEntity = await this.paymentsService.recordCustomerReceipt(businessId, payload as any, userId);
        }
        docNumber = createdEntity.paymentNumber;
        serverId = createdEntity.id;
        break;
      }
      case SyncEntityType.EXPENSE: {
        createdEntity = await this.expensesService.createExpense(businessId, payload as any, userId);
        docNumber = createdEntity.expenseNumber;
        serverId = createdEntity.id;
        break;
      }
      case SyncEntityType.CUSTOMER: {
        createdEntity = await this.customersService.create(businessId, payload as any);
        serverId = createdEntity.id;
        break;
      }
      case SyncEntityType.SUPPLIER: {
        if (!isManagerOrAdmin) {
          return {
            clientOperationId: op.clientOperationId,
            status: 'FAILED',
            errorMessage: `Forbidden: Role ${role} is not authorized to create suppliers via sync.`,
          };
        }
        createdEntity = await this.suppliersService.create(businessId, payload as any);
        serverId = createdEntity.id;
        break;
      }
      case SyncEntityType.PRODUCT: {
        if (!isManagerOrAdmin) {
          return {
            clientOperationId: op.clientOperationId,
            status: 'FAILED',
            errorMessage: `Forbidden: Role ${role} is not authorized to create products via sync.`,
          };
        }
        createdEntity = await this.productsService.create(businessId, payload as any);
        serverId = createdEntity.id;
        break;
      }
      default:
        throw new BadRequestException(`Unsupported entity type ${op.entityType}`);
    }

    // Record in SyncQueue
    await this.prisma.syncQueue.upsert({
      where: {
        businessId_clientOperationId: {
          businessId,
          clientOperationId: op.clientOperationId,
        },
      },
      update: {
        status: 'PROCESSED',
        processedAt: new Date(),
        entityId: serverId,
      },
      create: {
        businessId,
        clientOperationId: op.clientOperationId,
        entityType: op.entityType,
        entityId: serverId,
        operation: op.operation,
        payload: op.payload,
        status: 'PROCESSED',
        processedAt: new Date(),
      },
    });

    return {
      clientOperationId: op.clientOperationId,
      status: 'ACKNOWLEDGED',
      serverEntityId: serverId,
      canonicalDocumentNumber: docNumber,
      serverVersion: createdEntity.version ?? 1,
      data: createdEntity,
    };
  }

  private async handleUpdate(businessId: string, op: SyncOperationItemDto, userRole?: string): Promise<SyncAckItem> {
    const role = userRole || 'OWNER';
    const isManagerOrAdmin = ['OWNER', 'ADMIN', 'MANAGER'].includes(role);

    const existing = await this.fetchEntity(businessId, op.entityType, op.entityId);
    if (!existing) {
      throw new NotFoundException(`${op.entityType} with ID ${op.entityId} not found.`);
    }

    // Version conflict detection
    if (op.version !== undefined && existing.version !== undefined && existing.version > op.version) {
      this.logger.warn(`Sync conflict detected for ${op.entityType} ${op.entityId}: client version ${op.version} < server version ${existing.version}`);
      return {
        clientOperationId: op.clientOperationId,
        status: 'CONFLICT',
        serverEntityId: op.entityId,
        serverVersion: existing.version,
        data: existing,
        errorMessage: 'Concurrent edit detected. Server has newer version.',
      };
    }

    // Perform update with RBAC verification
    let updatedEntity: any;
    switch (op.entityType) {
      case SyncEntityType.CUSTOMER:
        updatedEntity = await this.customersService.update(businessId, op.entityId, op.payload as any);
        break;
      case SyncEntityType.SUPPLIER:
        if (!isManagerOrAdmin) {
          return {
            clientOperationId: op.clientOperationId,
            status: 'FAILED',
            errorMessage: `Forbidden: Role ${role} is not authorized to update suppliers via sync.`,
          };
        }
        updatedEntity = await this.suppliersService.update(businessId, op.entityId, op.payload as any);
        break;
      case SyncEntityType.PRODUCT:
        if (!isManagerOrAdmin) {
          return {
            clientOperationId: op.clientOperationId,
            status: 'FAILED',
            errorMessage: `Forbidden: Role ${role} is not authorized to update products via sync.`,
          };
        }
        updatedEntity = await this.productsService.update(businessId, op.entityId, op.payload as any);
        break;
      default:
        throw new BadRequestException(`Updates via sync not supported for ${op.entityType}`);
    }

    return {
      clientOperationId: op.clientOperationId,
      status: 'ACKNOWLEDGED',
      serverEntityId: op.entityId,
      serverVersion: (existing.version || 1) + 1,
      data: updatedEntity,
    };
  }

  /**
   * Pull changes created or updated since the specified timestamp.
   */
  async pullChanges(businessId: string, dto: SyncPullDto) {
    const sinceDate = dto.since ? new Date(dto.since) : new Date(0);

    const [invoices, purchases, payments, customers, suppliers, products] = await Promise.all([
      this.prisma.invoice.findMany({
        where: { businessId, updatedAt: { gte: sinceDate } },
        include: { items: true },
        take: 100,
        orderBy: { updatedAt: 'asc' },
      }),
      this.prisma.purchase.findMany({
        where: { businessId, updatedAt: { gte: sinceDate } },
        include: { items: true },
        take: 100,
        orderBy: { updatedAt: 'asc' },
      }),
      this.prisma.payment.findMany({
        where: { businessId, createdAt: { gte: sinceDate } },
        include: { allocations: true },
        take: 100,
        orderBy: { createdAt: 'asc' },
      }),
      this.prisma.customer.findMany({
        where: { businessId, updatedAt: { gte: sinceDate } },
        take: 100,
        orderBy: { updatedAt: 'asc' },
      }),
      this.prisma.supplier.findMany({
        where: { businessId, updatedAt: { gte: sinceDate } },
        take: 100,
        orderBy: { updatedAt: 'asc' },
      }),
      this.prisma.product.findMany({
        where: { businessId, updatedAt: { gte: sinceDate } },
        take: 100,
        orderBy: { updatedAt: 'asc' },
      }),
    ]);

    return {
      serverTime: new Date().toISOString(),
      changes: {
        invoices,
        purchases,
        payments,
        customers,
        suppliers,
        products,
      },
    };
  }

  private async fetchEntity(businessId: string, type: SyncEntityType, id: string): Promise<any> {
    switch (type) {
      case SyncEntityType.INVOICE:
        return this.prisma.invoice.findFirst({ where: { businessId, id }, include: { items: true } });
      case SyncEntityType.PURCHASE:
        return this.prisma.purchase.findFirst({ where: { businessId, id }, include: { items: true } });
      case SyncEntityType.PAYMENT:
        return this.prisma.payment.findFirst({ where: { businessId, id }, include: { allocations: true } });
      case SyncEntityType.EXPENSE:
        return this.prisma.expense.findFirst({ where: { businessId, id } });
      case SyncEntityType.CUSTOMER:
        return this.prisma.customer.findFirst({ where: { businessId, id } });
      case SyncEntityType.SUPPLIER:
        return this.prisma.supplier.findFirst({ where: { businessId, id } });
      case SyncEntityType.PRODUCT:
        return this.prisma.product.findFirst({ where: { businessId, id } });
      default:
        return null;
    }
  }

  private extractDocNumber(type: SyncEntityType, entity: any): string | undefined {
    if (!entity) return undefined;
    switch (type) {
      case SyncEntityType.INVOICE:
        return entity.invoiceNumber;
      case SyncEntityType.PURCHASE:
        return entity.billNumber;
      case SyncEntityType.PAYMENT:
        return entity.paymentNumber;
      case SyncEntityType.EXPENSE:
        return entity.expenseNumber;
      default:
        return undefined;
    }
  }
}
