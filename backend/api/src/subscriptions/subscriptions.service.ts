import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { AuditService } from '../audit/audit.service';
import { RazorpayPaymentProvider } from './payment-provider/razorpay-payment.provider';
import { CreateCheckoutDto } from './dto/create-checkout.dto';
import { VerifyPaymentDto } from './dto/verify-payment.dto';
import { Prisma } from '@prisma/client';

export const DEFAULT_DEV_PLANS = [
  {
    id: 'plan_starter_dev',
    name: 'Starter (Free Dev)',
    maxUsers: 1,
    maxInvoicesMonthly: 50,
    priceMonthly: new Prisma.Decimal('0.00'),
  },
  {
    id: 'plan_professional_dev',
    name: 'Professional',
    maxUsers: 5,
    maxInvoicesMonthly: 500,
    priceMonthly: new Prisma.Decimal('999.00'),
  },
  {
    id: 'plan_enterprise_dev',
    name: 'Enterprise',
    maxUsers: 50,
    maxInvoicesMonthly: 10000,
    priceMonthly: new Prisma.Decimal('2999.00'),
  },
];

@Injectable()
export class SubscriptionsService {
  private readonly logger = new Logger(SubscriptionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly paymentProvider: RazorpayPaymentProvider,
    @Optional() private readonly auditService?: AuditService,
  ) {}

  /**
   * Retrieves all available subscription plans, auto-seeding standard development plans if empty.
   */
  async getPlans() {
    let plans = await this.prisma.plan.findMany({
      orderBy: { maxUsers: 'asc' },
    });

    if (plans.length === 0) {
      for (const p of DEFAULT_DEV_PLANS) {
        await this.prisma.plan.upsert({
          where: { id: p.id },
          update: {},
          create: p,
        });
      }
      plans = await this.prisma.plan.findMany({
        orderBy: { maxUsers: 'asc' },
      });
    }

    return plans;
  }

  /**
   * Retrieves current active subscription for a business, with usage counters and entitlement limits.
   */
  async getCurrentSubscription(businessId: string, client?: any) {
    const db = client ?? this.prisma;
    let subscription = await db.subscription.findFirst({
      where: { businessId, status: 'ACTIVE' },
      include: { plan: true },
      orderBy: { createdAt: 'desc' },
    });

    if (!subscription) {
      // Auto-provision initial Starter Dev plan
      const plans = await this.getPlans();
      const starterPlan = plans[0];

      subscription = await db.subscription.create({
        data: {
          businessId,
          planId: starterPlan.id,
          status: 'ACTIVE',
          validUntil: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // 1 year
        },
        include: { plan: true },
      });
    }

    // Calculate usage counters
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const [userCount, monthlyInvoiceCount] = await Promise.all([
      db.businessUser.count({ where: { businessId } }),
      db.invoice.count({
        where: {
          businessId,
          createdAt: { gte: startOfMonth },
        },
      }),
    ]);

    const isExpired = subscription.validUntil.getTime() < now.getTime();
    const daysRemaining = Math.max(
      0,
      Math.ceil((subscription.validUntil.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)),
    );

    return {
      subscription: {
        id: subscription.id,
        businessId: subscription.businessId,
        status: isExpired ? 'EXPIRED' : subscription.status,
        validUntil: subscription.validUntil,
        daysRemaining,
        plan: subscription.plan,
      },
      usage: {
        currentUsers: userCount,
        maxUsers: subscription.plan.maxUsers,
        usersRemaining: Math.max(0, subscription.plan.maxUsers - userCount),
        monthlyInvoices: monthlyInvoiceCount,
        maxInvoicesMonthly: subscription.plan.maxInvoicesMonthly,
        invoicesRemaining: Math.max(0, subscription.plan.maxInvoicesMonthly - monthlyInvoiceCount),
      },
    };
  }

  /**
   * Secure plan change for free tiers only.
   * Prohibits unverified activation of paid plans (SEC-PAY-01).
   */
  async changePlan(businessId: string, planId: string, userId?: string) {
    const plan = await this.prisma.plan.findUnique({
      where: { id: planId },
    });

    if (!plan) {
      throw new NotFoundException(`Plan with ID ${planId} not found.`);
    }

    const price = plan.priceMonthly instanceof Prisma.Decimal ? plan.priceMonthly.toNumber() : Number(plan.priceMonthly);

    // Enforce payment gateway for paid plans
    if (price > 0) {
      throw new BadRequestException(
        `Direct activation of paid plan "${plan.name}" is prohibited without verified payment. Please initiate checkout via POST /subscriptions/checkout.`,
      );
    }

    const currentSub = await this.prisma.subscription.findFirst({
      where: { businessId, status: 'ACTIVE' },
    });

    let updatedSubscription;
    if (currentSub) {
      updatedSubscription = await this.prisma.subscription.update({
        where: { id: currentSub.id },
        data: {
          planId,
          validUntil: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
        },
        include: { plan: true },
      });
    } else {
      updatedSubscription = await this.prisma.subscription.create({
        data: {
          businessId,
          planId,
          status: 'ACTIVE',
          validUntil: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
        },
        include: { plan: true },
      });
    }

    if (this.auditService) {
      await this.auditService.logEvent({
        businessId,
        userId,
        action: 'SUBSCRIPTION_FREE_PLAN_CHANGED',
        entityName: 'SUBSCRIPTION',
        entityId: updatedSubscription.id,
        newValues: { planId, planName: plan.name },
      });
    }

    return updatedSubscription;
  }

  /**
   * Initiates an authoritative payment order for a paid subscription tier.
   */
  async createCheckout(businessId: string, userId: string, dto: CreateCheckoutDto) {
    const plan = await this.prisma.plan.findUnique({
      where: { id: dto.planId },
    });

    if (!plan) {
      throw new NotFoundException(`Plan with ID ${dto.planId} not found.`);
    }

    const price = plan.priceMonthly instanceof Prisma.Decimal ? plan.priceMonthly.toNumber() : Number(plan.priceMonthly);

    if (price <= 0) {
      throw new BadRequestException(
        `Plan "${plan.name}" is free and does not require payment checkout. Use POST /subscriptions/change-plan.`,
      );
    }

    // Idempotency: return existing order if same key is provided
    if (dto.idempotencyKey) {
      const existingOrder = await this.prisma.subscriptionOrder.findFirst({
        where: {
          businessId,
          idempotencyKey: dto.idempotencyKey,
        },
        include: { plan: true },
      });

      if (existingOrder && (existingOrder.status === 'CREATED' || existingOrder.status === 'COMPLETED')) {
        return {
          orderId: existingOrder.providerOrderId,
          amountInPaise: Math.round(Number(existingOrder.amount) * 100),
          currency: existingOrder.currency,
          keyId: this.paymentProvider.keyId,
          plan: {
            id: plan.id,
            name: plan.name,
            priceMonthly: price,
          },
          status: existingOrder.status,
          idempotentReplay: true,
        };
      }
    }

    const amountInPaise = Math.round(price * 100);
    const receipt = `rcpt_${businessId.substring(0, 8)}_${Date.now()}`;

    const providerOrder = await this.paymentProvider.createOrder({
      businessId,
      planId: plan.id,
      planName: plan.name,
      amountInPaise,
      currency: 'INR',
      receipt,
      notes: {
        userId,
      },
    });

    const subscriptionOrder = await this.prisma.subscriptionOrder.create({
      data: {
        businessId,
        planId: plan.id,
        userId,
        providerOrderId: providerOrder.providerOrderId,
        amount: plan.priceMonthly,
        currency: providerOrder.currency,
        status: 'CREATED',
        idempotencyKey: dto.idempotencyKey || null,
        receipt: providerOrder.receipt,
        metadata: {
          planName: plan.name,
          maxUsers: plan.maxUsers,
          maxInvoicesMonthly: plan.maxInvoicesMonthly,
        },
      },
    });

    if (this.auditService) {
      await this.auditService.logEvent({
        businessId,
        userId,
        action: 'SUBSCRIPTION_CHECKOUT_INITIATED',
        entityName: 'SUBSCRIPTION_ORDER',
        entityId: subscriptionOrder.id,
        newValues: {
          providerOrderId: providerOrder.providerOrderId,
          planId: plan.id,
          amount: price,
          currency: providerOrder.currency,
        },
      });
    }

    return {
      orderId: providerOrder.providerOrderId,
      amountInPaise: providerOrder.amountInPaise,
      currency: providerOrder.currency,
      keyId: providerOrder.keyId || this.paymentProvider.keyId,
      plan: {
        id: plan.id,
        name: plan.name,
        priceMonthly: price,
      },
      status: subscriptionOrder.status,
    };
  }

  /**
   * Verifies client checkout response using HMAC-SHA256 signature and activates the subscription in a transaction.
   */
  async verifyPayment(businessId: string, userId: string, dto: VerifyPaymentDto) {
    const order = await this.prisma.subscriptionOrder.findFirst({
      where: {
        businessId,
        providerOrderId: dto.providerOrderId,
      },
      include: { plan: true },
    });

    if (!order) {
      throw new NotFoundException(`Subscription order "${dto.providerOrderId}" not found for this business.`);
    }

    // Idempotent success handling
    if (order.status === 'COMPLETED') {
      const currentSub = await this.prisma.subscription.findFirst({
        where: { businessId, status: 'ACTIVE' },
        include: { plan: true },
      });
      return {
        success: true,
        message: 'Subscription payment was already verified and activated.',
        subscription: currentSub,
        order,
      };
    }

    if (order.status === 'FAILED') {
      throw new BadRequestException('This subscription order has already failed or been cancelled.');
    }

    // Independent cryptographic verification
    const isValidSignature = this.paymentProvider.verifyPaymentSignature({
      providerOrderId: dto.providerOrderId,
      providerPaymentId: dto.providerPaymentId,
      providerSignature: dto.providerSignature,
    });

    if (!isValidSignature) {
      await this.prisma.subscriptionOrder.update({
        where: { id: order.id },
        data: {
          status: 'FAILED',
          failureReason: 'Invalid signature verification',
        },
      });

      if (this.auditService) {
        await this.auditService.logEvent({
          businessId,
          userId,
          action: 'SUBSCRIPTION_PAYMENT_FAILED_SIGNATURE',
          entityName: 'SUBSCRIPTION_ORDER',
          entityId: order.id,
        });
      }

      throw new BadRequestException('Payment signature verification failed.');
    }

    // Transactional state activation
    return await this.prisma.$transaction(async (tx) => {
      // Prevent duplicate processing of the same payment ID across multiple orders
      const existingPayment = await tx.subscriptionOrder.findFirst({
        where: { providerPaymentId: dto.providerPaymentId },
      });

      if (existingPayment && existingPayment.id !== order.id) {
        throw new ConflictException('Payment ID has already been processed for another subscription order.');
      }

      // 1. Mark order completed
      const updatedOrder = await tx.subscriptionOrder.update({
        where: { id: order.id },
        data: {
          status: 'COMPLETED',
          providerPaymentId: dto.providerPaymentId,
          signature: dto.providerSignature,
        },
      });

      // 2. Activate or renew subscription
      const now = new Date();
      const validUntil = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000); // 30-day billing cycle

      const currentSub = await tx.subscription.findFirst({
        where: { businessId, status: 'ACTIVE' },
      });

      let activeSub;
      if (currentSub) {
        activeSub = await tx.subscription.update({
          where: { id: currentSub.id },
          data: {
            planId: order.planId,
            status: 'ACTIVE',
            validUntil,
          },
          include: { plan: true },
        });
      } else {
        activeSub = await tx.subscription.create({
          data: {
            businessId,
            planId: order.planId,
            status: 'ACTIVE',
            validUntil,
          },
          include: { plan: true },
        });
      }

      if (this.auditService) {
        await this.auditService.logEvent({
          businessId,
          userId,
          action: 'SUBSCRIPTION_ACTIVATED_PAYMENT',
          entityName: 'SUBSCRIPTION',
          entityId: activeSub.id,
          newValues: {
            orderId: order.id,
            planId: order.planId,
            providerPaymentId: dto.providerPaymentId,
            amount: Number(order.amount),
          },
        });
      }

      return {
        success: true,
        message: `Subscription successfully upgraded to ${order.plan.name}.`,
        subscription: activeSub,
        order: updatedOrder,
      };
    });
  }

  /**
   * Handles incoming server-to-server webhook notifications from the payment gateway.
   */
  async handleWebhook(rawBody: string | Buffer, signature: string, payload: any) {
    const isValidSignature = this.paymentProvider.verifyWebhookSignature(rawBody, signature);
    if (!isValidSignature) {
      this.logger.warn('Incoming payment webhook rejected: invalid signature.');
      throw new BadRequestException('Invalid webhook signature.');
    }

    const event = payload?.event;
    if (!event) {
      throw new BadRequestException('Webhook payload missing event identifier.');
    }

    if (event === 'order.paid' || event === 'payment.captured') {
      const orderId = payload.payload?.payment?.entity?.order_id || payload.payload?.order?.entity?.id;
      const paymentId = payload.payload?.payment?.entity?.id;
      const amountPaise = payload.payload?.payment?.entity?.amount;
      const currency = payload.payload?.payment?.entity?.currency;

      if (!orderId) {
        return { success: false, message: 'Missing order_id in webhook payload.' };
      }

      const order = await this.prisma.subscriptionOrder.findUnique({
        where: { providerOrderId: orderId },
        include: { plan: true },
      });

      if (!order) {
        this.logger.warn(`Webhook received for unknown order: ${orderId}`);
        return { success: false, message: 'Order not found.' };
      }

      // Idempotency: if already completed, do not re-process
      if (order.status === 'COMPLETED') {
        return { success: true, message: 'Order was already processed.' };
      }

      // Amount verification: prevent underpaid order activation
      const expectedPaise = Math.round(Number(order.amount) * 100);
      if (amountPaise !== undefined && amountPaise !== expectedPaise) {
        this.logger.error(
          `Webhook payment amount mismatch for order ${orderId}: expected ${expectedPaise}, got ${amountPaise}`,
        );
        throw new BadRequestException('Payment amount mismatch.');
      }

      if (currency && currency !== order.currency) {
        this.logger.error(
          `Webhook payment currency mismatch for order ${orderId}: expected ${order.currency}, got ${currency}`,
        );
        throw new BadRequestException('Payment currency mismatch.');
      }

      // Atomic activation
      return await this.prisma.$transaction(async (tx) => {
        const updatedOrder = await tx.subscriptionOrder.update({
          where: { id: order.id },
          data: {
            status: 'COMPLETED',
            providerPaymentId: paymentId || order.providerPaymentId,
          },
        });

        const now = new Date();
        const validUntil = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

        const currentSub = await tx.subscription.findFirst({
          where: { businessId: order.businessId, status: 'ACTIVE' },
        });

        let activeSub;
        if (currentSub) {
          activeSub = await tx.subscription.update({
            where: { id: currentSub.id },
            data: {
              planId: order.planId,
              status: 'ACTIVE',
              validUntil,
            },
            include: { plan: true },
          });
        } else {
          activeSub = await tx.subscription.create({
            data: {
              businessId: order.businessId,
              planId: order.planId,
              status: 'ACTIVE',
              validUntil,
            },
            include: { plan: true },
          });
        }

        if (this.auditService) {
          await this.auditService.logEvent({
            businessId: order.businessId,
            action: 'SUBSCRIPTION_ACTIVATED_WEBHOOK',
            entityName: 'SUBSCRIPTION',
            entityId: activeSub.id,
            newValues: {
              orderId: order.id,
              planId: order.planId,
              providerPaymentId: paymentId,
            },
          });
        }

        return { success: true, processed: true, subscription: activeSub, order: updatedOrder };
      });
    }

    if (event === 'payment.failed') {
      const orderId = payload.payload?.payment?.entity?.order_id;
      const failureReason = payload.payload?.payment?.entity?.error_description || 'Payment failed';

      if (orderId) {
        const order = await this.prisma.subscriptionOrder.findUnique({
          where: { providerOrderId: orderId },
        });

        if (order && order.status !== 'COMPLETED') {
          await this.prisma.subscriptionOrder.update({
            where: { id: order.id },
            data: {
              status: 'FAILED',
              failureReason,
            },
          });

          if (this.auditService) {
            await this.auditService.logEvent({
              businessId: order.businessId,
              action: 'SUBSCRIPTION_PAYMENT_FAILED_WEBHOOK',
              entityName: 'SUBSCRIPTION_ORDER',
              entityId: order.id,
              newValues: { failureReason },
            });
          }
        }
      }

      return { success: true, processed: true };
    }

    return { success: true, ignored: true };
  }

  /**
   * Server-side entitlement check: Enforces user seat limit.
   */
  async enforceUserLimit(businessId: string, client?: any) {
    const { subscription, usage } = await this.getCurrentSubscription(businessId, client);
    if (subscription.status === 'EXPIRED') {
      throw new ForbiddenException('Your business subscription has expired. Please renew your plan.');
    }

    if (usage.currentUsers >= usage.maxUsers) {
      throw new ForbiddenException(
        `Subscription user limit reached (${usage.currentUsers}/${usage.maxUsers}). Please upgrade your plan to add more team members.`,
      );
    }
  }

  /**
   * Server-side entitlement check: Enforces monthly invoice issuance limit.
   */
  async enforceInvoiceLimit(businessId: string, client?: any) {
    const { subscription, usage } = await this.getCurrentSubscription(businessId, client);
    if (subscription.status === 'EXPIRED') {
      throw new ForbiddenException('Your business subscription has expired. Please renew your plan to issue invoices.');
    }

    if (usage.monthlyInvoices >= usage.maxInvoicesMonthly) {
      throw new ForbiddenException(
        `Monthly invoice quota exceeded (${usage.monthlyInvoices}/${usage.maxInvoicesMonthly}). Please upgrade your plan to issue more invoices this month.`,
      );
    }
  }
}
