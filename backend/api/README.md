# AirthAI Backend API Foundation (Phase 3)

The NestJS Modular Monolith API powering the AirthAI MSME Business OS.

---

## 1. Prerequisites

- **Node.js**: `v20.x` or `v22.x` (LTS recommended)
- **npm**: `v10.x` or `v11.x`
- **PostgreSQL**: `v15+` (for database persistence and ACID constraints)

---

## 2. Quick Setup

```bash
# 1. Navigate to backend directory
cd backend/api

# 2. Install dependencies
npm install

# 3. Create local environment configuration
cp .env.example .env

# 4. Generate Prisma Client from validated Phase 2 schema
npm run prisma:generate
```

---

## 3. Running the Server

```bash
# Development mode with hot-reload
npm run start:dev

# Production build and run
npm run build
npm run start:prod
```

The API runs by default at `http://localhost:3000/api/v1`.

---

## 4. Health and Monitoring Endpoints

- **Liveness probe**: `GET /api/v1/health`
  Returns service status, uptime, and timestamp without sensitive environment exposure.
- **Readiness probe**: `GET /api/v1/health/ready`
  Performs live database connectivity test and measures latency.

---

## 5. Automated Tests

```bash
# Run unit tests
npm run test

# Run e2e tests
npm run test:e2e
```

