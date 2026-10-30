import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsService } from './notifications.service';
import { PrismaService } from '../database/prisma.service';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let prisma: any;

  const mockBusinessId = 'biz_notif_test_001';

  beforeEach(async () => {
    prisma = {
      notification: {
        create: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
      product: {
        findMany: jest.fn(),
      },
      invoice: {
        findMany: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<NotificationsService>(NotificationsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createNotification & Deduplication', () => {
    it('creates a notification when no dedupKey exists', async () => {
      prisma.notification.create.mockResolvedValue({ id: 'notif_1', title: 'Low Stock' });

      const result = await service.createNotification({
        businessId: mockBusinessId,
        type: 'LOW_STOCK',
        title: 'Low Stock Alert',
        message: 'Product stock is low',
      });

      expect(result.created).toBe(true);
      expect(result.deduplicated).toBe(false);
      expect(prisma.notification.create).toHaveBeenCalled();
    });

    it('prevents duplicate notification creation when dedupKey already exists', async () => {
      const dedupKey = 'LOW_STOCK:prod_1:2026-10-26';
      prisma.notification.findFirst.mockResolvedValue({
        id: 'existing_notif_1',
        dedupKey,
      });

      const result = await service.createNotification({
        businessId: mockBusinessId,
        type: 'LOW_STOCK',
        title: 'Low Stock Alert',
        message: 'Product stock is low',
        dedupKey,
      });

      expect(result.created).toBe(false);
      expect(result.deduplicated).toBe(true);
      expect(prisma.notification.create).not.toHaveBeenCalled();
    });
  });

  describe('scanLowStockAlerts', () => {
    it('scans products and creates deduplicated alerts for items at or below minStockLevel', async () => {
      prisma.product.findMany.mockResolvedValue([
        { id: 'p1', name: 'Item Low', currentStock: 2, minStockLevel: 5 },
        { id: 'p2', name: 'Item High', currentStock: 20, minStockLevel: 5 },
      ]);
      prisma.notification.findFirst.mockResolvedValue(null); // not yet created
      prisma.notification.create.mockResolvedValue({ id: 'notif_p1' });

      const result = await service.scanLowStockAlerts(mockBusinessId);

      expect(result.scanned).toBe(2);
      expect(result.alertsCreated).toBe(1);
      expect(prisma.notification.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            businessId: mockBusinessId,
            type: 'LOW_STOCK',
            title: 'Low Stock: Item Low',
          }),
        }),
      );
    });
  });

  describe('scanOverdueInvoices', () => {
    it('scans invoices and creates alerts for past due invoices with positive balance', async () => {
      prisma.invoice.findMany.mockResolvedValue([
        {
          id: 'inv_overdue_1',
          invoiceNumber: 'INV-2026-27-0010',
          balanceAmount: 2500,
          dueDate: new Date('2026-10-01'),
          customer: { name: 'Acme Corp' },
        },
      ]);
      prisma.notification.findFirst.mockResolvedValue(null);
      prisma.notification.create.mockResolvedValue({ id: 'notif_inv_1' });

      const result = await service.scanOverdueInvoices(mockBusinessId);

      expect(result.scanned).toBe(1);
      expect(result.alertsCreated).toBe(1);
      expect(prisma.notification.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            businessId: mockBusinessId,
            type: 'OVERDUE_INVOICE',
            title: 'Overdue Invoice: INV-2026-27-0010',
          }),
        }),
      );
    });
  });

  describe('markAsRead & markAllAsRead', () => {
    it('marks a single notification as read', async () => {
      prisma.notification.findFirst.mockResolvedValue({ id: 'notif_1', businessId: mockBusinessId });
      prisma.notification.update.mockResolvedValue({ id: 'notif_1', isRead: true });

      const result = await service.markAsRead(mockBusinessId, 'notif_1');

      expect(result.isRead).toBe(true);
      expect(prisma.notification.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'notif_1' },
          data: expect.objectContaining({ isRead: true }),
        }),
      );
    });

    it('marks all notifications as read for business', async () => {
      prisma.notification.updateMany.mockResolvedValue({ count: 5 });

      const result = await service.markAllAsRead(mockBusinessId);

      expect(result.success).toBe(true);
      expect(result.count).toBe(5);
    });
  });
});

