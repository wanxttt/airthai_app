import { UnauthorizedException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JwtStrategy } from './jwt.strategy';
import { PrismaService } from '../../database/prisma.service';

describe('JwtStrategy & Tenant Authorization', () => {
  let strategy: JwtStrategy;
  let mockPrisma: any;

  beforeEach(async () => {
    mockPrisma = {
      user: {
        findUnique: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JwtStrategy,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) => {
              if (key === 'JWT_SECRET') return 'test_jwt_secret_1234567890_abcdefghij';
              return null;
            }),
          },
        },
      ],
    }).compile();

    strategy = module.get<JwtStrategy>(JwtStrategy);
  });

  it('should be defined', () => {
    expect(strategy).toBeDefined();
  });

  it('should validate valid user payload with correct tenant membership', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      id: 'usr_1',
      email: 'owner@airthai.in',
      fullName: 'Owner One',
      phone: '9876543210',
      isActive: true,
      businessUsers: [
        {
          businessId: 'biz_1',
          role: { name: 'OWNER' },
        },
      ],
    });

    const user = await strategy.validate({
      sub: 'usr_1',
      email: 'owner@airthai.in',
      businessId: 'biz_1',
      role: 'OWNER',
    });

    expect(user.id).toBe('usr_1');
    expect(user.businessId).toBe('biz_1');
    expect(user.role).toBe('OWNER');
  });

  it('should reject deactivated user with UnauthorizedException', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      id: 'usr_inactive',
      email: 'inactive@airthai.in',
      isActive: false,
      businessUsers: [],
    });

    await expect(
      strategy.validate({
        sub: 'usr_inactive',
        email: 'inactive@airthai.in',
      }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('should deny unauthorized cross-tenant business ID if user is not a member of that business', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      id: 'usr_1',
      email: 'owner@airthai.in',
      fullName: 'Owner One',
      isActive: true,
      businessUsers: [
        {
          businessId: 'biz_authorized',
          role: { name: 'OWNER' },
        },
      ],
    });

    // User attempts to claim access to 'biz_unauthorized_victim'
    const result = await strategy.validate({
      sub: 'usr_1',
      email: 'owner@airthai.in',
      businessId: 'biz_unauthorized_victim',
      role: 'ADMIN',
    });

    // Strategy must fall back to authorized membership or deny privilege escalation
    expect(result.businessId).toBe('biz_authorized');
    expect(result.role).toBe('OWNER');
  });
});

