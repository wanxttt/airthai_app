import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { QueryAuditLogsDto } from './dto/query-audit-logs.dto';

export interface CreateAuditLogParams {
  businessId: string;
  userId?: string;
  action: string;
  entityName: string;
  entityId: string;
  oldValues?: any;
  newValues?: any;
  ipAddress?: string;
  userAgent?: string;
}

const REDACTED_KEYWORDS = [
  'password',
  'token',
  'secret',
  'auth',
  'creditcard',
  'cardnumber',
  'cvv',
  'pin',
];

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Record a new audit log event with strict sanitization of sensitive values.
   * Append-only behavior is enforced — no modification or deletion is permitted.
   */
  async logEvent(params: CreateAuditLogParams) {
    try {
      const sanitizedOld = this.sanitize(params.oldValues);
      const sanitizedNew = this.sanitize(params.newValues);

      return await this.prisma.auditLog.create({
        data: {
          businessId: params.businessId,
          userId: params.userId || null,
          action: params.action.toUpperCase(),
          entityName: params.entityName.toUpperCase(),
          entityId: params.entityId,
          oldValues: sanitizedOld,
          newValues: sanitizedNew,
          ipAddress: params.ipAddress || null,
          userAgent: params.userAgent || null,
        },
      });
    } catch (err: any) {
      this.logger.error(`Failed to record audit log for ${params.action} on ${params.entityName}: ${err.message}`, err.stack);
      return null;
    }
  }

  /**
   * Retrieves paginated audit logs scoped strictly to the authenticated tenant.
   */
  async findAll(businessId: string, query: QueryAuditLogsDto) {
    const where: any = { businessId };

    if (query.entityName) {
      where.entityName = query.entityName.toUpperCase();
    }
    if (query.entityId) {
      where.entityId = query.entityId;
    }
    if (query.action) {
      where.action = query.action.toUpperCase();
    }
    if (query.userId) {
      where.userId = query.userId;
    }
    if (query.startDate || query.endDate) {
      where.timestamp = {};
      if (query.startDate) {
        where.timestamp.gte = new Date(query.startDate);
      }
      if (query.endDate) {
        where.timestamp.lte = new Date(query.endDate);
      }
    }

    const limit = query.limit ?? 50;
    const offset = query.offset ?? 0;

    const [items, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        include: {
          user: {
            select: {
              id: true,
              fullName: true,
              email: true,
            },
          },
        },
        orderBy: { timestamp: 'desc' },
        take: limit,
        skip: offset,
      }),
      this.prisma.auditLog.count({ where }),
    ]);

    return {
      items,
      total,
      limit,
      offset,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Deeply sanitizes an object by removing or masking sensitive fields.
   */
  sanitize(data: any): any {
    if (data === null || data === undefined) return null;
    if (typeof data !== 'object') return data;

    if (Array.isArray(data)) {
      return data.map((item) => this.sanitize(item));
    }

    const sanitized: Record<string, any> = {};
    for (const [key, value] of Object.entries(data)) {
      const normalizedKey = key.toLowerCase().replace(/[-_]/g, '');
      const isSensitive = REDACTED_KEYWORDS.some((kw) => normalizedKey.includes(kw));

      if (isSensitive) {
        sanitized[key] = '[REDACTED]';
      } else if (typeof value === 'object' && value !== null) {
        sanitized[key] = this.sanitize(value);
      } else {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }
}

