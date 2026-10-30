# AirthAI — MSME Business Operating System (Monorepo)

AirthAI is an offline-first Enterprise Resource Planning (ERP) and business intelligence operating system tailored for Micro, Small, and Medium Enterprises (MSMEs).

---

## Authoritative Repository Directory Structure

This repository is structured as a modular monorepo containing distinct, isolated subsystems:

```
Airthai_app_b/airthai_app/
├── backend/
│   └── api/                # [AUTHORITATIVE] NestJS 10 Modular Monolith API
│       ├── prisma/         # Prisma 6 PostgreSQL schema, migrations & seeders
│       ├── src/            # Auth, Sales, Purchases, Accounting, Copilot, Subscriptions
│       └── test/           # Jest unit, integration & E2E test suites
│
├── frontend/
│   └── flutter_app/        # [AUTHORITATIVE] Production Flutter Multiplatform Application
│       ├── lib/            # Material 3 UI, core services, SQLite sync engine, routing
│       ├── test/           # 17 automated Flutter unit & widget test suites (130 tests)
│       └── web/            # Production web assets, manifest & index.html
│
├── infrastructure/         # Docker, PgBouncer, Nginx & deployment manifests
├── docs/                   # Complete architectural, database, security & audit documentation
└── .github/                # GitHub Actions CI/CD workflows (ci.yml)
```

> **IMPORTANT NOTICE FOR DEVELOPERS & CI WORKFLOWS:**  
> The active production Flutter codebase is located inside **`frontend/flutter_app`**.  
> Always navigate to `frontend/flutter_app` when running Flutter commands (`flutter test`, `flutter analyze`, `flutter build`).  
> The legacy boilerplate files at the repository root are preserved solely for directory structure stability.

---

## Quick Start & Verification

### 1. Backend API (NestJS)
```powershell
cd backend/api
npm install
npm run prisma:validate
npm run prisma:generate
npm test -- --runInBand
npm run build
```

### 2. Frontend Application (Flutter)
```powershell
cd frontend/flutter_app
flutter pub get
flutter analyze lib
flutter analyze test
flutter test
flutter build web --release
```
