import { NestFactory } from '@nestjs/core';
import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { CorrelationIdMiddleware } from './common/middleware/correlation-id.middleware';
import { SecurityHeadersMiddleware } from './common/middleware/security-headers.middleware';
import { AppConfig } from './config/app.config';

async function bootstrap(): Promise<void> {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule, { rawBody: true });

  // Security Headers & Request Correlation Tracing
  const correlationMiddleware = new CorrelationIdMiddleware();
  const securityHeadersMiddleware = new SecurityHeadersMiddleware();
  app.use(correlationMiddleware.use.bind(correlationMiddleware));
  app.use(securityHeadersMiddleware.use.bind(securityHeadersMiddleware));

  const configService = app.get(ConfigService);
  const appCfg = configService.get<AppConfig>('app');

  const port = appCfg?.port ?? 3000;
  const prefix = appCfg?.apiPrefix ?? '/api/v1';
  const corsOrigins = appCfg?.corsOrigins ?? ['http://localhost:3000', 'http://localhost:5000'];
  const nodeEnv = appCfg?.nodeEnv ?? process.env.NODE_ENV ?? 'development';
  const isProduction = nodeEnv === 'production';

  // Secret Hygiene & Production Safety Verification
  const jwtSecret = configService.get<string>('JWT_SECRET');
  const jwtRefreshSecret = configService.get<string>('JWT_REFRESH_SECRET');
  const defaultFallbackSecret = 'replace_with_a_secure_random_64_char_secret_for_production';

  if (isProduction) {
    if (!jwtSecret || jwtSecret === defaultFallbackSecret || jwtSecret.length < 32) {
      logger.error(
        'FATAL CONFIGURATION ERROR: JWT_SECRET must be configured with at least 32 cryptographically secure characters in production.',
      );
      process.exit(1);
    }
    if (!jwtRefreshSecret || jwtRefreshSecret === defaultFallbackSecret || jwtRefreshSecret.length < 32) {
      logger.error(
        'FATAL CONFIGURATION ERROR: JWT_REFRESH_SECRET must be configured with at least 32 cryptographically secure characters in production.',
      );
      process.exit(1);
    }
    if (jwtSecret === jwtRefreshSecret) {
      logger.error(
        'FATAL CONFIGURATION ERROR: JWT_SECRET and JWT_REFRESH_SECRET must be distinct cryptographic keys.',
      );
      process.exit(1);
    }
  } else if (!jwtSecret || jwtSecret === defaultFallbackSecret) {
    logger.warn(
      'SECURITY WARNING: Running with default development JWT secret. Replace before deploying to production.',
    );
  }

  // Global API Prefix
  app.setGlobalPrefix(prefix.replace(/^\//, ''));

  // CORS Configuration
  app.enableCors({
    origin: corsOrigins,
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // Centralized Request Validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // Centralized Error Handling & Structured Logging
  app.useGlobalFilters(new AllExceptionsFilter());
  app.useGlobalInterceptors(new LoggingInterceptor());

  // Graceful Shutdown Hooks
  app.enableShutdownHooks();

  // Trust proxy for proper IP resolution behind load balancers/reverse proxies
  const httpAdapter = app.getHttpAdapter();
  if (httpAdapter && typeof httpAdapter.getInstance === 'function') {
    const expressInstance = httpAdapter.getInstance();
    if (expressInstance && typeof expressInstance.set === 'function') {
      expressInstance.set('trust proxy', 1);
    }
  }

  await app.listen(port);
  logger.log(`AirthAI Backend API is running on: http://localhost:${port}/${prefix.replace(/^\//, '')}`);
  logger.log(`Environment: ${nodeEnv}`);
  logger.log(`Health check: http://localhost:${port}/${prefix.replace(/^\//, '')}/health`);
}

bootstrap().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Fatal error during NestJS bootstrap:', err);
  process.exit(1);
});
