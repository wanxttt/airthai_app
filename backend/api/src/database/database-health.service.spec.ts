import { Test, TestingModule } from '@nestjs/testing';
import { DatabaseHealthService } from './database-health.service';
import { PrismaService } from './prisma.service';

describe('DatabaseHealthService', () => {
  let service: DatabaseHealthService;
  let mockPrismaService: { $queryRaw: jest.Mock };

  beforeEach(async () => {
    mockPrismaService = {
      $queryRaw: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DatabaseHealthService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
      ],
    }).compile();

    service = module.get<DatabaseHealthService>(DatabaseHealthService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should return status up and measure latency on successful query', async () => {
    mockPrismaService.$queryRaw.mockResolvedValueOnce([{ test: 1 }]);

    const result = await service.checkHealth();

    expect(result.status).toBe('up');
    expect(typeof result.latencyMs).toBe('number');
    expect(result.latencyMs).toBeGreaterThanOrEqual(0);
    expect(result.timestamp).toBeDefined();
    expect(mockPrismaService.$queryRaw).toHaveBeenCalled();
  });

  it('should return status down and safe error message on query failure', async () => {
    mockPrismaService.$queryRaw.mockRejectedValueOnce(new Error('Connection refused'));

    const result = await service.checkHealth();

    expect(result.status).toBe('down');
    expect(result.message).toBe('Database service unreachable');
    expect(typeof result.latencyMs).toBe('number');
    expect(result.timestamp).toBeDefined();
  });
});

