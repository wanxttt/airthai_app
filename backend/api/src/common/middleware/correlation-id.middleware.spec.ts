import { CorrelationIdMiddleware, CorrelatedRequest } from './correlation-id.middleware';
import { Response, NextFunction } from 'express';

describe('CorrelationIdMiddleware', () => {
  let middleware: CorrelationIdMiddleware;
  let mockReq: Partial<CorrelatedRequest>;
  let mockRes: Partial<Response>;
  let mockNext: NextFunction;
  let setHeaderMock: jest.Mock;

  beforeEach(() => {
    middleware = new CorrelationIdMiddleware();
    setHeaderMock = jest.fn();
    mockRes = {
      setHeader: setHeaderMock,
    };
    mockNext = jest.fn();
  });

  it('should generate a new UUID if no X-Request-Id header is present', () => {
    mockReq = {
      headers: {},
    };

    middleware.use(mockReq as CorrelatedRequest, mockRes as Response, mockNext);

    expect(mockReq.requestId).toBeDefined();
    expect(mockReq.requestId).toMatch(/^req_[0-9a-f-]+$/);
    expect(mockReq.headers!['x-request-id']).toBe(mockReq.requestId);
    expect(setHeaderMock).toHaveBeenCalledWith('X-Request-Id', mockReq.requestId);
    expect(mockNext).toHaveBeenCalled();
  });

  it('should reuse a valid incoming X-Request-Id header', () => {
    mockReq = {
      headers: {
        'x-request-id': 'client-trace-12345',
      },
    };

    middleware.use(mockReq as CorrelatedRequest, mockRes as Response, mockNext);

    expect(mockReq.requestId).toBe('client-trace-12345');
    expect(setHeaderMock).toHaveBeenCalledWith('X-Request-Id', 'client-trace-12345');
    expect(mockNext).toHaveBeenCalled();
  });

  it('should sanitize and replace an invalid/dangerous X-Request-Id header', () => {
    mockReq = {
      headers: {
        'x-request-id': '<script>alert(1)</script>; DROP TABLE users;',
      },
    };

    middleware.use(mockReq as CorrelatedRequest, mockRes as Response, mockNext);

    expect(mockReq.requestId).not.toContain('<script>');
    expect(mockReq.requestId).toMatch(/^req_[0-9a-f-]+$/);
    expect(setHeaderMock).toHaveBeenCalledWith('X-Request-Id', mockReq.requestId);
    expect(mockNext).toHaveBeenCalled();
  });
});

