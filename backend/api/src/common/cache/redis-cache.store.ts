import * as net from 'net';
import { Logger } from '@nestjs/common';
import { ICacheStore } from './cache.interface';
import { InMemoryCacheStore } from './in-memory-cache.store';

export interface RedisOptions {
  host: string;
  port: number;
  password?: string;
}

export class RedisCacheStore implements ICacheStore {
  private readonly logger = new Logger(RedisCacheStore.name);
  private readonly fallbackStore = new InMemoryCacheStore();
  private socket: net.Socket | null = null;
  private isConnected = false;
  private connecting = false;

  constructor(private readonly options: RedisOptions) {
    this.connect();
  }

  private connect(): void {
    if (this.connecting || this.isConnected) return;
    this.connecting = true;

    try {
      const socket = net.createConnection({
        host: this.options.host,
        port: this.options.port,
        timeout: 3000,
      });

      socket.on('connect', () => {
        this.isConnected = true;
        this.connecting = false;
        this.socket = socket;
        this.logger.log(`Connected to Redis at ${this.options.host}:${this.options.port}`);

        if (this.options.password) {
          socket.write(this.encodeCommand(['AUTH', this.options.password]));
        }
      });

      socket.on('error', (err) => {
        this.isConnected = false;
        this.connecting = false;
        this.logger.warn(`Redis connection error: ${err.message}. Using in-memory fallback.`);
      });

      socket.on('close', () => {
        this.isConnected = false;
        this.connecting = false;
        this.socket = null;
      });

      socket.on('timeout', () => {
        socket.destroy();
        this.isConnected = false;
        this.connecting = false;
      });
    } catch (err: any) {
      this.connecting = false;
      this.isConnected = false;
      this.logger.warn(`Failed to initialize Redis socket: ${err.message}. Using in-memory fallback.`);
    }
  }

  private encodeCommand(args: string[]): string {
    let cmd = `*${args.length}\r\n`;
    for (const arg of args) {
      const buf = Buffer.from(arg, 'utf8');
      cmd += `$${buf.length}\r\n${arg}\r\n`;
    }
    return cmd;
  }

  private async executeCommand(args: string[]): Promise<string | null> {
    if (!this.isConnected || !this.socket) {
      return null;
    }

    return new Promise((resolve) => {
      const cmd = this.encodeCommand(args);
      let response = '';

      const onData = (data: Buffer) => {
        response += data.toString('utf8');
        cleanup();
        resolve(this.parseResponse(response));
      };

      const onError = () => {
        cleanup();
        resolve(null);
      };

      const timer = setTimeout(() => {
        cleanup();
        resolve(null);
      }, 2000);

      const cleanup = () => {
        clearTimeout(timer);
        this.socket?.removeListener('data', onData);
        this.socket?.removeListener('error', onError);
      };

      this.socket.once('data', onData);
      this.socket.once('error', onError);
      this.socket.write(cmd);
    });
  }

  private parseResponse(res: string): string | null {
    if (!res || res.startsWith('$-1')) return null; // Nil bulk string
    if (res.startsWith('+')) {
      // Simple string, e.g. +OK\r\n
      return res.substring(1).split('\r\n')[0];
    }
    if (res.startsWith(':')) {
      // Integer, e.g. :1\r\n
      return res.substring(1).split('\r\n')[0];
    }
    if (res.startsWith('$')) {
      // Bulk string, e.g. $5\r\nhello\r\n
      const lines = res.split('\r\n');
      if (lines.length >= 2) {
        return lines[1];
      }
    }
    if (res.startsWith('*')) {
      // Multi-bulk array: e.g. *2\r\n$4\r\nkey1\r\n$4\r\nkey2\r\n
      const lines = res.split('\r\n');
      const items: string[] = [];
      for (let i = 1; i < lines.length; i++) {
        if (!lines[i].startsWith('$') && lines[i].length > 0) {
          items.push(lines[i]);
        }
      }
      return items.join('\n');
    }
    return null;
  }

  async get(key: string): Promise<string | null> {
    if (!this.isConnected) {
      return this.fallbackStore.get(key);
    }
    try {
      const result = await this.executeCommand(['GET', key]);
      return result;
    } catch {
      return this.fallbackStore.get(key);
    }
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (!this.isConnected) {
      return this.fallbackStore.set(key, value, ttlSeconds);
    }
    try {
      if (ttlSeconds && ttlSeconds > 0) {
        await this.executeCommand(['SET', key, value, 'EX', ttlSeconds.toString()]);
      } else {
        await this.executeCommand(['SET', key, value]);
      }
    } catch {
      await this.fallbackStore.set(key, value, ttlSeconds);
    }
  }

  async del(key: string): Promise<void> {
    if (!this.isConnected) {
      return this.fallbackStore.del(key);
    }
    try {
      await this.executeCommand(['DEL', key]);
    } catch {
      await this.fallbackStore.del(key);
    }
  }

  async delByPrefix(prefix: string): Promise<void> {
    // Also invalidate fallback
    await this.fallbackStore.delByPrefix(prefix);

    if (!this.isConnected) return;
    try {
      // Redis pattern delete: SCAN or KEYS
      const keysResponse = await this.executeCommand(['KEYS', `${prefix}*`]);
      if (keysResponse) {
        const keys = keysResponse.split('\n').map((k) => k.trim()).filter(Boolean);
        for (const k of keys) {
          await this.executeCommand(['DEL', k]);
        }
      }
    } catch {
      // Ignore prefix scan failure
    }
  }

  async increment(key: string, ttlMs: number): Promise<{ count: number; resetTime: number }> {
    if (!this.isConnected) {
      return this.fallbackStore.increment(key, ttlMs);
    }
    try {
      const countRes = await this.executeCommand(['INCR', key]);
      const count = countRes ? parseInt(countRes, 10) : 1;

      if (count === 1) {
        await this.executeCommand(['PEXPIRE', key, ttlMs.toString()]);
      }
      return { count, resetTime: Date.now() + ttlMs };
    } catch {
      return this.fallbackStore.increment(key, ttlMs);
    }
  }

  async ping(): Promise<boolean> {
    if (!this.isConnected) {
      return true;
    }
    const res = await this.executeCommand(['PING']);
    return res === 'PONG';
  }
}

