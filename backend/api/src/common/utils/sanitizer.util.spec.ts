import { SanitizerUtil } from './sanitizer.util';

describe('SanitizerUtil', () => {
  it('redacts database credentials in URLs', () => {
    const raw = 'Failed to connect to postgresql://postgres:superSecretPass123@db.internal:5432/airthai';
    const clean = SanitizerUtil.sanitizeString(raw);
    expect(clean).toBe('Failed to connect to postgresql://***:***@db.internal:5432/airthai');
  });

  it('redacts Bearer tokens in headers or messages', () => {
    const raw = 'Request failed with header Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.fake_signature';
    const clean = SanitizerUtil.sanitizeString(raw);
    expect(clean).toContain('Bearer ***');
    expect(clean).not.toContain('fake_signature');
  });

  it('redacts credit card numbers', () => {
    const raw = 'Card payment attempt with 4111 2222 3333 4444 failed';
    const clean = SanitizerUtil.sanitizeString(raw);
    expect(clean).toBe('Card payment attempt with ****-****-****-**** failed');
  });

  it('redacts Razorpay keys and secrets', () => {
    const raw = 'Invalid signature from rzp_test_1234567890abcdef and secret';
    const clean = SanitizerUtil.sanitizeString(raw);
    expect(clean).toBe('Invalid signature from rzp_*** and secret');
  });

  it('recursively redacts sensitive object keys', () => {
    const payload = {
      email: 'user@example.com',
      password: 'PlainPassword123!',
      metadata: {
        apiKey: 'sk_live_12345',
        businessName: 'Apex Tools',
        nested: {
          refreshToken: 'secret_token_val',
          status: 'ACTIVE',
        },
      },
    };

    const sanitized = SanitizerUtil.sanitizeObject(payload);
    expect(sanitized.email).toBe('user@example.com');
    expect(sanitized.password).toBe('[REDACTED]');
    expect(sanitized.metadata.apiKey).toBe('[REDACTED]');
    expect(sanitized.metadata.businessName).toBe('Apex Tools');
    expect(sanitized.metadata.nested.refreshToken).toBe('[REDACTED]');
    expect(sanitized.metadata.nested.status).toBe('ACTIVE');
  });
});

