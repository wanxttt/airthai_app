import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import appConfig from './config/app.config';
import databaseConfig from './config/database.config';
import redisConfig from './config/redis.config';
import storageConfig from './config/storage.config';
import aiConfig from './config/ai.config';
import { DatabaseModule } from './database/database.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig, databaseConfig, redisConfig, storageConfig, aiConfig],
    }),
    DatabaseModule,
    HealthModule,
    AuthModule,
  ],
})
export class AppModule {}

