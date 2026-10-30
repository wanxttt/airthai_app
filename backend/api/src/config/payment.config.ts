import { registerAs } from '@nestjs/config';

export interface PaymentConfig {
  provider: string;
  mode: 'test' | 'live';
  keyId: string;
  keySecret: string;
  webhookSecret: string;
  currency: string;
}

export default registerAs(
  'payment',
  (): PaymentConfig => {
    const isProd = process.env.NODE_ENV === 'production';
    const keyId = process.env.RAZORPAY_KEY_ID || (isProd ? '' : 'rzp_test_mock_key_id');
    const keySecret = process.env.RAZORPAY_KEY_SECRET || (isProd ? '' : 'mock_razorpay_secret_key_32chars_len');
    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || (isProd ? '' : 'mock_webhook_secret_32chars_len');

    if (isProd && (!keyId || !keySecret || !webhookSecret)) {
      throw new Error(
        'Production configuration error: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, and RAZORPAY_WEBHOOK_SECRET must be set in production environment.',
      );
    }

    return {
      provider: 'razorpay',
      mode: (process.env.PAYMENT_PROVIDER_MODE as 'test' | 'live') || (isProd ? 'live' : 'test'),
      keyId,
      keySecret,
      webhookSecret,
      currency: 'INR',
    };
  },
);

