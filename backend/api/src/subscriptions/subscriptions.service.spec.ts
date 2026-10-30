import { Test, TestingModule } from '@nestjs/testing';
import { SubscriptionsService, DEFAULT_DEV_PLANS } from './subscriptions.service';
import { PrismaService } from '../database/prisma.service';
import { AuditService } from '../audit/audit.service';
import { RazorpayPaymentProvider } from './payment-provider/razorpay-payment.provider';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

describe('SubscriptionsService - Payment & Subscription Security', () => {
  let service: SubscriptionsService;
  let prisma: any;
  let paymentProvider: any;
  let auditService: any;

  const mockBusinessId = 'biz_sub_test_001';
  const mockUserId = 'usr_owner_001';

  beforeEach(async () => {
    prisma = {
      plan: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        upsert: jest.fn(),
      },
      subscription: {
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      subscriptionOrder: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      businessUser: {
        count: jest.fn(),
      },
      invoice: {
        count: jest.fn(),
      },
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return await callback(prisma);
      }),
    };

    paymentProvider = {
      providerName: 'razorpay',
      keyId: 'rzp_test_key_01',
      createOrder: jest.fn(),
      verifyPaymentSignature: jest.fn(),
      verifyWebhookSignature: jest.fn(),
    };

    auditService = {
      logEvent: jest.fn().mockResolvedValue(null),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
        { provide: RazorpayPaymentProvider, useValue: paymentProvider },
        { provide: AuditService, useValue: auditService },
      ],
    }).compile();

    service = module.get<SubscriptionsService>(SubscriptionsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getPlans', () => {
    it('returns existing plans from database', async () => {
      prisma.plan.findMany.mockResolvedValue(DEFAULT_DEV_PLANS);
      const plans = await service.getPlans();
      expect(plans).toHaveLength(3);
    });

    it('auto-seeds development plans if table is empty', async () => {
      prisma.plan.findMany
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce(DEFAULT_DEV_PLANS);
      prisma.plan.upsert.mockResolvedValue({});

      const plans = await service.getPlans();
      expect(prisma.plan.upsert).toHaveBeenCalledTimes(3);
      expect(plans).toHaveLength(3);
    });
  });

  describe('changePlan (Secured Free-Plan Only)', () => {
    it('allows changing to free Starter plan without payment', async () => {
      prisma.plan.findUnique.mockResolvedValue({
        id: 'plan_starter_dev',
        name: 'Starter',
        priceMonthly: new Prisma.Decimal('0.00'),
      });
      prisma.subscription.findFirst.mockResolvedValue({ id: 'sub_active' });
      prisma.subscription.update.mockResolvedValue({
        id: 'sub_active',
        planId: 'plan_starter_dev',
        status: 'ACTIVE',
      });

      const result = await service.changePlan(mockBusinessId, 'plan_starter_dev', mockUserId);
      expect(result.planId).toBe('plan_starter_dev');
      expect(prisma.subscription.update).toHaveBeenCalled();
      expect(auditService.logEvent).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'SUBSCRIPTION_FREE_PLAN_CHANGED' }),
      );
    });

    it('UNAUTHORIZED UPGRADE: rejects direct change to paid plan without verified payment', async () => {
      prisma.plan.findUnique.mockResolvedValue({
        id: 'plan_professional_dev',
        name: 'Professional',
        priceMonthly: new Prisma.Decimal('999.00'),
      });

      await expect(
        service.changePlan(mockBusinessId, 'plan_professional_dev', mockUserId),
      ).rejects.toThrow(BadRequestException);

      expect(prisma.subscription.update).not.toHaveBeenCalled();
      expect(prisma.subscription.create).not.toHaveBeenCalled();
    });

    it('throws NotFoundException for non-existent plan', async () => {
      prisma.plan.findUnique.mockResolvedValue(null);
      await expect(service.changePlan(mockBusinessId, 'non_existent_plan')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('createCheckout', () => {
    it('creates authoritative payment order for paid plan', async () => {
      prisma.plan.findUnique.mockResolvedValue({
        id: 'plan_professional_dev',
        name: 'Professional',
        priceMonthly: new Prisma.Decimal('999.00'),
        maxUsers: 5,
        maxInvoicesMonthly: 500,
      });

      paymentProvider.createOrder.mockResolvedValue({
        providerOrderId: 'order_rzp_123',
        amountInPaise: 99900,
        currency: 'INR',
        receipt: 'rcpt_biz_01_123',
        keyId: 'rzp_test_key_01',
      });

      prisma.subscriptionOrder.create.mockResolvedValue({
        id: 'so_1',
        providerOrderId: 'order_rzp_123',
        status: 'CREATED',
      });

      const result = await service.createCheckout(mockBusinessId, mockUserId, {
        planId: 'plan_professional_dev',
      });

      expect(result.orderId).toBe('order_rzp_123');
      expect(result.amountInPaise).toBe(99900);
      expect(result.currency).toBe('INR');
      expect(paymentProvider.createOrder).toHaveBeenCalledWith(
        expect.objectContaining({
          businessId: mockBusinessId,
          planId: 'plan_professional_dev',
          amountInPaise: 99900,
          currency: 'INR',
        }),
      );
      expect(auditService.logEvent).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'SUBSCRIPTION_CHECKOUT_INITIATED' }),
      );
    });

    it('rejects checkout creation for free plans', async () => {
      prisma.plan.findUnique.mockResolvedValue({
        id: 'plan_starter_dev',
        name: 'Starter',
        priceMonthly: new Prisma.Decimal('0.00'),
      });

      await expect(
        service.createCheckout(mockBusinessId, mockUserId, { planId: 'plan_starter_dev' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('idempotently returns existing order when idempotencyKey is reused', async () => {
      prisma.plan.findUnique.mockResolvedValue({
        id: 'plan_pro',
        name: 'Professional',
        priceMonthly: new Prisma.Decimal('999.00'),
      });

      prisma.subscriptionOrder.findFirst.mockResolvedValue({
        id: 'so_existing',
        providerOrderId: 'order_existing_123',
        amount: new Prisma.Decimal('999.00'),
        currency: 'INR',
        status: 'CREATED',
      });

      const result = await service.createCheckout(mockBusinessId, mockUserId, {
        planId: 'plan_pro',
        idempotencyKey: 'idemp_key_123',
      });

      expect(result.idempotentReplay).toBe(true);
      expect(result.orderId).toBe('order_existing_123');
      expect(paymentProvider.createOrder).not.toHaveBeenCalled();
    });
  });

  describe('verifyPayment', () => {
    const mockOrder = {
      id: 'so_01',
      businessId: mockBusinessId,
      planId: 'plan_pro',
      providerOrderId: 'order_123',
      amount: new Prisma.Decimal('999.00'),
      currency: 'INR',
      status: 'CREATED',
      plan: { id: 'plan_pro', name: 'Professional' },
    };

    it('VALID CONFIRMATION: verifies cryptographic signature and activates subscription atomically', async () => {
      prisma.subscriptionOrder.findFirst.mockResolvedValue(mockOrder);
      paymentProvider.verifyPaymentSignature.mockReturnValue(true);

      prisma.subscriptionOrder.update.mockResolvedValue({
        ...mockOrder,
        status: 'COMPLETED',
        providerPaymentId: 'pay_123',
      });

      prisma.subscription.findFirst.mockResolvedValue(null);
      prisma.subscription.create.mockResolvedValue({
        id: 'sub_new',
        businessId: mockBusinessId,
        planId: 'plan_pro',
        status: 'ACTIVE',
      });

      const result = await service.verifyPayment(mockBusinessId, mockUserId, {
        providerOrderId: 'order_123',
        providerPaymentId: 'pay_123',
        providerSignature: 'valid_hmac_sig',
      });

      expect(result.success).toBe(true);
      expect(paymentProvider.verifyPaymentSignature).toHaveBeenCalledWith({
        providerOrderId: 'order_123',
        providerPaymentId: 'pay_123',
        providerSignature: 'valid_hmac_sig',
      });
      expect(prisma.subscriptionOrder.update).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ status: 'COMPLETED' }) }),
      );
      expect(auditService.logEvent).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'SUBSCRIPTION_ACTIVATED_PAYMENT' }),
      );
    });

    it('INVALID SIGNATURE: marks order FAILED and rejects confirmation', async () => {
      prisma.subscriptionOrder.findFirst.mockResolvedValue(mockOrder);
      paymentProvider.verifyPaymentSignature.mockReturnValue(false); // Tampered signature

      await expect(
        service.verifyPayment(mockBusinessId, mockUserId, {
          providerOrderId: 'order_123',
          providerPaymentId: 'pay_123',
          providerSignature: 'invalid_tampered_sig',
        }),
      ).rejects.toThrow(BadRequestException);

      expect(prisma.subscriptionOrder.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'FAILED' }),
        }),
      );
      expect(prisma.subscription.create).not.toHaveBeenCalled();
      expect(prisma.subscription.update).not.toHaveBeenCalled();
    });

    it('CROSS-TENANT ISOLATION: rejects payment for order belonging to another business', async () => {
      prisma.subscriptionOrder.findFirst.mockResolvedValue(null); // Not found for mockBusinessId

      await expect(
        service.verifyPayment(mockBusinessId, mockUserId, {
          providerOrderId: 'order_other_biz',
          providerPaymentId: 'pay_123',
          providerSignature: 'sig',
        }),
      ).rejects.toThrow(NotFoundException);
    });

    it('IDEMPOTENT REPLAY: returns success without duplicate charge when order is already COMPLETED', async () => {
      prisma.subscriptionOrder.findFirst.mockResolvedValue({
        ...mockOrder,
        status: 'COMPLETED',
      });
      prisma.subscription.findFirst.mockResolvedValue({
        id: 'sub_active',
        status: 'ACTIVE',
      });

      const result = await service.verifyPayment(mockBusinessId, mockUserId, {
        providerOrderId: 'order_123',
        providerPaymentId: 'pay_123',
        providerSignature: 'sig',
      });

      expect(result.success).toBe(true);
      expect(paymentProvider.verifyPaymentSignature).not.toHaveBeenCalled();
      expect(prisma.subscriptionOrder.update).not.toHaveBeenCalled();
    });

    it('INVALID STATE TRANSITION: rejects verification on failed order', async () => {
      prisma.subscriptionOrder.findFirst.mockResolvedValue({
        ...mockOrder,
        status: 'FAILED',
      });

      await expect(
        service.verifyPayment(mockBusinessId, mockUserId, {
          providerOrderId: 'order_123',
          providerPaymentId: 'pay_123',
          providerSignature: 'sig',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('CONCURRENT / DUPLICATE PAYMENT ID: rejects if paymentId is already linked to another order', async () => {
      prisma.subscriptionOrder.findFirst
        .mockResolvedValueOnce(mockOrder) // initial find
        .mockResolvedValueOnce({ id: 'so_other_order', providerPaymentId: 'pay_reused' }); // inside transaction check

      paymentProvider.verifyPaymentSignature.mockReturnValue(true);

      await expect(
        service.verifyPayment(mockBusinessId, mockUserId, {
          providerOrderId: 'order_123',
          providerPaymentId: 'pay_reused',
          providerSignature: 'sig',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('ROLLBACK: transaction failure rolls back all state changes', async () => {
      prisma.subscriptionOrder.findFirst.mockResolvedValue(mockOrder);
      paymentProvider.verifyPaymentSignature.mockReturnValue(true);

      prisma.$transaction.mockRejectedValue(new Error('Database transaction deadlocked'));

      await expect(
        service.verifyPayment(mockBusinessId, mockUserId, {
          providerOrderId: 'order_123',
          providerPaymentId: 'pay_123',
          providerSignature: 'sig',
        }),
      ).rejects.toThrow('Database transaction deadlocked');
    });
  });

  describe('handleWebhook', () => {
    const rawPayload = JSON.stringify({
      event: 'order.paid',
      payload: {
        payment: {
          entity: {
            id: 'pay_wh_1',
            order_id: 'order_wh_1',
            amount: 99900,
            currency: 'INR',
            status: 'captured',
          },
        },
      },
    });

    it('INVALID WEBHOOK SIGNATURE: rejects unverified webhook delivery', async () => {
      paymentProvider.verifyWebhookSignature.mockReturnValue(false);

      await expect(
        service.handleWebhook(rawPayload, 'invalid_sig', JSON.parse(rawPayload)),
      ).rejects.toThrow(BadRequestException);
    });

    it('VALID WEBHOOK: activates subscription on order.paid', async () => {
      paymentProvider.verifyWebhookSignature.mockReturnValue(true);

      prisma.subscriptionOrder.findUnique.mockResolvedValue({
        id: 'so_wh_1',
        businessId: mockBusinessId,
        planId: 'plan_pro',
        amount: new Prisma.Decimal('999.00'),
        currency: 'INR',
        status: 'CREATED',
        plan: { id: 'plan_pro', name: 'Professional' },
      });

      prisma.subscriptionOrder.update.mockResolvedValue({ id: 'so_wh_1', status: 'COMPLETED' });
      prisma.subscription.findFirst.mockResolvedValue({ id: 'sub_1' });
      prisma.subscription.update.mockResolvedValue({ id: 'sub_1', status: 'ACTIVE' });

      const result = await service.handleWebhook(rawPayload, 'valid_sig', JSON.parse(rawPayload));

      expect(result.success).toBe(true);
      expect(result.processed).toBe(true);
      expect(prisma.subscriptionOrder.update).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ status: 'COMPLETED' }) }),
      );
      expect(auditService.logEvent).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'SUBSCRIPTION_ACTIVATED_WEBHOOK' }),
      );
    });

    it('DUPLICATE WEBHOOK: handles repeat delivery idempotently without re-activating', async () => {
      paymentProvider.verifyWebhookSignature.mockReturnValue(true);

      prisma.subscriptionOrder.findUnique.mockResolvedValue({
        id: 'so_wh_1',
        status: 'COMPLETED', // Already completed!
      });

      const result = await service.handleWebhook(rawPayload, 'valid_sig', JSON.parse(rawPayload));

      expect(result.success).toBe(true);
      expect((result as any).message).toContain('already processed');
      expect(prisma.subscriptionOrder.update).not.toHaveBeenCalled();
    });

    it('AMOUNT MISMATCH: rejects webhook if payment amount does not match order', async () => {
      paymentProvider.verifyWebhookSignature.mockReturnValue(true);

      prisma.subscriptionOrder.findUnique.mockResolvedValue({
        id: 'so_wh_1',
        amount: new Prisma.Decimal('2999.00'), // Enterprise order expecting ₹2,999
        currency: 'INR',
        status: 'CREATED',
      });

      // Payload has 99900 (₹999)
      await expect(
        service.handleWebhook(rawPayload, 'valid_sig', JSON.parse(rawPayload)),
      ).rejects.toThrow(BadRequestException);
    });

    it('CURRENCY MISMATCH: rejects webhook if payment currency differs from order', async () => {
      paymentProvider.verifyWebhookSignature.mockReturnValue(true);

      prisma.subscriptionOrder.findUnique.mockResolvedValue({
        id: 'so_wh_1',
        amount: new Prisma.Decimal('999.00'),
        currency: 'USD', // Expecting USD
        status: 'CREATED',
      });

      // Payload has currency: 'INR'
      await expect(
        service.handleWebhook(rawPayload, 'valid_sig', JSON.parse(rawPayload)),
      ).rejects.toThrow(BadRequestException);
    });

    it('FAILED PAYMENT WEBHOOK: marks order FAILED with failure reason', async () => {
      const failPayload = {
        event: 'payment.failed',
        payload: {
          payment: {
            entity: {
              order_id: 'order_wh_fail',
              error_description: 'Card declined by issuing bank',
            },
          },
        },
      };

      paymentProvider.verifyWebhookSignature.mockReturnValue(true);
      prisma.subscriptionOrder.findUnique.mockResolvedValue({
        id: 'so_wh_fail',
        businessId: mockBusinessId,
        status: 'CREATED',
      });

      const result = await service.handleWebhook(
        JSON.stringify(failPayload),
        'valid_sig',
        failPayload,
      );

      expect(result.success).toBe(true);
      expect(prisma.subscriptionOrder.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: 'FAILED',
            failureReason: 'Card declined by issuing bank',
          }),
        }),
      );
      expect(auditService.logEvent).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'SUBSCRIPTION_PAYMENT_FAILED_WEBHOOK' }),
      );
    });
  });

  describe('Entitlement Enforcement', () => {
    it('throws ForbiddenException when user limit is reached', async () => {
      jest.spyOn(service, 'getCurrentSubscription').mockResolvedValue({
        subscription: { status: 'ACTIVE' } as any,
        usage: { currentUsers: 1, maxUsers: 1 } as any,
      });

      await expect(service.enforceUserLimit(mockBusinessId)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('allows user addition when under the limit', async () => {
      jest.spyOn(service, 'getCurrentSubscription').mockResolvedValue({
        subscription: { status: 'ACTIVE' } as any,
        usage: { currentUsers: 1, maxUsers: 5 } as any,
      });

      await expect(service.enforceUserLimit(mockBusinessId)).resolves.not.toThrow();
    });

    it('throws ForbiddenException when monthly invoice quota is reached', async () => {
      jest.spyOn(service, 'getCurrentSubscription').mockResolvedValue({
        subscription: { status: 'ACTIVE' } as any,
        usage: { monthlyInvoices: 50, maxInvoicesMonthly: 50 } as any,
      });

      await expect(service.enforceInvoiceLimit(mockBusinessId)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('allows invoice creation when within monthly quota', async () => {
      jest.spyOn(service, 'getCurrentSubscription').mockResolvedValue({
        subscription: { status: 'ACTIVE' } as any,
        usage: { monthlyInvoices: 10, maxInvoicesMonthly: 50 } as any,
      });

      await expect(service.enforceInvoiceLimit(mockBusinessId)).resolves.not.toThrow();
    });
  });
});
