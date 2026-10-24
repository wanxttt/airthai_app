import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthService, AuthResponse } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { BusinessSetupDto } from './dto/business-setup.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { RateLimitGuard } from './guards/rate-limit.guard';
import { Roles } from './decorators/roles.decorator';
import { RateLimit } from './decorators/rate-limit.decorator';

@Controller('auth')
@UseGuards(RateLimitGuard)
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @RateLimit({ limit: 10, ttlMs: 60000 })
  @HttpCode(HttpStatus.CREATED)
  async register(@Body() dto: RegisterDto): Promise<AuthResponse> {
    return await this.authService.register(dto);
  }

  @Post('login')
  @RateLimit({ limit: 15, ttlMs: 60000 })
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto): Promise<AuthResponse> {
    return await this.authService.login(dto);
  }

  @Post('refresh')
  @RateLimit({ limit: 20, ttlMs: 60000 })
  @HttpCode(HttpStatus.OK)
  async refreshToken(
    @Body() dto: RefreshTokenDto,
    @Headers('authorization') authHeader?: string,
  ): Promise<{ accessToken: string; refreshToken: string; expiresIn: number }> {
    return await this.authService.refreshToken(dto, authHeader);
  }

  @UseGuards(JwtAuthGuard)
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  async logout(
    @Req() req: any,
    @Body() dto?: RefreshTokenDto,
  ): Promise<{ success: boolean; message: string }> {
    return await this.authService.logout(req.user, dto?.refreshToken);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  @HttpCode(HttpStatus.OK)
  async getMe(@Req() req: any): Promise<Record<string, unknown>> {
    return await this.authService.getMe(req.user.id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('OWNER', 'ADMIN')
  @Patch('business-setup')
  @HttpCode(HttpStatus.OK)
  async updateBusinessSetup(
    @Req() req: any,
    @Body() dto: BusinessSetupDto,
  ): Promise<Record<string, unknown>> {
    const businessId = req.user.businessId;
    return await this.authService.updateBusinessSetup(req.user.id, businessId, dto);
  }
}
