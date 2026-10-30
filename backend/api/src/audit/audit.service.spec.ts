import { Test, TestingModule } from '@nestjs/testing';
import { AuditService } from './audit.service';
import { PrismaService } from '../database/prisma.service';

describe('AuditService', () => {
  let service: AuditService;
  let prisma: any;

  const mockBusinessId = 'biz_audit_test_001';

  beforeEach(async () => {
    prisma = {
      auditLog: {
        create: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuditService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<AuditService>(AuditService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('logEvent', () => {
    it('creates an audit record with actor, business, action, and timestamps', async () => {
      prisma.auditLog.create.mockResolvedValue({ id: 'log_1' });

      await service.logEvent({
        businessId: mockBusinessId,
        userId: 'usr_actor_001',
        action: 'INVOICE_CREATED',
        entityName: 'INVOICE',
        entityId: 'inv_101',
        newValues: { invoiceNumber: 'INV-2026-27-0001', totalAmount: '5000.00' },
        ipAddress: '192.168.1.1',
        userAgent: 'Mozilla/5.0 Chrome',
      });

      expect(prisma.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          businessId: mockBusinessId,
          userId: 'usr_actor_001',
          action: 'INVOICE_CREATED',
          entityName: 'INVOICE',
          entityId: 'inv_101',
          newValues: { invoiceNumber: 'INV-2026-27-0001', totalAmount: '5000.00' },
          ipAddress: '192.168.1.1',
          userAgent: 'Mozilla/5.0 Chrome',
        }),
      });
    });

    it('strictly sanitizes passwords, tokens, and secrets from audit values', async () => {
      prisma.auditLog.create.mockResolvedValue({ id: 'log_2' });

      await service.logEvent({
        businessId: mockBusinessId,
        userId: 'usr_actor_001',
        action: 'USER_REGISTERED',
        entityName: 'USER',
        entityId: 'usr_102',
        newValues: {
          email: 'test@example.com',
          password: 'superSecretPassword123!',
          token: 'jwt-access-token-xyz',
          refreshToken: 'refresh-token-abc',
          nested: {
            apiKeySecret: 'secret_key_value',
            validData: 'safe_field',
          },
        },
      });

      expect(prisma.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          newValues: {
            email: 'test@example.com',
            password: '[REDACTED]',
            token: '[REDACTED]',
            refreshToken: '[REDACTED]',
            nested: {
              apiKeySecret: '[REDACTED]',
              validData: 'safe_field',
            },
          },
        }),
      });
    });
  });

  describe('findAll', () => {
    it('queries audit logs scoped strictly to caller businessId with filters', async () => {
      prisma.auditLog.findMany.mockResolvedValue([{ id: 'log_1' }]);
      prisma.auditLog.count.mockResolvedValue(1);

      const result = await service.findAll(mockBusinessId, {
        entityName: 'invoice',
        action: 'invoice_created',
        limit: 10,
        offset: 0,
      });

      expect(result.items).toHaveLength(1);
      expect(result.total).toBe(1);
      expect(prisma.auditLog.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            businessId: mockBusinessId,
            entityName: 'INVOICE',
            action: 'INVOICE_CREATED',
          },
          take: 10,
          skip: 0,
        }),
      );
    });

    it('enforces append-only immutability by not providing any delete or update methods', () => {
      expect((service as any).delete).toBeUndefined();
      expect((service as any).update).toBeUndefined();
      expect((service as any).deleteMany).toBeUndefined();
    });
  });
});

