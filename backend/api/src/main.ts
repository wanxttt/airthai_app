import { NestFactory } from '@nestjs/core';
import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { AppConfig } from './config/app.config';

async function bootstrap(): Promise<void> {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  const configService = app.get(ConfigService);
  const appCfg = configService.get<AppConfig>('app');

  const port = appCfg?.port ?? 3000;
  const prefix = appCfg?.apiPrefix ?? '/api/v1';
  const corsOrigins = appCfg?.corsOrigins ?? ['http://localhost:3000', 'http://localhost:5000'];

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

  await app.listen(port);
  logger.log(`AirthAI Backend API is running on: http://localhost:${port}/${prefix.replace(/^\//, '')}`);
  logger.log(`Environment: ${appCfg?.nodeEnv ?? 'development'}`);
  logger.log(`Health check: http://localhost:${port}/${prefix.replace(/^\//, '')}/health`);
}

bootstrap().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Fatal error during NestJS bootstrap:', err);
  process.exit(1);
});

