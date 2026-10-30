import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    const request = context.switchToHttp().getRequest();
    const method = request.method;

    if (!requiredRoles || requiredRoles.length === 0) {
      // Fail closed: Mutating operations MUST have an explicit role policy defined
      if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
        throw new ForbiddenException(
          `Access denied: Mutating route ${method} ${request.url} requires an explicit role policy.`,
        );
      }
      // Read-only queries without an explicit role policy are accessible to any authenticated tenant member
      return true;
    }

    const user = request.user;

    if (!user || !user.role) {
      throw new ForbiddenException('User has no assigned role.');
    }

    const hasRole = requiredRoles.includes(user.role);
    if (!hasRole) {
      throw new ForbiddenException(
        `Insufficient permissions: action requires role in [${requiredRoles.join(', ')}], current role is ${user.role}.`,
      );
    }

    return true;
  }
}
