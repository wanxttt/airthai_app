import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { RazorpayPaymentProvider } from './razorpay-payment.provider';

describe('RazorpayPaymentProvider', () => {
  let provider: RazorpayPaymentProvider;
  const mockKeySecret = 'test_secret_key_for_hmac_sha256_32chars';
  const mockWebhookSecret = 'test_webhook_secret_key_32chars_len';

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RazorpayPaymentProvider,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockReturnValue({
              provider: 'razorpay',
              mode: 'test',
              keyId: 'rzp_test_sample_key',
              keySecret: mockKeySecret,
              webhookSecret: mockWebhookSecret,
              currency: 'INR',
            }),
          },
        },
      ],
    }).compile();

    provider = module.get<RazorpayPaymentProvider>(RazorpayPaymentProvider);
  });

  it('should be defined', () => {
    expect(provider).toBeDefined();
    expect(provider.providerName).toBe('razorpay');
  });

  describe('createOrder', () => {
    it('creates deterministic test order in sandbox mode', async () => {
      const order = await provider.createOrder({
        businessId: 'biz_01',
        planId: 'plan_pro',
        planName: 'Professional',
        amountInPaise: 99900,
        currency: 'INR',
        receipt: 'rcpt_12345',
      });

      expect(order.providerOrderId).toMatch(/^order_/);
      expect(order.amountInPaise).toBe(99900);
      expect(order.currency).toBe('INR');
      expect(order.status).toBe('created');
    });
  });

  describe('verifyPaymentSignature', () => {
    it('returns true for cryptographically valid payment signature', () => {
      const orderId = 'order_test_123';
      const paymentId = 'pay_test_456';
      const validSignature = crypto
        .createHmac('sha256', mockKeySecret)
        .update(`${orderId}|${paymentId}`)
        .digest('hex');

      const isValid = provider.verifyPaymentSignature({
        providerOrderId: orderId,
        providerPaymentId: paymentId,
        providerSignature: validSignature,
      });

      expect(isValid).toBe(true);
    });

    it('returns false for tampered payment signature', () => {
      const isValid = provider.verifyPaymentSignature({
        providerOrderId: 'order_test_123',
        providerPaymentId: 'pay_test_456',
        providerSignature: 'tampered_signature_invalid_hex_string',
      });

      expect(isValid).toBe(false);
    });

    it('returns false when parameters are missing', () => {
      expect(
        provider.verifyPaymentSignature({
          providerOrderId: '',
          providerPaymentId: 'pay_1',
          providerSignature: 'sig_1',
        }),
      ).toBe(false);
    });
  });

  describe('verifyWebhookSignature', () => {
    it('returns true for cryptographically valid webhook payload and signature', () => {
      const rawPayload = JSON.stringify({ event: 'order.paid', id: 'evt_1' });
      const validSignature = crypto
        .createHmac('sha256', mockWebhookSecret)
        .update(rawPayload)
        .digest('hex');

      const isValid = provider.verifyWebhookSignature(rawPayload, validSignature);
      expect(isValid).toBe(true);
    });

    it('returns false for invalid webhook signature', () => {
      const rawPayload = JSON.stringify({ event: 'order.paid' });
      const isValid = provider.verifyWebhookSignature(rawPayload, 'invalid_signature_hex');
      expect(isValid).toBe(false);
    });

    it('returns false for empty payload or signature', () => {
      expect(provider.verifyWebhookSignature('', 'sig')).toBe(false);
      expect(provider.verifyWebhookSignature('payload', '')).toBe(false);
    });
  });
});

