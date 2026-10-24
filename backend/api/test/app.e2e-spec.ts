import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { DatabaseHealthService } from '../src/database/database-health.service';

describe('AppController (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(DatabaseHealthService)
      .useValue({
        checkHealth: jest.fn().mockResolvedValue({
          status: 'up',
          latencyMs: 1,
          timestamp: new Date().toISOString(),
        }),
      })
      .compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('/health (GET) should return 200 and liveness status', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect((res) => {
        expect(res.body).toHaveProperty('status', 'ok');
        expect(res.body).toHaveProperty('service', 'airthai-backend-api');
      });
  });

  it('/health/ready (GET) should return 200 and readiness status', () => {
    return request(app.getHttpServer())
      .get('/health/ready')
      .expect(200)
      .expect((res) => {
        expect(res.body).toHaveProperty('status', 'ready');
        expect(res.body.services.database).toHaveProperty('status', 'up');
      });
  });

  it('/auth/login (POST) should return 400 when body is invalid', () => {
    return request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'not-an-email', password: '123' })
      .expect(400);
  });

  it('/auth/me (GET) should return 401 Unauthorized without token', () => {
    return request(app.getHttpServer())
      .get('/auth/me')
      .expect(401);
  });
});

