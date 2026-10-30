import {
  Controller,
  Get,
  Post,
  Body,
  Headers,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
  BadRequestException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { RateLimitGuard } from '../auth/guards/rate-limit.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { RateLimit } from '../auth/decorators/rate-limit.decorator';
import { SubscriptionsService } from './subscriptions.service';
import { ChangePlanDto } from './dto/change-plan.dto';
import { CreateCheckoutDto } from './dto/create-checkout.dto';
import { VerifyPaymentDto } from './dto/verify-payment.dto';

@Controller('subscriptions')
@UseGuards(RateLimitGuard)
export class SubscriptionsController {
  constructor(private readonly subscriptionsService: SubscriptionsService) {}

  @Get('current')
  @UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async getCurrent(@CurrentUser('businessId') businessId: string) {
    const data = await this.subscriptionsService.getCurrentSubscription(businessId);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data,
    };
  }

  @Get('plans')
  @UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async getPlans() {
    const plans = await this.subscriptionsService.getPlans();
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: plans,
    };
  }

  @Post('change-plan')
  @UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
  @HttpCode(HttpStatus.OK)
  @Roles('OWNER', 'ADMIN')
  async changePlan(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: ChangePlanDto,
  ) {
    const updated = await this.subscriptionsService.changePlan(businessId, dto.planId, userId);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: updated,
    };
  }

  @Post('checkout')
  @UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
  @RateLimit({ limit: 20, ttlMs: 60000 })
  @HttpCode(HttpStatus.CREATED)
  @Roles('OWNER', 'ADMIN')
  async createCheckout(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateCheckoutDto,
  ) {
    const checkout = await this.subscriptionsService.createCheckout(businessId, userId, dto);
    return {
      success: true,
      statusCode: HttpStatus.CREATED,
      data: checkout,
    };
  }

  @Post('verify')
  @UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
  @RateLimit({ limit: 20, ttlMs: 60000 })
  @HttpCode(HttpStatus.OK)
  @Roles('OWNER', 'ADMIN')
  async verifyPayment(
    @CurrentUser('businessId') businessId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: VerifyPaymentDto,
  ) {
    const result = await this.subscriptionsService.verifyPayment(businessId, userId, dto);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: result,
    };
  }

  @Post('webhook')
  @RateLimit({ limit: 120, ttlMs: 60000 })
  @HttpCode(HttpStatus.OK)
  async handleWebhook(
    @Headers('x-razorpay-signature') signature: string,
    @Req() req: any,
    @Body() payload: any,
  ) {
    if (!signature) {
      throw new BadRequestException('Missing x-razorpay-signature header.');
    }
    const rawBody = req.rawBody || JSON.stringify(payload);
    const result = await this.subscriptionsService.handleWebhook(rawBody, signature, payload);
    return {
      success: true,
      statusCode: HttpStatus.OK,
      data: result,
    };
  }
}
