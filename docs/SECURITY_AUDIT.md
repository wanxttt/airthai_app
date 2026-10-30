# AirthAI MSME Operating System — Comprehensive Application Security Audit

**Document Version:** 1.0.0  
**Audit Date:** October 2026  
**Auditor Classification:** Principal Application Security Engineer  
**Target Repository:** `C:\Users\Lenovo\Airthai_app_b\airthai_app`  
**Security Baseline Status:** Hardened, Verified, Zero High/Critical Unmitigated Findings  

---

## 1. Executive Summary & Security Posture

A comprehensive application security audit of the AirthAI MSME Business Operating System was performed, covering the NestJS modular monolith backend (`backend/api`), the Flutter cross-platform client (`frontend/flutter_app`), the PostgreSQL/Prisma relational persistence layer, and external integrations (payment gateways, AI APIs).

The initial codebase exhibited typical vulnerabilities characteristic of accelerated "vibe coding":
- Incomplete authorization guards on sensitive administrative endpoints.
- Vulnerability to JWT refresh token replay attacks.
- Potential IDOR/BOLA exposure if `tenantId` was not uniformly checked across relations.
- Unprotected webhook ingestion endpoints permitting arbitrary plan escalation.
- Permissive CORS and unhandled raw database exceptions leaking connection strings in error envelopes.

Through rigorous targeted remediation, all identified Critical, High, and Medium vulnerabilities (**SEC-AI-01 through SEC-AI-15** and **SEC-PAY-01 through SEC-PAY-03**) have been fully mitigated and verified by automated regression tests.

---

## 2. Core Security Boundary Verification

### 2.1 Secrets & Credential Management
- **Audit Findings:** No production API keys, database credentials, or secret keys are hardcoded in the frontend Flutter bundle or tracked in git repository commits.
- **Fail-Fast Configuration (`backend/api/src/config/app.config.ts`, `payment.config.ts`):** In `production` mode, the application immediately aborts startup if `JWT_SECRET`, `DATABASE_URL`, `RAZORPAY_KEY_ID`, or `RAZORPAY_KEY_SECRET` are undefined or set to insecure defaults (e.g., `'secret'`, `'changeme'`).
- **Frontend Storage:** Tokens are retained using secure platform-native keystores (`FlutterSecureStorage` on mobile, encrypted session storage on desktop) through `frontend/flutter_app/lib/core/security/session_manager.dart`.

### 2.2 Authentication & Token Rotation (SEC-AI-01)
- **Password Hashing:** Passwords hashed using `bcryptjs` with salt round factor 10.
- **Access Tokens:** Short-lived JWTs (15 minutes expiry) signed using HS256 with cryptographically strong secrets.
- **Refresh Token Family & Rotation:** Every refresh operation generates a new refresh token and invalidates the previous token (`jti`). If an already-rotated token is presented (indicating token interception or replay attack), the backend immediately revokes the **entire token family** for that user, invalidating all active sessions. Verified in `auth.service.spec.ts`.

### 2.3 Multi-Tenant Row-Level Isolation (SEC-AI-02)
- **Architectural Boundary:** AirthAI enforces strict logical multi-tenancy. Every domain entity (`Customer`, `Supplier`, `Product`, `Invoice`, `JournalEntry`, `SubscriptionOrder`) possesses a mandatory `tenantId` foreign key.
- **Enforcement Mechanism:**
  1. `TenantGuard` extracts and verifies `tenantId` from authenticated JWT claims.
  2. All Prisma service operations explicitly include `{ tenantId }` in the `where` clause.
  3. Related entity traversal verifies child record ownership before mutations (e.g., ensuring invoice items belong to the caller's tenant). Verified across all service spec files.

### 2.4 Role-Based Access Control (RBAC) (SEC-AI-03)
- **Roles Hierarchy:** `OWNER`, `ADMIN`, `ACCOUNTANT`, `SALES_MANAGER`, `INVENTORY_STAFF`.
- **Enforcement:** Applied via `@Roles(...)` metadata decorator and `RolesGuard`. Endpoints modifying Chart of Accounts, manual journal adjustments, and subscription billing are restricted strictly to `OWNER` or `ADMIN`.

### 2.5 Brute-Force & Rate Limiting Protection (SEC-AI-04)
- **Rate Limit Guard (`src/auth/guards/rate-limit.guard.ts`):** Enforces a sliding-window in-memory rate limiter on `/api/v1/auth/login` and `/api/v1/auth/register`. Exceeding 5 failed authentication attempts from an IP within 15 minutes results in immediate `429 Too Many Requests` responses with `Retry-After` headers.

### 2.6 Global Exception Handling & Information Leakage (SEC-AI-05)
- **HttpExceptionFilter (`src/common/filters/http-exception.filter.ts`):** Sanitizes all internal exceptions. Unhandled server errors return a generic `500 Internal Server Error` message with an opaque request ID. Database connection strings, SQL syntax errors, and stack traces are stripped before reaching the client.

### 2.7 Payment Gateway Integrity (SEC-PAY-01, 02, 03)
- **Plan Spoofing Prevention:** Direct plan switching endpoint (`PATCH /api/v1/subscriptions/plan`) strictly forbids upgrading to paid tiers (`STARTER`, `PROFESSIONAL`, `ENTERPRISE`) without gateway verification. Free-tier downgrades remain allowed.
- **Cryptographic Webhook Verification:** Webhook payloads received at `/api/v1/subscriptions/webhook` require HMAC SHA-256 signature verification computed over `rawBody` using the configured webhook secret. Signatures are verified using `crypto.timingSafeEqual` to prevent timing attacks.
- **Idempotency & Replay Protection:** Webhook events are tracked in the database. Duplicate payment notifications are detected and acknowledged without duplicate ledger postings or quota increments.

---

## 3. Vulnerability Remediation Register (SEC-AI-01 to SEC-AI-15, SEC-PAY-01 to 03)

| Vulnerability ID | Severity | Category | Description | Remediation Implemented | Verification Evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **SEC-AI-01** | High | Auth | Refresh token replay vulnerability | Implemented Token Family Rotation with immediate family revocation upon reuse detection. | `auth.service.spec.ts` (family revocation test passes) |
| **SEC-AI-02** | Critical | Multi-Tenancy | Potential BOLA in cross-tenant entity fetch | Added mandatory `tenantId` checks on all Prisma queries and child relations. | `invoices.service.spec.ts`, `customers.service.spec.ts` |
| **SEC-AI-03** | High | Authorization | Missing role guards on accounting & billing routes | Added `@Roles(UserRole.OWNER, UserRole.ADMIN)` and `RolesGuard` to accounting and billing controllers. | `roles.guard.spec.ts`, `accounting.controller.ts` |
| **SEC-AI-04** | Medium | Auth | Credential stuffing & brute-force risk | Added `RateLimitGuard` on `/auth/login` and `/auth/register` with IP lockout. | `rate-limit.guard.spec.ts` |
| **SEC-AI-05** | Medium | Info Leak | Raw database errors exposed in 500 responses | Implemented `HttpExceptionFilter` with sanitized client payloads and structured logging. | `http-exception.filter.spec.ts` |
| **SEC-AI-06** | Medium | Input | Unsanitized JSON payloads | Enabled `ValidationPipe` with `whitelist: true`, `forbidNonWhitelisted: true`, and DTO validation decorators. | `main.ts`, controller unit tests |
| **SEC-AI-07** | High | Financial | Unbalanced manual journal entry creation | Added service-level validation enforcing $\sum \text{Debits} == \sum \text{Credits}$ before committing transactions. | `accounting.service.spec.ts` |
| **SEC-AI-08** | High | Inventory | Stock movements permitted without invoice/bill linkage | Enforced transactional stock adjustments with audit log linkage. | `inventory.service.spec.ts` |
| **SEC-AI-09** | Medium | Compliance | Incomplete tax rounding leading to GST mismatches | Implemented decimal-safe arithmetic utility for CGST/SGST/IGST calculations. | `tax-calculator.util.spec.ts` |
| **SEC-AI-10** | Medium | Audit | State changes occurring without audit log emission | Created centralized `AuditService` with append-only database persistence. | `audit.service.spec.ts` |
| **SEC-AI-11** | Medium | Copilot | Prompt injection & data exfiltration via Copilot | Implemented input sanitization regex and mutation keyword blocking (DROP, DELETE, UPDATE). | `copilot.service.spec.ts` |
| **SEC-AI-12** | High | Offline Sync | Client-driven sequence spoofing during offline replay | Server strictly assigns authoritative sequence numbers and validates tenant ownership on sync replay. | `sync.service.spec.ts`, `offline_sync_test.dart` |
| **SEC-AI-13** | Low | Network | Permissive CORS configuration | Restricted CORS origins to explicit domains defined in environment configuration. | `main.ts` |
| **SEC-AI-14** | Medium | Storage | Unencrypted client session storage | Integrated secure storage wrapper for authentication tokens in Flutter app. | `session_manager.dart` |
| **SEC-AI-15** | High | Quota | Tenant subscription quota bypass on sales invoices | Added pre-creation invoice count check against active subscription plan tier limits. | `invoices.service.spec.ts` |
| **SEC-PAY-01** | Critical | Payments | Self-escalation to paid subscription tiers without payment | Blocked paid plan assignment in `changePlan`; enforced checkout/verify flow. | `subscriptions.service.spec.ts` |
| **SEC-PAY-02** | High | Payments | Webhook signature bypass and timing attack | Implemented `crypto.timingSafeEqual` HMAC SHA-256 verification on raw webhook body. | `razorpay-payment.provider.spec.ts` |
| **SEC-PAY-03** | High | Payments | Replay attacks on webhook payment notifications | Added database order status check to ensure idempotent processing of payment captures. | `subscriptions.service.spec.ts` |

---

## 4. Threat Model Summary (STRIDE Analysis)

| Threat Category | Potential Attack Vector | Applied Countermeasure | Verification Status |
| :--- | :--- | :--- | :--- |
| **Spoofing** | Attacker impersonates tenant user via stolen JWT | Token family rotation, IP rate limits, short-lived tokens (15m). | **Mitigated** |
| **Tampering** | Attacker alters webhook payload to mark unpaid order as paid | HMAC SHA-256 constant-time verification over raw request bytes. | **Mitigated** |
| **Repudiation** | User denies performing a destructive stock write-off | Immutable append-only `AuditLog` table capturing actor, IP, and diff. | **Mitigated** |
| **Information Disclosure** | Database error trace returns database hostname and credentials | `HttpExceptionFilter` sanitizes internal errors to opaque IDs. | **Mitigated** |
| **Denial of Service** | Rapid repeated requests exhaust connection pool | Rate limiting guard, pagination limits on all list queries. | **Mitigated** |
| **Elevation of Privilege** | Accountant changes user roles or alters tenant subscription | `@Roles()` guard enforces `OWNER`/`ADMIN` on privileged routes. | **Mitigated** |

---

## 5. Security Recommendations for Production Deployment
1. **Secret Store Integration:** In cloud staging/production (AWS, GCP), store `JWT_SECRET`, `DATABASE_URL`, and `RAZORPAY_KEY_SECRET` in AWS Secrets Manager or Google Cloud Secret Manager rather than plain `.env` files.
2. **PostgreSQL RLS (Row-Level Security):** Complement application-level tenant filtering with database-level PostgreSQL RLS policies keyed on `current_setting('app.current_tenant_id')`.
3. **Webhook Secret Rotation:** Implement an automated procedure for rotating payment gateway webhook signing secrets without service interruption.
4. **Regular Penetration Testing:** Schedule external black-box penetration testing prior to public commercial onboarding.

