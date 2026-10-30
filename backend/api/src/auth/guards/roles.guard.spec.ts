import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from './roles.guard';
import { ROLES_KEY } from '../decorators/roles.decorator';

describe('RolesGuard Security Enforcement', () => {
  let guard: RolesGuard;
  let reflector: jest.Mocked<Reflector>;

  beforeEach(() => {
    reflector = {
      getAllAndOverride: jest.fn(),
    } as any;
    guard = new RolesGuard(reflector);
  });

  const createMockContext = (method: string, user?: { id: string; role: string }) => {
    return {
      getHandler: jest.fn(),
      getClass: jest.fn(),
      switchToHttp: () => ({
        getRequest: () => ({
          method,
          url: '/api/v1/test-endpoint',
          user,
        }),
      }),
    } as unknown as ExecutionContext;
  };

  describe('Fail-Closed Mutating Route Protection', () => {
    it('MUST reject mutating POST requests when @Roles decorator is omitted (fail-closed)', () => {
      reflector.getAllAndOverride.mockReturnValue(undefined); // No @Roles declared
      const ctx = createMockContext('POST', { id: 'usr-1', role: 'STAFF' });

      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });

    it('MUST reject mutating DELETE requests when @Roles decorator is omitted (fail-closed)', () => {
      reflector.getAllAndOverride.mockReturnValue([]); // Empty @Roles array
      const ctx = createMockContext('DELETE', { id: 'usr-1', role: 'STAFF' });

      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });

    it('MUST allow read-only GET requests when @Roles decorator is omitted', () => {
      reflector.getAllAndOverride.mockReturnValue(undefined);
      const ctx = createMockContext('GET', { id: 'usr-1', role: 'STAFF' });

      expect(guard.canActivate(ctx)).toBe(true);
    });
  });

  describe('Role-Based Access Enforcement', () => {
    it('MUST permit user when user role matches declared @Roles policy', () => {
      reflector.getAllAndOverride.mockReturnValue(['OWNER', 'ADMIN']);
      const ctx = createMockContext('POST', { id: 'usr-admin', role: 'ADMIN' });

      expect(guard.canActivate(ctx)).toBe(true);
    });

    it('MUST block user with HTTP 403 when user role is not in declared @Roles policy', () => {
      reflector.getAllAndOverride.mockReturnValue(['OWNER', 'ADMIN']);
      const ctx = createMockContext('POST', { id: 'usr-staff', role: 'STAFF' });

      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });

    it('MUST throw ForbiddenException if user identity is missing or has no role', () => {
      reflector.getAllAndOverride.mockReturnValue(['OWNER']);
      const ctx = createMockContext('POST', undefined); // No user

      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });
  });
});

