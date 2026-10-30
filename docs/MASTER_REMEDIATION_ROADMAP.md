# AirthAI MSME Operating System — Master Remediation & Engineering Roadmap

**Document Version:** 1.0.0  
**Audit Date:** October 2026  
**Auditor Classification:** Principal Software Architect & Engineering Leadership Team  
**Execution Strategy:** Strict Prioritization (P0 -> P1 -> P2 -> P3 -> P4) with Continuous Test Invariants  

---

## 1. Roadmap Prioritization Framework

All engineering initiatives are prioritized according to impact on security, financial correctness, statutory compliance, and commercial viability:

- **P0: Critical Security, Financial Integrity & Data Safety (COMPLETED)**
  *Focus:* Remediate vulnerabilities that could lead to financial loss, cross-tenant data leaks, or unverified plan escalation.
- **P1: Production Hardening, CI/CD & Staging Launch (IMMEDIATE NEXT)**
  *Focus:* Prepare staging environment, finalize legal metadata, automate GitHub Actions CI/CD pipelines, and configure production container images.
- **P2: Performance, Scalability & Asynchronous Queues**
  *Focus:* Decouple CPU-intensive workloads (PDF generation, bulk sync) to BullMQ/Redis worker queues; introduce PgBouncer and dashboard caching.
- **P3: Commercial Feature Completeness & Statutory Enhancements**
  *Focus:* Automated bank statement import, customer payment reminders via WhatsApp, and e-Invoicing (IRN/QR code) government portal integration.
- **P4: Autonomous AI Agent Workflows**
  *Focus:* Human-in-the-loop autonomous agents for stock reorder drafting, smart invoice matching, and dynamic cash forecasting.

---

## 2. Detailed Roadmap Batches & Acceptance Criteria

### Batch P0: Security & Financial Core (COMPLETED & VERIFIED)
- [x] **P0-1: Refresh Token Family Rotation (SEC-AI-01)**
  - *Status:* Verified in `auth.service.spec.ts`.
  - *Acceptance:* Reusing a previously exchanged refresh token revokes all tokens in the family.
- [x] **P0-2: Multi-Tenant Row-Level Security (SEC-AI-02)**
  - *Status:* Verified across all 34 backend test suites.
  - *Acceptance:* All queries include `tenantId`; cross-tenant entity operations throw 404/403.
- [x] **P0-3: Double-Entry Balancing Invariant (SEC-AI-07)**
  - *Status:* Verified in `accounting.service.spec.ts`.
  - *Acceptance:* Journal entries with $|\text{Debit} - \text{Credit}| \ge 0.001$ are rejected before database commit.
- [x] **P0-4: Payment Gateway Cryptographic Hardening (SEC-PAY-01/02/03)**
  - *Status:* Verified in `subscriptions.service.spec.ts` and `razorpay-payment.provider.spec.ts`.
  - *Acceptance:* Paid plan tampering blocked; HMAC SHA-256 signatures verified with constant-time equality; duplicate webhooks handled idempotently.
- [x] **P0-5: Copilot Read-Only Guard & Injection Defense (SEC-AI-11)**
  - *Status:* Verified in `copilot.service.spec.ts` and `copilot_test.dart`.
  - *Acceptance:* Mutations blocked; deterministic fallback returns authoritative numbers without hallucination.

---

### Batch P1: Production Hardening & Staging Deployment (RECOMMENDED IMMEDIATE BATCH)
- [ ] **P1-1: Automated CI/CD GitHub Actions Workflow**
  - *Scope:* `.github/workflows/ci.yml`.
  - *Acceptance:* Executes `npm test`, `npm run build`, `flutter analyze`, and `flutter test` on every pull request.
- [ ] **P1-2: Production Multi-Stage Dockerization**
  - *Scope:* `backend/api/Dockerfile` and `infrastructure/docker/docker-compose.prod.yml`.
  - *Acceptance:* Generates minimal Alpine-based Node.js runtime container running with non-root user.
- [ ] **P1-3: Legal & Entity Metadata Finalization**
  - *Scope:* `frontend/flutter_app/lib/features/legal/presentation/screens/`.
  - *Acceptance:* Replace placeholder support email and business address with registered legal entity details.
- [ ] **P1-4: Automated Migration Deployment Guard**
  - *Scope:* Package deployment script `prisma migrate deploy`.
  - *Acceptance:* Prevents application launch if database schema is out of sync with Prisma models.

---

### Batch P2: Performance, Scalability & Caching
- [ ] **P2-1: Asynchronous Worker Architecture (BullMQ + Redis)**
  - *Scope:* Offload invoice PDF generation and bulk offline sync ingestion to background worker threads.
  - *Acceptance:* API response time for invoice generation remains $< 150\text{ ms}$; PDF generation completes asynchronously.
- [ ] **P2-2: Connection Pooling with PgBouncer**
  - *Scope:* Dockerized PgBouncer configuration with transaction-level pooling.
  - *Acceptance:* Supports 500 concurrent connections without exhausting PostgreSQL process limits.
- [ ] **P2-3: Redis Dashboard & Master Data Cache**
  - *Scope:* `@Inject(CACHE_MANAGER)` on `DashboardService` with 120s TTL and mutation-driven cache eviction.
  - *Acceptance:* Dashboard P95 latency drops below $20\text{ ms}$ under concurrent load.

---

### Batch P3: Commercial Features & Compliance
- [ ] **P3-1: Bank Account Statement Reconciliation (OFX / CSV)**
  - *Scope:* Ingest standard Indian bank statements (HDFC, ICICI, SBI) and provide semi-automated payment allocation.
  - *Acceptance:* Matches bank credit entries to outstanding customer invoices with confidence score.
- [ ] **P3-2: WhatsApp Payment Reminders & Invoicing**
  - *Scope:* Integration with WhatsApp Business API to dispatch payment receipts and invoice PDFs.
  - *Acceptance:* One-click customer reminder dispatch with opt-in tracking.
- [ ] **P3-3: GST Portal Direct e-Invoice / IRN Generation**
  - *Scope:* NIC e-Invoice API integration for enterprises with annual turnover $> \text{₹5 Crore}$.
  - *Acceptance:* Generates IRN and signed QR code automatically on invoice issuance.

---

### Batch P4: Autonomous AI Agent Workflows
- [ ] **P4-1: Smart Stock Reorder Agent**
  - *Scope:* Autonomous background monitor identifying fast-moving stock reaching safety threshold.
  - *Acceptance:* Drafts Purchase Order with preferred supplier and pre-negotiated unit costs; prompts owner for one-tap biometric approval.
- [ ] **P4-2: Predictive Cash Runway Forecaster**
  - *Scope:* Time-series revenue forecasting model trained on historical tenant invoice turnaround times.
  - *Acceptance:* Displays low-cash probability curve 30/60/90 days in advance with sensitivity levers.

---

## 3. Verification Protocol & Quality Gates
No code change shall be merged without fulfilling the Three Invariants:
1. **Zero Regression:** All 235 backend tests and 130 Flutter tests must remain 100% green.
2. **Zero Analyzer Warnings:** `flutter analyze` and TypeScript `eslint` must report 0 diagnostics.
3. **Financial Invariance:** Every monetary calculation must utilize decimal-safe precision and balanced double-entry journals.

