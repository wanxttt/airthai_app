import { SecurityHeadersMiddleware } from './security-headers.middleware';
import { Request, Response, NextFunction } from 'express';

describe('SecurityHeadersMiddleware', () => {
  let middleware: SecurityHeadersMiddleware;
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;
  let mockNext: NextFunction;
  let headers: Record<string, string>;

  beforeEach(() => {
    middleware = new SecurityHeadersMiddleware();
    headers = {};
    mockReq = {};
    mockRes = {
      setHeader: jest.fn((name: string, value: string) => {
        headers[name] = value;
        return mockRes as Response;
      }),
    };
    mockNext = jest.fn();
  });

  it('should set all essential HTTP security headers', () => {
    middleware.use(mockReq as Request, mockRes as Response, mockNext);

    expect(headers['X-Content-Type-Options']).toBe('nosniff');
    expect(headers['X-Frame-Options']).toBe('SAMEORIGIN');
    expect(headers['X-XSS-Protection']).toBe('0');
    expect(headers['Referrer-Policy']).toBe('strict-origin-when-cross-origin');
    expect(headers['Strict-Transport-Security']).toBe('max-age=31536000; includeSubDomains');
    expect(headers['Content-Security-Policy']).toBe("default-src 'none'; frame-ancestors 'none'");
    expect(mockNext).toHaveBeenCalled();
  });
});

