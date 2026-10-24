import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { TokenRevocationService } from './services/token-revocation.service';
import { RateLimitGuard } from './guards/rate-limit.guard';
import { RolesGuard } from './guards/roles.guard';
import { TenantGuard } from './guards/tenant.guard';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [
    DatabaseModule,
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret:
          configService.get<string>('JWT_SECRET') ||
          'replace_with_a_secure_random_64_char_secret_for_production',
        signOptions: {
          expiresIn: configService.get<string>('JWT_EXPIRES_IN') || '3600s',
        },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    TokenRevocationService,
    RateLimitGuard,
    RolesGuard,
    TenantGuard,
  ],
  exports: [
    AuthService,
    JwtStrategy,
    PassportModule,
    JwtModule,
    RateLimitGuard,
    RolesGuard,
    TenantGuard,
  ],
})
export class AuthModule {}

