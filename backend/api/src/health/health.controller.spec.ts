import { Test, TestingModule } from '@nestjs/testing';
import { HealthController } from './health.controller';
import { DatabaseHealthService } from '../database/database-health.service';
import { Response } from 'express';

describe('HealthController', () => {
  let controller: HealthController;
  let dbHealthService: Partial<DatabaseHealthService>;

  beforeEach(async () => {
    dbHealthService = {
      checkHealth: jest.fn().mockResolvedValue({
        status: 'up',
        latencyMs: 5,
        timestamp: new Date().toISOString(),
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        {
          provide: DatabaseHealthService,
          useValue: dbHealthService,
        },
      ],
    }).compile();

    controller = module.get<HealthController>(HealthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('getLiveness', () => {
    it('should return service health status with metadata and uptime', () => {
      const result = controller.getLiveness();
      expect(result).toHaveProperty('status', 'ok');
      expect(result).toHaveProperty('service', 'airthai-backend-api');
      expect(result).toHaveProperty('version', '0.1.0');
      expect(result).toHaveProperty('uptime');
      expect(result).toHaveProperty('timestamp');
      expect(result).toHaveProperty('environment');
    });
  });

  describe('getReadiness', () => {
    it('should respond with 200 OK and ready status when database is up', async () => {
      const mockStatus = jest.fn().mockReturnThis();
      const mockJson = jest.fn();
      const mockResponse = {
        status: mockStatus,
        json: mockJson,
      } as unknown as Response;

      await controller.getReadiness(mockResponse);

      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'ready',
          services: expect.objectContaining({
            database: expect.objectContaining({ status: 'up', latencyMs: 5 }),
          }),
        }),
      );
    });

    it('should respond with 503 Service Unavailable when database is down', async () => {
      jest.spyOn(dbHealthService, 'checkHealth').mockResolvedValueOnce({
        status: 'down',
        latencyMs: 120,
        message: 'Database service unreachable',
        timestamp: new Date().toISOString(),
      });

      const mockStatus = jest.fn().mockReturnThis();
      const mockJson = jest.fn();
      const mockResponse = {
        status: mockStatus,
        json: mockJson,
      } as unknown as Response;

      await controller.getReadiness(mockResponse);

      expect(mockStatus).toHaveBeenCalledWith(503);
      expect(mockJson).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'degraded',
          services: expect.objectContaining({
            database: expect.objectContaining({ status: 'down' }),
          }),
        }),
      );
    });
  });

  describe('getMetrics', () => {
    it('should return metrics snapshot with uptime and timestamp', () => {
      const metrics = controller.getMetrics();
      expect(metrics).toHaveProperty('service', 'airthai-backend-api');
      expect(metrics).toHaveProperty('uptime');
    });
  });
});

