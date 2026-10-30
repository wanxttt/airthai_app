import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../database/prisma.service';

export interface JwtPayload {
  sub: string;
  email: string;
  businessId?: string;
  role?: string;
  iat?: number;
  exp?: number;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const secret = configService.get<string>('JWT_SECRET');
    const isProd = configService.get<string>('NODE_ENV') === 'production';
    if (isProd && (!secret || secret === 'replace_with_a_secure_random_64_char_secret_for_production')) {
      throw new Error('FATAL CONFIGURATION ERROR: JWT_SECRET must be configured with a secure key in production.');
    }

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret || 'replace_with_a_secure_random_64_char_secret_for_production',
    });
  }

  async validate(payload: JwtPayload): Promise<any> {
    if (!payload || !payload.sub) {
      throw new UnauthorizedException('Invalid token payload.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        id: true,
        email: true,
        fullName: true,
        phone: true,
        isActive: true,
        businessUsers: {
          select: {
            businessId: true,
            role: {
              select: {
                name: true,
              },
            },
          },
        },
      },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('User account is deactivated or not found.');
    }

    const activeMembership = user.businessUsers.find((bu) => bu.businessId === payload.businessId) || user.businessUsers[0];

    return {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      phone: user.phone,
      businessId: activeMembership?.businessId || payload.businessId,
      role: activeMembership?.role?.name || payload.role || 'OWNER',
    };
  }
}
