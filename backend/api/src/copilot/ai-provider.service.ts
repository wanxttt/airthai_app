import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AiConfig } from '../config/ai.config';

export interface CompletionOptions {
  systemPrompt: string;
  userPrompt: string;
  temperature?: number;
  maxTokens?: number;
}

@Injectable()
export class AiProviderService {
  private readonly logger = new Logger(AiProviderService.name);
  private readonly config: AiConfig;

  constructor(private readonly configService: ConfigService) {
    this.config = this.configService.get<AiConfig>('ai') || {
      model: 'gpt-4o',
      timeoutMs: 30000,
    };
  }

  isConfigured(): boolean {
    return !!this.config.apiKey && this.config.apiKey.trim().length > 0;
  }

  getModelName(): string {
    return this.config.model;
  }

  async generateCompletion(options: CompletionOptions): Promise<string> {
    if (!this.isConfigured()) {
      throw new Error('AI provider is not configured. Missing server-side API key.');
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.config.timeoutMs);

    try {
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.config.apiKey}`,
        },
        body: JSON.stringify({
          model: this.config.model,
          temperature: options.temperature ?? 0.1,
          max_tokens: options.maxTokens ?? 1000,
          messages: [
            { role: 'system', content: options.systemPrompt },
            { role: 'user', content: options.userPrompt },
          ],
        }),
        signal: controller.signal,
      });

      if (!response.ok) {
        const errorText = await response.text();
        this.logger.error(`AI Provider HTTP ${response.status}: ${errorText}`);
        throw new Error(`AI Provider HTTP ${response.status}: ${errorText}`);
      }

      const data = await response.json();
      return data.choices?.[0]?.message?.content || '';
    } catch (err: any) {
      if (err.name === 'AbortError') {
        throw new Error(`AI Provider request timed out after ${this.config.timeoutMs}ms.`);
      }
      throw err;
    } finally {
      clearTimeout(timeout);
    }
  }
}

