import { registerAs } from '@nestjs/config';

export interface AiConfig {
  apiKey?: string;
  model: string;
  timeoutMs: number;
}

export default registerAs(
  'ai',
  (): AiConfig => ({
    apiKey: process.env.OPENAI_API_KEY || undefined,
    model: process.env.AI_MODEL || 'gpt-4o',
    timeoutMs: parseInt(process.env.AI_TIMEOUT_MS || '30000', 10),
  }),
);

