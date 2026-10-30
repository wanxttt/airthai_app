/**
 * High-performance, zero-dependency data sanitizer.
 * Ensures passwords, tokens, API keys, database credentials, and payment card numbers
 * are systematically redacted before reaching logs, error payloads, or APM tools.
 */
export class SanitizerUtil {
  private static readonly SENSITIVE_KEY_REGEX =
    /password|passwordhash|secret|jwtsecret|refreshtoken|accesstoken|authorization|cookie|cvv|cardnumber|apikey|keysecret|webhooksecret/i;

  private static readonly PASSWORD_REGEX = /(?:password|pwd|pass)\s*[:=]\s*[^\s,;]+/gi;
  private static readonly DB_URL_REGEX = /postgresql:\/\/[^@]+@/gi;
  private static readonly BEARER_REGEX = /bearer\s+[a-z0-9._-]+/gi;
  private static readonly RAZORPAY_KEY_REGEX = /rzp_(?:test|live)_[a-zA-Z0-9]+/gi;
  private static readonly CARD_PAN_REGEX = /\b(?:\d{4}[ -]?){3}\d{4}\b/g;
  private static readonly JWT_REGEX = /eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]+/g;

  /**
   * Redacts sensitive substrings from arbitrary text or log strings.
   */
  static sanitizeString(input: string): string {
    if (!input || typeof input !== 'string') return input;

    return input
      .replace(this.PASSWORD_REGEX, 'password=***')
      .replace(this.DB_URL_REGEX, 'postgresql://***:***@')
      .replace(this.BEARER_REGEX, 'Bearer ***')
      .replace(this.RAZORPAY_KEY_REGEX, 'rzp_***')
      .replace(this.CARD_PAN_REGEX, '****-****-****-****')
      .replace(this.JWT_REGEX, '[REDACTED_JWT]');
  }

  /**
   * Recursively traverses and redacts sensitive properties from objects or arrays.
   */
  static sanitizeObject<T>(obj: T): T {
    if (obj === null || obj === undefined) return obj;

    if (typeof obj === 'string') {
      return this.sanitizeString(obj) as unknown as T;
    }

    if (Array.isArray(obj)) {
      return obj.map((item) => this.sanitizeObject(item)) as unknown as T;
    }

    if (typeof obj === 'object') {
      const sanitized: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(obj)) {
        if (this.SENSITIVE_KEY_REGEX.test(key)) {
          sanitized[key] = '[REDACTED]';
        } else if (typeof value === 'object' && value !== null) {
          sanitized[key] = this.sanitizeObject(value);
        } else if (typeof value === 'string') {
          sanitized[key] = this.sanitizeString(value);
        } else {
          sanitized[key] = value;
        }
      }
      return sanitized as T;
    }

    return obj;
  }
}

