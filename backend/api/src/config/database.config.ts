import { registerAs } from '@nestjs/config';

export interface DatabaseConfig {
  url: string;
  maxConnections: number;
  connectionTimeoutMs: number;
  ssl: boolean;
}

export default registerAs(
  'database',
  (): DatabaseConfig => ({
    url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/airthai_db?schema=public',
    maxConnections: parseInt(process.env.DB_MAX_CONNECTIONS || '10', 10),
    connectionTimeoutMs: parseInt(process.env.DB_TIMEOUT_MS || '5000', 10),
    ssl: process.env.DB_SSL === 'true',
  }),
);

