import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import {
  IPaymentProvider,
  CreateOrderParams,
  ProviderOrderResult,
  VerifyPaymentParams,
} from './payment-provider.interface';
import { PaymentConfig } from '../../config/payment.config';

@Injectable()
export class RazorpayPaymentProvider implements IPaymentProvider {
  readonly providerName = 'razorpay';
  private readonly logger = new Logger(RazorpayPaymentProvider.name);
  private readonly config: PaymentConfig;

  constructor(private readonly configService: ConfigService) {
    this.config = this.configService.get<PaymentConfig>('payment') || {
      provider: 'razorpay',
      mode: 'test',
      keyId: 'rzp_test_mock_key_id',
      keySecret: 'mock_razorpay_secret_key_32chars_len',
      webhookSecret: 'mock_webhook_secret_32chars_len',
      currency: 'INR',
    };
  }

  get keyId(): string {
    return this.config.keyId;
  }

  async createOrder(params: CreateOrderParams): Promise<ProviderOrderResult> {
    // If live credentials are provided and not in test/mock mode, call Razorpay API
    if (
      this.config.mode === 'live' &&
      !this.config.keyId.startsWith('rzp_test_mock')
    ) {
      const basicAuth = Buffer.from(
        `${this.config.keyId}:${this.config.keySecret}`,
      ).toString('base64');

      const response = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${basicAuth}`,
        },
        body: JSON.stringify({
          amount: params.amountInPaise,
          currency: params.currency,
          receipt: params.receipt,
          notes: {
            businessId: params.businessId,
            planId: params.planId,
            planName: params.planName,
            ...params.notes,
          },
        }),
      });

      if (!response.ok) {
        const errText = await response.text();
        this.logger.error(`Razorpay order creation failed: ${errText}`);
        throw new Error(`Payment gateway order creation failed: ${response.statusText}`);
      }

      const orderData: any = await response.json();
      return {
        providerOrderId: orderData.id,
        amountInPaise: orderData.amount,
        currency: orderData.currency,
        receipt: orderData.receipt,
        status: orderData.status,
        keyId: this.config.keyId,
      };
    }

    // Deterministic test/sandbox mode for dev & test verification
    const mockOrderId = `order_${crypto.createHash('sha256').update(params.receipt).digest('hex').substring(0, 16)}`;
    return {
      providerOrderId: mockOrderId,
      amountInPaise: params.amountInPaise,
      currency: params.currency,
      receipt: params.receipt,
      status: 'created',
      keyId: this.config.keyId,
    };
  }

  /**
   * Verifies payment signature returned by Razorpay client checkout.
   * Uses HMAC-SHA256 with constant-time equality check to prevent timing attacks.
   */
  verifyPaymentSignature(params: VerifyPaymentParams): boolean {
    if (
      !params.providerOrderId ||
      !params.providerPaymentId ||
      !params.providerSignature
    ) {
      return false;
    }

    try {
      const payload = `${params.providerOrderId}|${params.providerPaymentId}`;
      const expectedSignature = crypto
        .createHmac('sha256', this.config.keySecret)
        .update(payload)
        .digest('hex');

      const expectedBuf = Buffer.from(expectedSignature, 'utf8');
      const providedBuf = Buffer.from(params.providerSignature, 'utf8');

      if (expectedBuf.length !== providedBuf.length) {
        return false;
      }

      return crypto.timingSafeEqual(expectedBuf, providedBuf);
    } catch (err: any) {
      this.logger.error(`Signature verification exception: ${err.message}`);
      return false;
    }
  }

  /**
   * Verifies incoming webhook signature from Razorpay.
   * Compares raw body payload against x-razorpay-signature header.
   */
  verifyWebhookSignature(rawBody: string | Buffer, signature: string): boolean {
    if (!rawBody || !signature) {
      return false;
    }

    try {
      const expectedSignature = crypto
        .createHmac('sha256', this.config.webhookSecret)
        .update(rawBody)
        .digest('hex');

      const expectedBuf = Buffer.from(expectedSignature, 'utf8');
      const providedBuf = Buffer.from(signature, 'utf8');

      if (expectedBuf.length !== providedBuf.length) {
        return false;
      }

      return crypto.timingSafeEqual(expectedBuf, providedBuf);
    } catch (err: any) {
      this.logger.error(`Webhook signature verification exception: ${err.message}`);
      return false;
    }
  }
}

