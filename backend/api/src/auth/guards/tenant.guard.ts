import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';

@Injectable()
export class TenantGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user || !user.id) {
      throw new ForbiddenException('User is not authenticated.');
    }

    // Identify target business ID from params, body, query, or custom header
    const targetBusinessId =
      request.params?.businessId ||
      request.body?.businessId ||
      request.query?.businessId ||
      request.headers['x-business-id'];

    if (!targetBusinessId) {
      // No specific tenant requested, use user's active tenant
      return true;
    }

    // Verify user belongs to the target business in the database
    const membership = await this.prisma.businessUser.findUnique({
      where: {
        businessId_userId: {
          businessId: targetBusinessId,
          userId: user.id,
        },
      },
    });

    if (!membership || !membership.isActive) {
      throw new ForbiddenException(
        'Cross-tenant access denied: you do not have permission to access this business.',
      );
    }

    // Attach verified businessId to request
    request.businessId = targetBusinessId;
    return true;
  }
}
