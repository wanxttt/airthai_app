import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  Optional,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { BillFormat, TaxType } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import * as crypto from 'crypto';
import { PrismaService } from '../database/prisma.service';
import { TokenRevocationService } from './services/token-revocation.service';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { BusinessSetupDto } from './dto/business-setup.dto';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  token: string;
  expiresIn: number;
}

export interface AuthResponse extends AuthTokens {
  user: {
    id: string;
    email: string;
    fullName: string;
    phone?: string | null;
    businessId?: string | null;
    role: string;
  };
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly tokenRevocationService: TokenRevocationService,
    @Optional() private readonly subscriptionsService?: SubscriptionsService,
  ) {}

  private getJwtSecret(): string {
    const secret = this.configService.get<string>('JWT_SECRET');
    const isProd = this.configService.get<string>('NODE_ENV') === 'production';
    if (isProd && (!secret || secret === 'replace_with_a_secure_random_64_char_secret_for_production')) {
      throw new Error('FATAL CONFIGURATION ERROR: JWT_SECRET must be configured with a secure key in production.');
    }
    return secret || 'replace_with_a_secure_random_64_char_secret_for_production';
  }

  private getRefreshTokenSecret(): string {
    const refreshSecret = this.configService.get<string>('JWT_REFRESH_SECRET');
    const isProd = this.configService.get<string>('NODE_ENV') === 'production';

    if (refreshSecret && refreshSecret.trim().length > 0) {
      if (
        isProd &&
        (refreshSecret === 'replace_with_a_secure_random_64_char_secret_for_production' || refreshSecret.length < 32)
      ) {
        throw new Error(
          'FATAL CONFIGURATION ERROR: JWT_REFRESH_SECRET must be configured with at least 32 characters in production.',
        );
      }
      return refreshSecret.trim();
    }

    if (isProd) {
      throw new Error('FATAL CONFIGURATION ERROR: JWT_REFRESH_SECRET must be configured in production.');
    }

    return `${this.getJwtSecret()}_refresh`;
  }

  /**
   * Registers a new user, creates their primary business tenant, settings, default branch,
   * assigns OWNER role, and issues authentication tokens atomically.
   */
  async register(dto: RegisterDto): Promise<AuthResponse> {
    const cleanEmail = dto.email.trim().toLowerCase();
    const cleanPhone = dto.phone.trim();
    const cleanName = dto.fullName.trim();

    // 1. Verify email uniqueness
    const existingEmail = await this.prisma.user.findUnique({
      where: { email: cleanEmail },
    });
    if (existingEmail) {
      throw new ConflictException('An account with this email address already exists.');
    }

    // 2. Verify phone uniqueness if supplied
    if (cleanPhone) {
      const existingPhone = await this.prisma.user.findUnique({
        where: { phone: cleanPhone },
      });
      if (existingPhone) {
        throw new ConflictException('An account with this phone number already exists.');
      }
    }

    // 3. Hash password safely
    const passwordHash = await bcrypt.hash(dto.password, 10);

    // 4. Atomic tenant & user provision
    const result = await this.prisma.$transaction(async (tx) => {
      // Create user
      const user = await tx.user.create({
        data: {
          email: cleanEmail,
          phone: cleanPhone,
          passwordHash,
          fullName: cleanName,
          isActive: true,
        },
      });

      // Create primary business tenant
      const businessName = dto.businessName?.trim() || `${cleanName}'s Business`;
      const business = await tx.business.create({
        data: {
          name: businessName,
          email: cleanEmail,
          phone: cleanPhone,
          currency: 'INR',
          taxType: 'REGULAR',
        },
      });

      // Initialize tenant settings
      const now = new Date();
      const currentYear = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
      const financialYearStart = new Date(currentYear, 3, 1); // 1st April

      await tx.businessSettings.create({
        data: {
          businessId: business.id,
          trackInventory: true,
          allowNegativeStock: false,
          defaultBillFormat: 'A4_STANDARD',
          enableGst: true,
          defaultGstRate: 18.0,
          financialYearStart,
        },
      });

      // Create main branch
      const branch = await tx.branch.create({
        data: {
          businessId: business.id,
          name: 'Main Branch',
          isMain: true,
          isActive: true,
        },
      });

      // Find or assign OWNER system role
      let ownerRole = await tx.role.findFirst({
        where: {
          name: 'OWNER',
          isSystem: true,
          businessId: null,
        },
      });

      if (!ownerRole) {
        ownerRole = await tx.role.create({
          data: {
            businessId: business.id,
            name: 'OWNER',
            description: 'Business owner with unrestricted authority.',
            isSystem: false,
            permissions: ['*'],
          },
        });
      }

      // Link User to Business as Owner
      await tx.businessUser.create({
        data: {
          businessId: business.id,
          userId: user.id,
          roleId: ownerRole.id,
          defaultBranchId: branch.id,
          isActive: true,
        },
      });

      return {
        user,
        business,
        role: 'OWNER',
      };
    });

    const tokens = await this.generateTokenPair(
      result.user.id,
      result.user.email,
      result.business.id,
      result.role,
    );

    return {
      ...tokens,
      user: {
        id: result.user.id,
        email: result.user.email,
        fullName: result.user.fullName,
        phone: result.user.phone,
        businessId: result.business.id,
        role: result.role,
      },
    };
  }

  /**
   * Adds an existing user to an existing business tenant with the assigned role,
   * enforcing subscription user seat limits (SEC-AI-08).
   */
  async addUserToBusiness(businessId: string, userId: string, roleId: string, branchId?: string) {
    if (this.subscriptionsService) {
      await this.subscriptionsService.enforceUserLimit(businessId);
    }
    return this.prisma.businessUser.create({
      data: {
        businessId,
        userId,
        roleId,
        defaultBranchId: branchId,
        isActive: true,
      },
    });
  }

  /**
   * Authenticates user credentials using constant-time password comparison,
   * returns generic errors to prevent account enumeration, and issues access & refresh tokens.
   */
  async login(dto: LoginDto): Promise<AuthResponse> {
    const cleanEmail = dto.email.trim().toLowerCase();

    const user = await this.prisma.user.findUnique({
      where: { email: cleanEmail },
      include: {
        businessUsers: {
          include: {
            role: true,
            business: true,
          },
        },
      },
    });

    // Constant-time check: generic failure if user not found or deactivated
    if (!user || !user.isActive) {
      // Execute dummy compare to mitigate timing attacks
      await bcrypt.compare(dto.password, '$2a$10$abcdefghijklmnopqrstuvwxyz1234567890ABCDEF');
      throw new UnauthorizedException('Invalid email or password.');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password.');
    }

    // Determine primary business membership and role
    const primaryMembership = user.businessUsers[0];
    const businessId = primaryMembership?.businessId || null;
    const role = primaryMembership?.role?.name || 'OWNER';

    const tokens = await this.generateTokenPair(user.id, user.email, businessId ?? undefined, role);

    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        phone: user.phone,
        businessId,
        role,
      },
    };
  }

  /**
   * Rotates refresh token with reuse detection.
   * If a rotated token is reused, all tokens in the family are immediately revoked.
   */
  async refreshToken(dto: RefreshTokenDto, authHeader?: string): Promise<{
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
  }> {
    let rawToken = dto.refreshToken;
    if (!rawToken && authHeader && authHeader.startsWith('Bearer ')) {
      rawToken = authHeader.substring(7).trim();
    }

    if (!rawToken) {
      throw new UnauthorizedException('Refresh token is required.');
    }

    let payload: any;
    try {
      payload = this.jwtService.verify(rawToken, {
        secret: this.getRefreshTokenSecret(),
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token.');
    }

    const { sub: userId, email, businessId, role, jti, family } = payload;
    if (!userId || !jti || !family) {
      throw new UnauthorizedException('Malformed refresh token payload.');
    }

    const newJti = crypto.randomUUID();
    const ttlMs = 7 * 24 * 60 * 60 * 1000; // 7 days

    const success = await this.tokenRevocationService.rotateRefreshToken(
      jti,
      newJti,
      family,
      userId,
      ttlMs,
    );

    if (!success) {
      throw new UnauthorizedException('Refresh token has expired, been revoked, or was already used.');
    }

    const newTokens = this.generateTokenPairWithFamily(
      userId,
      email,
      businessId,
      role,
      family,
      newJti,
      ttlMs,
    );

    return {
      accessToken: newTokens.accessToken,
      refreshToken: newTokens.refreshToken,
      expiresIn: newTokens.expiresIn,
    };
  }

  /**
   * Revokes the user's refresh token family on logout.
   */
  async logout(user: { id: string }, refreshToken?: string): Promise<{ success: boolean; message: string }> {
    if (refreshToken) {
      try {
        const payload = this.jwtService.decode(refreshToken) as any;
        if (payload?.family) {
          await this.tokenRevocationService.revokeFamily(payload.family);
        }
      } catch {
        // Continue with user-level revocation
      }
    }

    await this.tokenRevocationService.revokeAllForUser(user.id);
    return {
      success: true,
      message: 'Logged out successfully.',
    };
  }

  /**
   * Returns current authenticated user profile and business memberships.
   */
  async getMe(userId: string): Promise<Record<string, unknown>> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        fullName: true,
        phone: true,
        avatarUrl: true,
        isActive: true,
        createdAt: true,
        businessUsers: {
          select: {
            businessId: true,
            defaultBranchId: true,
            role: {
              select: {
                name: true,
                permissions: true,
              },
            },
            business: {
              select: {
                id: true,
                name: true,
                gstin: true,
                taxType: true,
                currency: true,
              },
            },
          },
        },
      },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('User account is inactive or not found.');
    }

    const primaryMembership = user.businessUsers[0];

    return {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      phone: user.phone,
      avatarUrl: user.avatarUrl,
      businessId: primaryMembership?.businessId || null,
      businessName: primaryMembership?.business?.name || null,
      role: primaryMembership?.role?.name || 'OWNER',
      permissions: primaryMembership?.role?.permissions || [],
      businesses: user.businessUsers.map((bu) => ({
        businessId: bu.businessId,
        businessName: bu.business?.name,
        role: bu.role?.name,
        taxType: bu.business?.taxType,
      })),
    };
  }

  /**
   * Updates business tenant setup, profile, and GST preferences after registration.
   * Only permitted for authorized OWNER or ADMIN members of that business.
   */
  async updateBusinessSetup(
    userId: string,
    businessId: string,
    dto: BusinessSetupDto,
  ): Promise<Record<string, unknown>> {
    const membership = await this.prisma.businessUser.findUnique({
      where: {
        businessId_userId: {
          businessId,
          userId,
        },
      },
      include: { role: true },
    });

    if (!membership || !['OWNER', 'ADMIN'].includes(membership.role?.name || '')) {
      throw new ForbiddenException(
        'Only an authorized business OWNER or ADMIN can modify business settings.',
      );
    }

    return await this.prisma.$transaction(async (tx) => {
      const updatedBusiness = await tx.business.update({
        where: { id: businessId },
        data: {
          name: dto.businessName || undefined,
          legalName: dto.legalName || undefined,
          gstin: dto.gstin || undefined,
          pan: dto.pan || undefined,
          addressLine1: dto.addressLine1 || undefined,
          city: dto.city || undefined,
          state: dto.state || undefined,
          stateCode: dto.stateCode || undefined,
          pincode: dto.pincode || undefined,
          taxType: dto.taxType || undefined,
        },
      });

      if (dto.defaultBillFormat || dto.taxType !== undefined) {
        await tx.businessSettings.upsert({
          where: { businessId },
          update: {
            defaultBillFormat: dto.defaultBillFormat || undefined,
            enableGst: dto.taxType ? dto.taxType !== TaxType.UNREGISTERED : undefined,
          },
          create: {
            businessId,
            defaultBillFormat: dto.defaultBillFormat || BillFormat.A4_STANDARD,
            enableGst: dto.taxType ? dto.taxType !== TaxType.UNREGISTERED : true,
            financialYearStart: new Date(new Date().getFullYear(), 3, 1),
          },
        });
      }

      return {
        success: true,
        message: 'Business profile and setup updated successfully.',
        business: updatedBusiness,
      };
    });
  }

  private async generateTokenPair(
    userId: string,
    email: string,
    businessId?: string,
    role: string = 'OWNER',
  ): Promise<AuthTokens> {
    const family = crypto.randomUUID();
    const jti = crypto.randomUUID();
    const ttlMs = 7 * 24 * 60 * 60 * 1000; // 7 days

    await this.tokenRevocationService.registerRefreshToken(jti, family, userId, ttlMs);
    return this.generateTokenPairWithFamily(userId, email, businessId, role, family, jti, ttlMs);
  }

  private generateTokenPairWithFamily(
    userId: string,
    email: string,
    businessId: string | undefined,
    role: string,
    family: string,
    jti: string,
    ttlMs: number,
  ): AuthTokens {
    const accessTokenPayload = {
      sub: userId,
      email,
      businessId,
      role,
    };

    const accessToken = this.jwtService.sign(accessTokenPayload, {
      secret: this.getJwtSecret(),
      expiresIn: '1h',
    });

    const refreshTokenPayload = {
      sub: userId,
      email,
      businessId,
      role,
      family,
      jti,
    };

    const refreshToken = this.jwtService.sign(refreshTokenPayload, {
      secret: this.getRefreshTokenSecret(),
      expiresIn: '7d',
    });

    return {
      accessToken,
      refreshToken,
      token: accessToken,
      expiresIn: 3600,
    };
  }
}

