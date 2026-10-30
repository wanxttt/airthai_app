# AirthAI Staging Deployment, Scalability & Operations Guide

## 1. Executive Summary & Staging Architecture

AirthAI's production-ready staging architecture is engineered for high-availability multi-tenant operations, strict transactional tenant isolation, sub-second API latency, and resilient offline synchronization.

The staging environment is deployed as a coordinated container cluster:

```
[ Client Browser / Mobile App / Web ]
                 │
                 ▼
     [ Nginx Reverse Proxy:443 / :80 ]
         │ (Static Web Assets)
         │ (SSL / Gzip / Rate Limit Headers)
         ▼
     [ AirthAI NestJS Backend API:3000 ]
         │ (Non-root user: airthai)
         │ (BullMQ Worker Queues / PDF Engine)
         │
         ├──► [ Redis 7:6379 ] (Distributed Rate Limiting, Dashboard Cache, Job Queues)
         │
         └──► [ PgBouncer:6432 ] (Transaction Connection Pooling, max 1000 conns)
                 │
                 ▼
              [ PostgreSQL 16:5432 ] (Persistent Volume, Decimal-safe Accounting)
```

---

## 2. Infrastructure Components

| Container / Service | Image | Internal Port | External Port | Role |
| :--- | :--- | :--- | :--- | :--- |
| `airthai-nginx-staging` | `nginx:alpine` | `80`, `443` | `80`, `443` | Reverse proxy, SSL termination, HTTP security headers, static asset host |
| `airthai-backend-staging` | Custom Multi-Stage Alpine Node 20 | `3000` | Isolated (internal) | NestJS modular monolith API, BullMQ worker queue processor |
| `airthai-pgbouncer-staging` | `edoburu/pgbouncer:v1.22.1` | `6432` | `6432` | Transaction-level connection pooler preventing connection saturation |
| `airthai-postgres-staging` | `postgres:16-alpine` | `5432` | Isolated (internal) | ACID relational store with decimal-precise financial ledger |
| `airthai-redis-staging` | `redis:7-alpine` | `6379` | `6379` | In-memory distributed store for rate limiting, cache, and worker queues |

---

## 3. Authoritative Environment Variables & Secrets Reference

All staging environment variables MUST be supplied via `.env.staging` (or AWS Secrets Manager / Doppler / GitHub Secrets in CI/CD). **Never commit plain-text credentials to version control.**

| Variable | Type | Default / Example | Purpose & Security Scope |
| :--- | :--- | :--- | :--- |
| `NODE_ENV` | `string` | `staging` | Runtime environment mode |
| `PORT` | `number` | `3000` | Port for the NestJS HTTP server |
| `DATABASE_URL` | `string` | `postgresql://airthai_user:SECRET@pgbouncer:6432/airthai_staging?schema=public&pgbouncer=true` | Prisma connection string routed through PgBouncer |
| `DIRECT_DATABASE_URL` | `string` | `postgresql://airthai_user:SECRET@postgres:5432/airthai_staging?schema=public` | Direct PostgreSQL connection string for DDL migrations (`prisma migrate deploy`) |
| `JWT_SECRET` | `string` | `[64-byte hex string]` | Secret key used to sign Access Tokens (15m expiry) |
| `JWT_REFRESH_SECRET` | `string` | `[64-byte hex string]` | Secret key used to sign Refresh Tokens (7d expiry, family reuse detection) |
| `REDIS_ENABLED` | `boolean` | `true` | Enables distributed Redis caching and worker queues |
| `REDIS_HOST` | `string` | `redis` | Redis service hostname in Docker network |
| `REDIS_PORT` | `number` | `6379` | Redis port |
| `REDIS_PASSWORD` | `string` | `[secure password]` | Redis authentication password |
| `RAZORPAY_KEY_ID` | `string` | `rzp_test_...` | Razorpay gateway identifier |
| `RAZORPAY_KEY_SECRET` | `string` | `[test key secret]` | Razorpay secret for HMAC-SHA256 signature verification |
| `RAZORPAY_WEBHOOK_SECRET`| `string` | `[test webhook secret]` | Razorpay webhook cryptographic verification secret |
| `CORS_ORIGINS` | `string` | `https://staging.airthai.in,http://localhost:8080` | Allowed CORS origins for authenticated API requests |
| `AI_PROVIDER` | `string` | `gemini` | AI Business Copilot provider (`gemini` or `claude`) |
| `GEMINI_API_KEY` | `string` | `[gemini key]` | Google Gemini API key for read-only MSME financial copilot |

---

## 4. PgBouncer Connection Pooling Configuration

Prisma connects to PgBouncer in **Transaction Pooling Mode** (`pool_mode = transaction`) to allow hundreds of concurrent client connections without exhausting PostgreSQL process limits.

### Configuration (`infrastructure/pgbouncer/pgbouncer.ini`)
```ini
[databases]
airthai_staging = host=postgres port=5432 dbname=airthai_staging auth_user=airthai_user

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 50
min_pool_size = 10
reserve_pool_size = 10
reserve_pool_timeout = 5
server_idle_timeout = 300
server_connect_timeout = 15
```

> [!IMPORTANT]
> **Transaction Pooling Rule:** Under transaction pooling, prepared statements must be disabled (`?pgbouncer=true` on the Prisma URL), and table names in raw queries must be enclosed in double quotes (e.g. `"products"`, `"invoices"`). Schema migrations (`prisma migrate`) MUST be executed against `DIRECT_DATABASE_URL` (port 5432), not PgBouncer.

---

## 5. Distributed Rate Limiting & Dashboard Caching

### Distributed Rate Limiting
- **Mechanism:** Implemented in `RateLimitGuard` using atomic Redis `INCR` + `PEXPIRE` commands.
- **Key Scheme:** `ratelimit:<client_ip>:<clean_path>`
- **Fail-Safe:** If Redis becomes unreachable, `RateLimitGuard` automatically and transparently falls back to its internal in-memory bucket store without dropping requests or throwing 500 errors.

### Authoritative Dashboard Caching
- **Mechanism:** Implemented in `DashboardService` via `CacheService`.
- **Key Scheme:** `dashboard:<businessId>:<period>:<startDate>:<endDate>`
- **TTL:** 120 seconds.
- **Automatic Invalidation:** Whenever an invoice, purchase, or expense is created or cancelled in `InvoicesService`, `PurchasesService`, or `ExpensesService`, `cacheService.delByPrefix('dashboard:' + businessId)` immediately purges the cache so users always see real-time figures.

---

## 6. Asynchronous Worker Processing (BullMQ & PDF Engine)

Long-running and CPU-intensive operations (such as PDF generation and batch offline sync replay) are executed asynchronously outside the HTTP request-response cycle:

1. **Immediate Download:** `GET /api/v1/invoices/:id/pdf` streams the binary PDF-1.4 buffer directly to the client.
2. **Asynchronous Generation:** `POST /api/v1/invoices/:id/pdf/async` enqueues a background job in `WorkerQueueService`, returning `HTTP 202 Accepted` with a `jobId`.
3. **Status Polling:** `GET /api/v1/invoices/pdf/jobs/:jobId` returns the job status (`PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`) and base64-encoded PDF artifact.
4. **Resilience Policy:** Jobs automatically retry up to 3 times with exponential backoff before transitioning to `FAILED`.

---

## 7. Step-by-Step Staging Deployment Runbook

### Step 1: Clone Repository & Prepare Staging Secrets
```bash
git clone https://github.com/airthai-org/airthai_app.git
cd airthai_app

# Generate strong random secrets
JWT_SECRET=$(openssl rand -hex 32)
JWT_REFRESH_SECRET=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -hex 16)

# Create staging .env
cat <<EOF > .env.staging
NODE_ENV=staging
PORT=3000
POSTGRES_DB=airthai_staging
POSTGRES_USER=airthai_user
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
DATABASE_URL=postgresql://airthai_user:${POSTGRES_PASSWORD}@pgbouncer:6432/airthai_staging?schema=public&pgbouncer=true
DIRECT_DATABASE_URL=postgresql://airthai_user:${POSTGRES_PASSWORD}@postgres:5432/airthai_staging?schema=public
REDIS_ENABLED=true
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
EOF
```

### Step 2: Build and Launch Staging Stack
```bash
docker compose -f infrastructure/docker/docker-compose.staging.yml --env-file .env.staging up -d --build
```

### Step 3: Run Database Migrations
```bash
docker compose -f infrastructure/docker/docker-compose.staging.yml exec backend npx prisma migrate deploy
```

### Step 4: Verify Health Probes
```bash
# Backend Health Probe
curl -f http://localhost:80/api/v1/health

# Direct Container Health Probe
docker compose -f infrastructure/docker/docker-compose.staging.yml exec backend node -e "
  require('http').get('http://localhost:3000/api/v1/health', (r) => {
    process.exit(r.statusCode === 200 ? 0 : 1);
  });
"
```

---

## 8. Backup & Disaster Recovery Runbook

### Automated Daily Backup (`pg_dump`)
```bash
#!/bin/bash
BACKUP_DIR="/var/backups/airthai"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/airthai_staging_${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

# Execute pg_dump directly against PostgreSQL with compression
docker compose -f infrastructure/docker/docker-compose.staging.yml exec -T postgres \
  pg_dump -U airthai_user -d airthai_staging --clean --if-exists | gzip > "${BACKUP_FILE}"

# Enforce 30-day retention
find "${BACKUP_DIR}" -type f -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: ${BACKUP_FILE}"
```

### Restore Runbook
```bash
# 1. Stop backend and PgBouncer to terminate active client connections
docker compose -f infrastructure/docker/docker-compose.staging.yml stop backend pgbouncer

# 2. Decompress and restore database
gunzip -c /var/backups/airthai/airthai_staging_TARGET.sql.gz | \
  docker compose -f infrastructure/docker/docker-compose.staging.yml exec -T postgres \
  psql -U airthai_user -d airthai_staging

# 3. Restart services
docker compose -f infrastructure/docker/docker-compose.staging.yml start pgbouncer backend
```

### Rollback Procedure
If a newly deployed backend build experiences runtime faults:
```bash
# 1. Roll back backend image to previous tag
docker compose -f infrastructure/docker/docker-compose.staging.yml stop backend
docker compose -f infrastructure/docker/docker-compose.staging.yml up -d --no-deps backend:previous

# 2. Verify health probe
curl -f http://localhost:80/api/v1/health
```

---

## 9. Staging Verification Checklist

- [x] **CI Pipeline:** GitHub Actions runs backend tests/build and Flutter analysis/tests on every PR.
- [x] **Monorepo Architecture:** Monorepo canonical root documented; root boilerplate points to `frontend/flutter_app`.
- [x] **Container Isolation:** Multi-stage Docker builds run under unprivileged `airthai` UID 1001.
- [x] **Connection Pooling:** PgBouncer configured in transaction mode on port 6432.
- [x] **Distributed Cache:** Redis-backed caching with automatic failover to in-memory store.
- [x] **Worker Queues:** Asynchronous PDF invoice rendering with retry policy.
- [x] **Web Offline Persistence:** `LocalStorage` snapshot persistence preserves offline queues across browser reloads.
- [x] **Automated Tests:** 37 backend suites (249 tests) and 18 frontend suites (132 tests) — 381/381 tests passing.

