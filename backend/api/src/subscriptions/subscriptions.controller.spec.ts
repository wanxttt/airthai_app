import { Test, TestingModule } from '@nestjs/testing';
import { SubscriptionsController } from './subscriptions.controller';
import { SubscriptionsService } from './subscriptions.service';
import { BadRequestException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { RateLimitGuard } from '../auth/guards/rate-limit.guard';

describe('SubscriptionsController', () => {
  let controller: SubscriptionsController;
  let service: any;

  const mockBusinessId = 'biz_test_001';
  const mockUserId = 'usr_owner_001';

  beforeEach(async () => {
    service = {
      getCurrentSubscription: jest.fn(),
      getPlans: jest.fn(),
      changePlan: jest.fn(),
      createCheckout: jest.fn(),
      verifyPayment: jest.fn(),
      handleWebhook: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SubscriptionsController],
      providers: [{ provide: SubscriptionsService, useValue: service }],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(RolesGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(TenantGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(RateLimitGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<SubscriptionsController>(SubscriptionsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('getCurrent', () => {
    it('returns subscription data for authenticated tenant', async () => {
      service.getCurrentSubscription.mockResolvedValue({ status: 'ACTIVE' });
      const res = await controller.getCurrent(mockBusinessId);
      expect(res.statusCode).toBe(HttpStatus.OK);
      expect(res.data).toEqual({ status: 'ACTIVE' });
      expect(service.getCurrentSubscription).toHaveBeenCalledWith(mockBusinessId);
    });
  });

  describe('getPlans', () => {
    it('returns available plans list', async () => {
      service.getPlans.mockResolvedValue([{ id: 'plan_1' }]);
      const res = await controller.getPlans();
      expect(res.statusCode).toBe(HttpStatus.OK);
      expect(res.data).toHaveLength(1);
    });
  });

  describe('changePlan', () => {
    it('delegates free plan change to service with user ID', async () => {
      service.changePlan.mockResolvedValue({ id: 'sub_1', planId: 'plan_starter_dev' });
      const res = await controller.changePlan(mockBusinessId, mockUserId, {
        planId: 'plan_starter_dev',
      });
      expect(res.statusCode).toBe(HttpStatus.OK);
      expect(service.changePlan).toHaveBeenCalledWith(mockBusinessId, 'plan_starter_dev', mockUserId);
    });
  });

  describe('createCheckout', () => {
    it('creates payment checkout order for paid tier', async () => {
      service.createCheckout.mockResolvedValue({
        orderId: 'order_123',
        amountInPaise: 99900,
        currency: 'INR',
      });

      const res = await controller.createCheckout(mockBusinessId, mockUserId, {
        planId: 'plan_pro',
      });

      expect(res.statusCode).toBe(HttpStatus.CREATED);
      expect(res.data.orderId).toBe('order_123');
      expect(service.createCheckout).toHaveBeenCalledWith(mockBusinessId, mockUserId, {
        planId: 'plan_pro',
      });
    });
  });

  describe('verifyPayment', () => {
    it('verifies client payment confirmation', async () => {
      service.verifyPayment.mockResolvedValue({
        success: true,
        message: 'Subscription activated',
      });

      const res = await controller.verifyPayment(mockBusinessId, mockUserId, {
        providerOrderId: 'order_123',
        providerPaymentId: 'pay_123',
        providerSignature: 'sig_123',
      });

      expect(res.statusCode).toBe(HttpStatus.OK);
      expect(res.data.success).toBe(true);
      expect(service.verifyPayment).toHaveBeenCalledWith(mockBusinessId, mockUserId, {
        providerOrderId: 'order_123',
        providerPaymentId: 'pay_123',
        providerSignature: 'sig_123',
      });
    });
  });

  describe('handleWebhook', () => {
    it('rejects webhook missing x-razorpay-signature header', async () => {
      await expect(
        controller.handleWebhook('', {} as any, { event: 'order.paid' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('passes rawBody and signature to service when valid', async () => {
      service.handleWebhook.mockResolvedValue({ success: true, processed: true });
      const req = { rawBody: '{"event":"order.paid"}' };
      const payload = { event: 'order.paid' };

      const res = await controller.handleWebhook('valid_sig', req, payload);
      expect(res.statusCode).toBe(HttpStatus.OK);
      expect(res.data.success).toBe(true);
      expect(service.handleWebhook).toHaveBeenCalledWith('{"event":"order.paid"}', 'valid_sig', payload);
    });
  });
});
