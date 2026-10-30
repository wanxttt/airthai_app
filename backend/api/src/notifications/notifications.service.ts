import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { QueryNotificationsDto } from './dto/query-notifications.dto';

export interface CreateNotificationParams {
  businessId: string;
  userId?: string;
  type: string;
  title: string;
  message: string;
  data?: Record<string, any>;
  dedupKey?: string;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Creates a notification with automatic deduplication protection.
   */
  async createNotification(params: CreateNotificationParams) {
    if (params.dedupKey) {
      const existing = await this.prisma.notification.findFirst({
        where: {
          businessId: params.businessId,
          dedupKey: params.dedupKey,
        },
      });

      if (existing) {
        return {
          created: false,
          deduplicated: true,
          notification: existing,
        };
      }
    }

    const created = await this.prisma.notification.create({
      data: {
        businessId: params.businessId,
        userId: params.userId || null,
        type: params.type.toUpperCase(),
        title: params.title,
        message: params.message,
        data: params.data ?? null,
        dedupKey: params.dedupKey || null,
        isRead: false,
      },
    });

    return {
      created: true,
      deduplicated: false,
      notification: created,
    };
  }

  /**
   * Retrieves paginated notifications for the tenant.
   */
  async getNotifications(businessId: string, query: QueryNotificationsDto) {
    const where: any = { businessId };
    if (query.isRead !== undefined) {
      where.isRead = query.isRead;
    }

    const limit = query.limit ?? 20;
    const offset = query.offset ?? 0;

    const [items, total, unreadCount] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip: offset,
      }),
      this.prisma.notification.count({ where }),
      this.prisma.notification.count({
        where: { businessId, isRead: false },
      }),
    ]);

    return {
      items,
      total,
      unreadCount,
      limit,
      offset,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Retrieves unread notification count.
   */
  async getUnreadCount(businessId: string): Promise<number> {
    return this.prisma.notification.count({
      where: { businessId, isRead: false },
    });
  }

  /**
   * Marks a single notification as read.
   */
  async markAsRead(businessId: string, id: string) {
    const notification = await this.prisma.notification.findFirst({
      where: { businessId, id },
    });

    if (!notification) {
      throw new NotFoundException(`Notification with ID ${id} not found.`);
    }

    return this.prisma.notification.update({
      where: { id },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });
  }

  /**
   * Marks all notifications as read for a business.
   */
  async markAllAsRead(businessId: string) {
    const updated = await this.prisma.notification.updateMany({
      where: { businessId, isRead: false },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });

    return {
      success: true,
      count: updated.count,
    };
  }

  /**
   * Scans products for low-stock thresholds and generates deduplicated alerts.
   */
  async scanLowStockAlerts(businessId: string) {
    const products = await this.prisma.product.findMany({
      where: { businessId, trackStock: true, status: 'ACTIVE' },
    });

    const todayStr = new Date().toISOString().split('T')[0];
    let createdCount = 0;

    for (const p of products) {
      const stock = Number(p.currentStock);
      const minLevel = Number(p.minStockLevel);

      if (stock <= minLevel) {
        const dedupKey = `LOW_STOCK:${p.id}:${todayStr}`;
        const res = await this.createNotification({
          businessId,
          type: 'LOW_STOCK',
          title: `Low Stock: ${p.name}`,
          message: `${p.name} has reached low stock level (${stock} remaining, minimum: ${minLevel}).`,
          data: {
            productId: p.id,
            currentStock: stock,
            minStockLevel: minLevel,
          },
          dedupKey,
        });

        if (res.created) {
          createdCount++;
        }
      }
    }

    return { scanned: products.length, alertsCreated: createdCount };
  }

  /**
   * Scans invoices for overdue receivables and generates deduplicated alerts.
   */
  async scanOverdueInvoices(businessId: string) {
    const now = new Date();
    const invoices = await this.prisma.invoice.findMany({
      where: {
        businessId,
        status: { notIn: ['PAID', 'CANCELLED', 'DRAFT'] },
        dueDate: { lt: now },
      },
      include: { customer: true },
    });

    const todayStr = now.toISOString().split('T')[0];
    let createdCount = 0;

    for (const inv of invoices) {
      const balance = Number(inv.balanceAmount);
      if (balance > 0) {
        const dedupKey = `OVERDUE_INVOICE:${inv.id}:${todayStr}`;
        const customerName = inv.customer?.name || 'Customer';
        const res = await this.createNotification({
          businessId,
          type: 'OVERDUE_INVOICE',
          title: `Overdue Invoice: ${inv.invoiceNumber}`,
          message: `Invoice ${inv.invoiceNumber} for ${customerName} of amount ₹${balance.toFixed(2)} is overdue.`,
          data: {
            invoiceId: inv.id,
            invoiceNumber: inv.invoiceNumber,
            balanceAmount: balance,
            dueDate: inv.dueDate,
          },
          dedupKey,
        });

        if (res.created) {
          createdCount++;
        }
      }
    }

    return { scanned: invoices.length, alertsCreated: createdCount };
  }
}

