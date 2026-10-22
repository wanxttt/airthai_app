import { HttpException, HttpStatus } from '@nestjs/common';
import { AllExceptionsFilter } from './http-exception.filter';
import { ArgumentsHost } from '@nestjs/common';

describe('AllExceptionsFilter', () => {
  let filter: AllExceptionsFilter;
  let mockStatus: jest.Mock;
  let mockJson: jest.Mock;
  let mockResponse: { status: jest.Mock; json: jest.Mock };
  let mockRequest: { url: string; method: string };
  let mockHost: ArgumentsHost;

  beforeEach(() => {
    filter = new AllExceptionsFilter();
    mockStatus = jest.fn().mockReturnThis();
    mockJson = jest.fn();
    mockResponse = { status: mockStatus, json: mockJson };
    mockRequest = { url: '/api/v1/test', method: 'GET' };

    mockHost = {
      switchToHttp: jest.fn().mockReturnValue({
        getResponse: () => mockResponse,
        getRequest: () => mockRequest,
      }),
    } as unknown as ArgumentsHost;
  });

  it('should format standard HttpException into structured response', () => {
    const exception = new HttpException('Resource not found', HttpStatus.NOT_FOUND);

    filter.catch(exception, mockHost);

    expect(mockStatus).toHaveBeenCalledWith(404);
    expect(mockJson).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: 404,
        error: 'HttpException',
        message: 'Resource not found',
        path: '/api/v1/test',
        timestamp: expect.any(String),
      }),
    );
  });

  it('should format unknown internal errors gracefully as 500 without leaking sensitive data', () => {
    const exception = new Error('Database password failed or internal crash');

    filter.catch(exception, mockHost);

    expect(mockStatus).toHaveBeenCalledWith(500);
    expect(mockJson).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: 500,
        error: 'Internal Server Error',
        path: '/api/v1/test',
        timestamp: expect.any(String),
      }),
    );
  });
});

