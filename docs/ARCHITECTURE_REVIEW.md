# AirthAI MSME Operating System — Architecture Review & Technical Debt Assessment

**Document Version:** 1.0.0  
**Audit Date:** October 2026  
**Auditor Classification:** Principal Software Architect & Senior Flutter/NestJS Engineer  
**Target Repository:** `C:\Users\Lenovo\Airthai_app_b\airthai_app`  

---

## 1. High-Level System Context (C4 Model - Level 1 & 2)

AirthAI is structured as a cloud-synchronized, offline-first Enterprise Resource Planning (ERP) and business intelligence operating system tailored for Micro, Small, and Medium Enterprises (MSMEs).

```
                      +---------------------------------------+
                      |               End User                |
                      |  (MSME Owner, Accountant, Sales Rep)  |
                      +---------------------------------------+
                                          |
                                          v
                      +---------------------------------------+
                      |         AirthAI Flutter Client        |
                      |   (Web, Mobile Android/iOS, Desktop)  |
                      |   - Material 3 Responsive UI          |
                      |   - Local SQLite Data Engine          |
                      |   - Offline Sync Queue & Replayer     |
                      +---------------------------------------+
                                          |
                            HTTPS / JSON REST API (v1)
                                          |
                                          v
                      +---------------------------------------+
                      |        AirthAI NestJS API             |
                      |         (Modular Monolith)            |
                      |   - Auth, RBAC & Tenant Guard         |
                      |   - Sales, Purchases & Inventory      |
                      |   - Payments, Expenses & GL Engine    |
                      |   - Subscriptions & Webhook Receiver  |
                      |   - AI Copilot Analytics Engine       |
                      +---------------------------------------+
                             |                    |
                 Prisma ORM  |                    | HTTP API
                             v                    v
              +-----------------------+   +-------------------+
              | PostgreSQL Relational |   | External Services |
              |      Database         |   | - Razorpay GW     |
              | (Multi-tenant schema) |   | - OpenAI API      |
              +-----------------------+   +-------------------+
```

---

## 2. Backend Architecture: NestJS Modular Monolith

### 2.1 Domain Boundaries & Module Decomposition
The backend employs a clean Modular Monolith design pattern within NestJS 10, compartmentalizing discrete business domains into dedicated feature modules:

1. **`AuthModule` (`src/auth/`):** Identity management, password hashing, JWT issue/validation, token family rotation, and global route guards (`JwtAuthGuard`, `TenantGuard`, `RolesGuard`, `RateLimitGuard`).
2. **`MasterDataModule` (`src/master-data/`):** Shared reference entities (`Customer`, `Supplier`, `Product`, `Category`, `Unit`).
3. **`SalesModule` (`src/sales/`):** Commercial revenue workflows (`Quotation`, `Invoice`, `InvoiceItem`), sequential numbering service (`SequenceService`), tax calculators.
4. **`PurchasesInventoryModule` (`src/purchases-inventory/`):** Vendor procurement (`PurchaseOrder`, `VendorBill`), inventory movements (`StockMovement`), and weighted average cost revaluation.
5. **`PaymentsExpensesModule` (`src/payments-expenses/`):** Cash flow instruments (`PaymentReceipt`, `SupplierPayment`, `Expense`), FIFO payment allocation algorithms.
6. **`AccountingModule` (`src/accounting/`):** Financial core (`ChartOfAccounts`, `JournalEntry`, `JournalEntryLine`, `TrialBalance`, `ProfitAndLoss`, `GSTService`).
7. **`SubscriptionsModule` (`src/subscriptions/`):** Commercial plans, quota enforcement middleware, payment provider abstraction (`IPaymentProvider`), Razorpay integration.
8. **`SyncModule` (`src/sync/`):** Offline synchronization endpoint, operation ingestion, sequence resolution.
9. **`CopilotModule` (`src/copilot/`):** Deterministic SQL-backed business query engine, prompt sanitization, optional LLM grounding.
10. **`AuditModule` & `NotificationsModule` (`src/audit/`, `src/notifications/`):** Cross-cutting concerns for audit logging and tenant alerts.

### 2.2 Request Lifecycle & Pipeline Guards
Every incoming HTTP request passes through a strictly ordered execution pipeline:
```
Client Request
    |
    v
Express CORS & Body Parser (Raw body preserved for /subscriptions/webhook)
    |
    v
HttpExceptionFilter (Global Exception Sanitization)
    |
    v
ValidationPipe (class-validator DTO validation with whitelist & forbidNonWhitelisted)
    |
    v
RateLimitGuard (IP & sliding window brute-force protection)
    |
    v
JwtAuthGuard (Passport JWT token extraction & signature verification)
    |
    v
TenantGuard (Tenant claim verification & row-level tenant context injection)
    |
    v
RolesGuard (RBAC role authorization check)
    |
    v
Target Controller -> Domain Service -> Prisma Transaction -> PostgreSQL
```

---

## 3. Frontend Architecture: Flutter Cross-Platform Client

### 3.1 Project Structure & Separation of Concerns
The production Flutter application resides in `frontend/flutter_app`:
- **`lib/core/`:** Foundational infrastructure including database abstraction (`DatabaseManager`, `AppDatabase`), network connectivity detection (`ConnectivityService`), route definitions (`AppRouter`, `RouteNames`), security storage (`SessionManager`), and offline sync (`SyncQueue`, `SyncManager`).
- **`lib/features/`:** Feature slices following clean presentation/state/service layering:
  - `auth/`: Login, registration, token refresh orchestration.
  - `landing/`: Public marketing landing page.
  - `legal/`: Terms of service, privacy policy.
  - `dashboard/`: Executive KPI summary cards and activity feeds.
  - `sales/`: Invoicing, quotations, customer selection, line-item tax calculation.
  - `purchases/`: Vendor bills, purchase orders.
  - `inventory/`: Stock tracking, low stock alerts, catalog management.
  - `payments/` & `expenses/`: Receipt capture, vendor disbursements, expense logging.
  - `accounting/`: General ledger explorer, journal entries, trial balance, GST reports.
  - `subscriptions/`: Plan tier comparison, upgrade checkout.
  - `copilot/`: Interactive business analytics assistant.
- **`lib/shared/`:** Reusable UI components (`AppShell`, `AirthaiCard`, `MetricTile`, `ResponsiveLayout`).

### 3.2 State Management & Service Architecture
- Current state management leverages encapsulated service Singletons with reactive `ValueNotifier` and `ChangeNotifier` state containers.
- View models manage local screen states, while domain services (`SalesService`, `InventoryService`, `AccountingService`) communicate with `ApiConstants` and `DatabaseManager` to ensure seamless offline-first operation.

---

## 4. End-to-End Business Flow Invariants

The architecture enforces the canonical AirthAI business loop:
$$\text{RECORD} \longrightarrow \text{UNDERSTAND} \longrightarrow \text{PREDICT} \longrightarrow \text{RECOMMEND} \longrightarrow \text{APPROVE} \longrightarrow \text{EXECUTE} \longrightarrow \text{LEARN}$$

1. **RECORD:** An operator records an invoice, bill, or receipt (online via REST API or offline via SQLite SyncQueue).
2. **UNDERSTAND:** Domain services immediately update double-entry journals, inventory moving average costs, and customer balances within atomic transactions.
3. **PREDICT:** Dashboard metrics and Copilot analytics aggregate real-time cash runway, upcoming payable obligations, and low stock items.
4. **RECOMMEND:** Notifications and Copilot surface actionable insights (e.g., "Reorder Product X", "Follow up on Invoice Y overdue by 45 days").
5. **APPROVE:** High-impact operations (journal adjustments, plan upgrades, stock write-offs) require explicit human approval via RBAC.
6. **EXECUTE:** Immutable commits, sequential numbering, and audit logs are recorded.
7. **LEARN:** Usage patterns, tax categories, and customer payment turnaround feed subsequent predictive analytics.

---

## 5. Technical Debt Register & Remediation Recommendations

| Debt ID | Subsystem | Severity | Description | Recommended Remediation |
| :--- | :--- | :--- | :--- | :--- |
| **DEBT-01** | Repository Structure | Medium | Root directory contains legacy Flutter boilerplate alongside active `frontend/flutter_app`. | Deprecate root-level Flutter boilerplate files (`lib/`, `pubspec.yaml` at root) to prevent developer confusion. |
| **DEBT-02** | State Management | Low | Mixed use of `ChangeNotifier` and reactive service listeners across some Flutter screens. | Standardize on Riverpod (`flutter_riverpod`) across all feature screens in Phase 2. |
| **DEBT-03** | Background Tasks | Medium | In-process execution of PDF generation and webhook processing. | Introduce Redis-backed BullMQ worker queue for asynchronous background jobs (invoices PDF, email alerts). |
| **DEBT-04** | Database Connection | Low | Standard Prisma pool configuration without PgBouncer. | Add PgBouncer connection pooler in staging/production for high-concurrency connection reuse. |
| **DEBT-05** | Cache Layer | Low | Dashboard KPIs computed dynamically from PostgreSQL on each request. | Introduce Redis cache with 60-second TTL for dashboard metrics and reference master data. |

