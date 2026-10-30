import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom Prometheus/k6 Metrics
export const errorRate = new Rate('custom_error_rate');
export const loginLatency = new Trend('login_duration_ms');
export const dashboardLatency = new Trend('dashboard_duration_ms');
export const invoicesLatency = new Trend('invoices_duration_ms');

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // 1. Warm-up: 50 concurrent VUs
    { duration: '1m', target: 100 },   // 2. Normal operational load: 100 VUs
    { duration: '1m', target: 250 },   // 3. Peak load: 250 VUs
    { duration: '1m', target: 500 },   // 4. Stress burst: 500 VUs
    { duration: '1m', target: 1000 },  // 5. Saturation ceiling: 1000 VUs
    { duration: '30s', target: 0 },    // 6. Graceful ramp-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1500'], // 95% of requests under 500ms
    custom_error_rate: ['rate<0.01'],               // Less than 1% errors
  },
};

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:3000/api/v1';

export default function () {
  const correlationId = `k6_${__VU}_${__ITER}_${Date.now()}`;
  const defaultHeaders = {
    'Content-Type': 'application/json',
    'X-Request-Id': correlationId,
  };

  group('01. Health & Readiness Probes', () => {
    const res = http.get(`${BASE_URL}/health`, { headers: defaultHeaders });
    const isOk = check(res, {
      'liveness returns 200': (r) => r.status === 200,
      'service is reported ok': (r) => r.json('status') === 'ok',
    });
    errorRate.add(!isOk);
  });

  group('02. Authentication Journey', () => {
    const payload = JSON.stringify({
      email: __ENV.TEST_USER_EMAIL || 'owner@airthai.in',
      password: __ENV.TEST_USER_PASSWORD || 'AirthAI@2026Secure!',
    });

    const start = Date.now();
    const res = http.post(`${BASE_URL}/auth/login`, payload, { headers: defaultHeaders });
    loginLatency.add(Date.now() - start);

    const isOk = check(res, {
      'login handles request': (r) => r.status === 200 || r.status === 401 || r.status === 429,
    });
    errorRate.add(!isOk);

    let token = null;
    if (res.status === 200) {
      token = res.json('accessToken');
    }

    // Authenticated API Queries (if token available)
    if (token) {
      const authHeaders = Object.assign({}, defaultHeaders, {
        Authorization: `Bearer ${token}`,
      });

      group('03. Dashboard Retrieval (Cached)', () => {
        const dStart = Date.now();
        const dRes = http.get(`${BASE_URL}/reports/dashboard`, { headers: authHeaders });
        dashboardLatency.add(Date.now() - dStart);

        check(dRes, {
          'dashboard returns 200': (r) => r.status === 200,
        });
      });

      group('04. Invoices Pagination', () => {
        const invStart = Date.now();
        const invRes = http.get(`${BASE_URL}/sales/invoices?page=1&limit=20`, { headers: authHeaders });
        invoicesLatency.add(Date.now() - invStart);

        check(invRes, {
          'invoices return 200': (r) => r.status === 200,
        });
      });
    }
  });

  sleep(1); // User think time (1 second between iterations)
}

