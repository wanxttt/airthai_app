import { ConflictException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';
import { PrismaService } from '../database/prisma.service';
import { TokenRevocationService } from './services/token-revocation.service';

describe('AuthService', () => {
  let service: AuthService;
  let mockPrisma: any;
  let jwtService: JwtService;
  let revocationService: TokenRevocationService;

  beforeEach(async () => {
    mockPrisma = {
      user: {
        findUnique: jest.fn(),
        create: jest.fn(),
      },
      business: {
        create: jest.fn(),
        update: jest.fn(),
      },
      businessSettings: {
        create: jest.fn(),
        upsert: jest.fn(),
      },
      branch: {
        create: jest.fn(),
      },
      role: {
        findFirst: jest.fn(),
        create: jest.fn(),
      },
      businessUser: {
        create: jest.fn(),
        findUnique: jest.fn(),
      },
      $transaction: jest.fn((callback) => callback(mockPrisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        TokenRevocationService,
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
        {
          provide: JwtService,
          useValue: {
            sign: jest.fn(() => 'signed_mock_jwt_token'),
            verify: jest.fn(),
            decode: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    jwtService = module.get<JwtService>(JwtService);
    revocationService = module.get<TokenRevocationService>(TokenRevocationService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('register', () => {
    it('should reject registration if email is already taken', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: 'usr_existing',
        email: 'taken@airthai.in',
      });

      await expect(
        service.register({
          fullName: 'Test User',
          email: 'taken@airthai.in',
          phone: '9876543210',
          password: 'Password@123',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('should atomically create user, business, settings, branch, role and return tokens', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      mockPrisma.user.create.mockResolvedValue({
        id: 'usr_1',
        email: 'newuser@airthai.in',
        fullName: 'New User',
        phone: '9876543210',
      });
      mockPrisma.business.create.mockResolvedValue({
        id: 'biz_1',
        name: "New User's Business",
      });
      mockPrisma.businessSettings.create.mockResolvedValue({ id: 'set_1' });
      mockPrisma.branch.create.mockResolvedValue({ id: 'br_1' });
      mockPrisma.role.findFirst.mockResolvedValue({ id: 'role_owner', name: 'OWNER' });
      mockPrisma.businessUser.create.mockResolvedValue({ id: 'bu_1' });

      const result = await service.register({
        fullName: 'New User',
        email: 'NewUser@Airthai.IN ', // test normalization
        phone: '9876543210',
        password: 'Password@123',
      });

      expect(mockPrisma.$transaction).toHaveBeenCalled();
      expect(mockPrisma.user.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            email: 'newuser@airthai.in',
          }),
        }),
      );
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(result.user).toEqual(
        expect.objectContaining({
          id: 'usr_1',
          email: 'newuser@airthai.in',
          businessId: 'biz_1',
          role: 'OWNER',
        }),
      );
    });
  });

  describe('login', () => {
    it('should throw UnauthorizedException with generic message if user is not found', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);

      await expect(
        service.login({
          email: 'unknown@airthai.in',
          password: 'AnyPassword123',
        }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException with generic message if password does not match', async () => {
      const hash = await bcrypt.hash('CorrectPassword123', 10);
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: 'usr_1',
        email: 'user@airthai.in',
        passwordHash: hash,
        isActive: true,
        businessUsers: [],
      });

      await expect(
        service.login({
          email: 'user@airthai.in',
          password: 'WrongPassword123',
        }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should succeed and return token payload if password matches', async () => {
      const password = 'CorrectPassword123';
      const hash = await bcrypt.hash(password, 10);

      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: 'usr_1',
        email: 'user@airthai.in',
        fullName: 'Test User',
        passwordHash: hash,
        isActive: true,
        businessUsers: [
          {
            businessId: 'biz_1',
            role: { name: 'OWNER' },
            business: { id: 'biz_1', name: 'Biz One' },
          },
        ],
      });

      const result = await service.login({
        email: 'User@Airthai.IN',
        password,
      });

      expect(result).toHaveProperty('accessToken');
      expect(result.user).toEqual(
        expect.objectContaining({
          id: 'usr_1',
          email: 'user@airthai.in',
          businessId: 'biz_1',
          role: 'OWNER',
        }),
      );
    });
  });

  describe('refreshToken & rotation reuse detection', () => {
    it('should rotate valid refresh token', async () => {
      const family = 'fam_123';
      const jti = 'jti_old';
      const userId = 'usr_1';

      await revocationService.registerRefreshToken(jti, family, userId, 100000);

      jest.spyOn(jwtService, 'verify').mockReturnValueOnce({
        sub: userId,
        email: 'user@airthai.in',
        businessId: 'biz_1',
        role: 'OWNER',
        jti,
        family,
      });

      const result = await service.refreshToken({ refreshToken: 'valid_refresh_token' });

      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
    });

    it('should detect token reuse, revoke the family, and throw UnauthorizedException', async () => {
      const family = 'fam_reuse_test';
      const jti = 'jti_original';
      const userId = 'usr_2';

      await revocationService.registerRefreshToken(jti, family, userId, 100000);

      // First rotation succeeds
      await revocationService.rotateRefreshToken(jti, 'jti_next', family, userId, 100000);

      // Now someone tries to reuse jti_original
      jest.spyOn(jwtService, 'verify').mockReturnValueOnce({
        sub: userId,
        email: 'user@airthai.in',
        businessId: 'biz_1',
        role: 'OWNER',
        jti,
        family,
      });

      await expect(
        service.refreshToken({ refreshToken: 'reused_token' }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('getMe', () => {
    it('should return sanitized user profile and business memberships', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: 'usr_1',
        email: 'user@airthai.in',
        fullName: 'Test User',
        phone: '9876543210',
        isActive: true,
        businessUsers: [
          {
            businessId: 'biz_1',
            role: { name: 'OWNER', permissions: ['*'] },
            business: { id: 'biz_1', name: 'Biz One', gstin: '27AAAAA0000A1Z5', taxType: 'REGULAR' },
          },
        ],
      });

      const result = await service.getMe('usr_1');

      expect(result).toHaveProperty('id', 'usr_1');
      expect(result).toHaveProperty('businessId', 'biz_1');
      expect(result).toHaveProperty('businessName', 'Biz One');
      expect(result).toHaveProperty('role', 'OWNER');
    });
  });

  describe('updateBusinessSetup', () => {
    it('should throw ForbiddenException if user is not OWNER or ADMIN', async () => {
      mockPrisma.businessUser.findUnique.mockResolvedValueOnce({
        role: { name: 'STAFF' },
      });

      await expect(
        service.updateBusinessSetup('usr_staff', 'biz_1', { businessName: 'Hacked' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should update business and settings if user is OWNER', async () => {
      mockPrisma.businessUser.findUnique.mockResolvedValueOnce({
        role: { name: 'OWNER' },
      });
      mockPrisma.business.update.mockResolvedValueOnce({
        id: 'biz_1',
        name: 'Updated Enterprise',
        gstin: '27AAAAA0000A1Z5',
      });
      mockPrisma.businessSettings.upsert.mockResolvedValueOnce({
        businessId: 'biz_1',
      });

      const result = await service.updateBusinessSetup('usr_1', 'biz_1', {
        businessName: 'Updated Enterprise',
        gstin: '27AAAAA0000A1Z5',
      });

      expect(result.success).toBe(true);
      expect((result as any).business.name).toBe('Updated Enterprise');
    });
  });

  describe('addUserToBusiness (SEC-AI-08)', () => {
    it('enforces subscription user quota when adding team member to business', async () => {
      mockPrisma.businessUser.create.mockResolvedValueOnce({ id: 'bu_member_1' });

      const result = await service.addUserToBusiness('biz_1', 'usr_2', 'role_cashier');
      expect(mockPrisma.businessUser.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          businessId: 'biz_1',
          userId: 'usr_2',
          roleId: 'role_cashier',
        }),
      });
      expect(result).toHaveProperty('id', 'bu_member_1');
    });
  });

  describe('JWT Key Separation & Secret Hygiene', () => {
    it('uses dedicated JWT_REFRESH_SECRET when provided', async () => {
      const configService = {
        get: jest.fn((key: string) => {
          if (key === 'JWT_SECRET') return 'primary_jwt_secret_32_characters_long!';
          if (key === 'JWT_REFRESH_SECRET') return 'independent_refresh_key_32_chars_long!';
          return null;
        }),
      } as any;

      const customService = new AuthService(
        mockPrisma,
        jwtService,
        configService,
        revocationService,
      );

      mockPrisma.user.findUnique.mockResolvedValueOnce(null);
      mockPrisma.user.create.mockResolvedValueOnce({
        id: 'usr_new',
        email: 'keysep@example.com',
        fullName: 'Key Separation',
        passwordHash: 'hash',
      });
      mockPrisma.business.create.mockResolvedValueOnce({ id: 'biz_new', name: 'Biz' });
      mockPrisma.businessSettings.create.mockResolvedValueOnce({ businessId: 'biz_new' });
      mockPrisma.branch.create.mockResolvedValueOnce({ id: 'branch_new' });
      mockPrisma.role.findFirst.mockResolvedValueOnce({ id: 'role_owner', name: 'OWNER' });
      mockPrisma.businessUser.create.mockResolvedValueOnce({ id: 'bu_owner' });

      await customService.register({
        email: 'keysep@example.com',
        password: 'Password123!',
        fullName: 'Key Separation',
        phone: '9876543210',
        businessName: 'Biz',
      });

      expect(jwtService.sign).toHaveBeenCalledWith(
        expect.objectContaining({ sub: 'usr_new' }),
        expect.objectContaining({ secret: 'independent_refresh_key_32_chars_long!' }),
      );
    });

    it('rejects missing JWT_REFRESH_SECRET in production environment', async () => {
      const prodConfigService = {
        get: jest.fn((key: string) => {
          if (key === 'JWT_SECRET') return 'primary_jwt_secret_32_characters_long!';
          if (key === 'NODE_ENV') return 'production';
          if (key === 'JWT_REFRESH_SECRET') return null;
          return null;
        }),
      } as any;

      const prodService = new AuthService(
        mockPrisma,
        jwtService,
        prodConfigService,
        revocationService,
      );

      mockPrisma.user.findUnique.mockResolvedValueOnce(null);
      mockPrisma.user.create.mockResolvedValueOnce({
        id: 'usr_new',
        email: 'prod@example.com',
        fullName: 'Prod User',
        passwordHash: 'hash',
      });
      mockPrisma.business.create.mockResolvedValueOnce({ id: 'biz_new', name: 'Biz' });
      mockPrisma.businessSettings.create.mockResolvedValueOnce({ businessId: 'biz_new' });
      mockPrisma.branch.create.mockResolvedValueOnce({ id: 'branch_new' });
      mockPrisma.role.findFirst.mockResolvedValueOnce({ id: 'role_owner', name: 'OWNER' });
      mockPrisma.businessUser.create.mockResolvedValueOnce({ id: 'bu_owner' });

      await expect(
        prodService.register({
          email: 'prod@example.com',
          password: 'Password123!',
          fullName: 'Prod User',
          phone: '9876543210',
          businessName: 'Biz',
        }),
      ).rejects.toThrow('FATAL CONFIGURATION ERROR: JWT_REFRESH_SECRET must be configured in production.');
    });
  });
});

