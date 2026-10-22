import appConfig from './app.config';

describe('AppConfig', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('should return default values when environment variables are not set', () => {
    delete process.env.PORT;
    delete process.env.NODE_ENV;
    delete process.env.API_PREFIX;

    const config = appConfig();

    expect(config.port).toBe(3000);
    expect(config.nodeEnv).toBe('development');
    expect(config.apiPrefix).toBe('/api/v1');
    expect(Array.isArray(config.corsOrigins)).toBe(true);
  });

  it('should parse environment variables when supplied', () => {
    process.env.PORT = '8080';
    process.env.NODE_ENV = 'production';
    process.env.API_PREFIX = '/api/v2';
    process.env.CORS_ORIGINS = 'https://app.airthai.in,https://admin.airthai.in';

    const config = appConfig();

    expect(config.port).toBe(8080);
    expect(config.nodeEnv).toBe('production');
    expect(config.apiPrefix).toBe('/api/v2');
    expect(config.corsOrigins).toEqual(['https://app.airthai.in', 'https://admin.airthai.in']);
  });
});

