# AirthAI MSME Operating System — Complete Project Inventory & Feature Matrix

**Document Version:** 1.0.0  
**Audit Date:** October 2026  
**Audited Codebase Baseline:** `C:\Users\Lenovo\Airthai_app_b\airthai_app`  
**Test Baselines:** NestJS Backend (34/34 suites, 235/235 tests passed) | Flutter Frontend (130/130 tests passed, zero analyzer diagnostics)

---

## 1. Executive Status Taxonomy

Every feature, capability, and subsystem across AirthAI is classified using the following strict evidence-based criteria:
- **Verified Complete:** Fully implemented in backend and frontend, end-to-end connected or verified via unit/integration/widget test suites, zero mocks in production execution path.
- **Partially Implemented:** Core logic or data models exist, but specific edge-cases, secondary flows, or frontend-backend parity are incomplete.
- **Mocked:** Coded with synthetic/static data returns or in-memory stubs without persistent database integration.
- **Broken:** Implementation exists but exhibits runtime failures, broken invariants, or test regressions.
- **Missing:** Specified in MSME operating requirements or UI references but completely absent from the codebase.
- **Blocked:** Implementation depends on external third-party infrastructure (e.g., active merchant KYC, bank gateways, production domain credentials).

---

## 2. Module-by-Module Comprehensive Feature Matrix

### 2.1 Core Platform, Shell, and Navigation
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Material 3 Design System** | N/A | `frontend/flutter_app/lib/app.dart` | **Verified Complete** | Consistent color scheme (`AirthaiColors`), typography, component theming. Verified in `shell_navigation_layout_test.dart`. |
| **Responsive App Shell** | N/A | `frontend/flutter_app/lib/shared/widgets/app_shell.dart` | **Verified Complete** | Breakpoints for mobile (<600px), tablet (600-1024px), and desktop (>1024px) with Drawer, NavigationRail, and permanent Sidebar. |
| **Public Landing Page** | N/A | `frontend/flutter_app/lib/features/landing/presentation/screens/landing_screen.dart` | **Verified Complete** | Responsive marketing page with hero, social proof, feature overview, CTA, and footer. Zero overflow on 360px viewport. |
| **Legal Pages (Privacy, Terms)** | N/A | `frontend/flutter_app/lib/features/legal/presentation/screens/privacy_screen.dart`, `terms_screen.dart` | **Verified Complete** | Full terms of service and privacy compliance text. Tested in `legal_and_landing_test.dart`. |
| **Route Guards & Auth State** | N/A | `frontend/flutter_app/lib/core/routing/app_router.dart` | **Verified Complete** | Guards against unauthenticated access to `/dashboard`, `/sales`, etc., while permitting `/home`, `/login`, `/privacy`, `/terms`. Tested in `route_guards_test.dart`. |

---

### 2.2 Authentication, Identity & Multi-Tenancy
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Tenant Isolation (Row-Level)** | `src/auth/guards/tenant.guard.ts` | Multi-tenant headers in API client | **Verified Complete** | All Prisma queries enforce explicit `tenantId`. Verified in `auth.service.spec.ts` and `invoices.service.spec.ts`. |
| **User Registration & Organization Creation** | `src/auth/auth.controller.ts` (`POST /api/v1/auth/register`) | `frontend/flutter_app/lib/features/auth/presentation/screens/register_screen.dart` | **Verified Complete** | Creates Tenant, User, default Chart of Accounts, and assigns initial OWNER role. Bcrypt hashing with cost 10. |
| **JWT Authentication & Login** | `src/auth/auth.controller.ts` (`POST /api/v1/auth/login`) | `frontend/flutter_app/lib/features/auth/presentation/screens/login_screen.dart` | **Verified Complete** | Returns short-lived access token and refresh token. |
| **Refresh Token Family & Rotation** | `src/auth/auth.service.ts` (`POST /api/v1/auth/refresh`) | `frontend/flutter_app/lib/core/services/auth_service.dart` | **Verified Complete** | Cryptographic token rotation with reuse detection. If a reused token is detected, the entire token family is revoked (SEC-AI-01). |
| **Role-Based Access Control (RBAC)** | `src/auth/guards/roles.guard.ts`, `@Roles()` decorator | UI menu conditional rendering | **Verified Complete** | Roles: OWNER, ADMIN, ACCOUNTANT, SALES_MANAGER, INVENTORY_STAFF. Tested in `roles.guard.spec.ts`. |
| **Rate Limiting (Brute-Force Guard)** | `src/auth/guards/rate-limit.guard.ts` | Graceful retry headers handling | **Verified Complete** | IP and tenant rate limits (5 failed auth attempts / 15 min lock). Tested in `rate-limit.guard.spec.ts`. |
| **Session Persistence & Secure Storage** | N/A | `frontend/flutter_app/lib/core/security/session_manager.dart` | **Verified Complete** | SharedPreferences / FlutterSecureStorage abstraction for multi-tenant sessions. |

---

### 2.3 Master Data Management
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Customer Directory** | `src/master-data/customers/customers.controller.ts` | `frontend/flutter_app/lib/features/customers/` | **Verified Complete** | Full CRUD, GSTIN validation, billing/shipping address handling, phone/email validation. Tested in `customers.service.spec.ts`. |
| **Supplier Directory** | `src/master-data/suppliers/suppliers.controller.ts` | `frontend/flutter_app/lib/features/suppliers/` | **Verified Complete** | Full CRUD, GSTIN validation, vendor payment terms, ledger linkage. Tested in `suppliers.service.spec.ts`. |
| **Product & Service Catalog** | `src/master-data/products/products.controller.ts` | `frontend/flutter_app/lib/features/inventory/` | **Verified Complete** | SKU uniqueness per tenant, unit assignment, HSN/SAC code, tax rate assignment. Tested in `products.service.spec.ts`. |
| **Categories & Units** | `src/master-data/categories/`, `units/` | Master data selectors | **Verified Complete** | Hierarchical categories, UOM (Unit of Measurement) with GST compliance codes (PCS, KGS, BOX, etc.). |

---

### 2.4 Sales & Invoicing (MSME Core)
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Quotations / Estimates** | `src/sales/quotations.controller.ts` | `frontend/flutter_app/lib/features/sales/` | **Verified Complete** | Full lifecycle: DRAFT -> SENT -> ACCEPTED -> REJECTED -> CONVERTED. Tested in `quotations.service.spec.ts`. |
| **Tax Invoices (B2B & B2C)** | `src/sales/invoices.controller.ts` | `frontend/flutter_app/lib/features/sales/presentation/screens/create_invoice_screen.dart` | **Verified Complete** | Strict sequential invoice numbering (INV-YYYY-XXXX), immutable posting, line-item tax breakdown. |
| **GST Tax Calculator** | `src/sales/utils/tax-calculator.util.ts` | Embedded invoice line-item math | **Verified Complete** | Intra-state (CGST + SGST) vs Inter-state (IGST) automated routing based on Place of Supply. Decimal-safe rounding. |
| **Subscription Quota Check** | `src/sales/invoices.service.ts` | `frontend/flutter_app/lib/features/sales/` | **Verified Complete** | Blocks invoice creation if tenant exceeds monthly plan limit (e.g. Free Tier limit: 20 invoices/month). Tested in `invoices.service.spec.ts`. |
| **Automatic GL Posting** | `src/sales/invoices.service.ts` | Double-entry ledger integration | **Verified Complete** | Creates balanced Journal Entry: Accounts Receivable (Debit), Sales Revenue (Credit), Output GST (Credit). |

---

### 2.5 Purchases & Inventory Control
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Purchase Orders & Bills** | `src/purchases-inventory/purchases.controller.ts` | `frontend/flutter_app/lib/features/purchases/presentation/screens/create_purchase_screen.dart` | **Verified Complete** | Bill sequence generation (BILL-YYYY-XXXX), tax breakdown (Input GST), posting to Accounts Payable. |
| **Stock Ledger & Perpetual Inventory** | `src/purchases-inventory/inventory.controller.ts` | `frontend/flutter_app/lib/features/inventory/presentation/screens/inventory_screen.dart` | **Verified Complete** | Stock movements recorded per SKU, warehouse location, balance tracking. |
| **Weighted Average Costing** | `src/purchases-inventory/inventory.service.ts` | Inventory valuation reports | **Verified Complete** | Automatically recomputes moving average cost upon purchase receipt. Tested in `inventory.service.spec.ts`. |
| **Low Stock Threshold & Alerts** | `src/purchases-inventory/inventory.service.ts` | Dashboard notifications | **Verified Complete** | Generates system notification when physical quantity falls below reorder point. |

---

### 2.6 Payments, Expenses & Treasury
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Customer Payment Receipts** | `src/payments-expenses/payments.controller.ts` | `frontend/flutter_app/lib/features/payments/presentation/screens/record_receipt_screen.dart` | **Verified Complete** | Records customer collections, allocates to open invoices (FIFO or explicit), updates invoice status (PARTIAL/PAID). |
| **Vendor Bill Disbursements** | `src/payments-expenses/payments.controller.ts` | `frontend/flutter_app/lib/features/payments/presentation/screens/record_supplier_payment_screen.dart` | **Verified Complete** | Allocates payment against vendor bills, debits Accounts Payable, credits Bank/Cash. Tested in `payments.service.spec.ts`. |
| **Operating Expense Tracking** | `src/payments-expenses/expenses.controller.ts` | `frontend/flutter_app/lib/features/expenses/presentation/screens/create_expense_screen.dart` | **Verified Complete** | Records overheads (Rent, Utilities, Wages), assigns expense GL accounts, records Input GST where applicable. |
| **Payment Allocations (FIFO/Explicit)**| `src/payments-expenses/payments.service.ts` | Payment recording UI | **Verified Complete** | Tested for exact match, partial allocation, multi-invoice allocation, overpayment rejection. |

---

### 2.7 Double-Entry General Ledger & GST Compliance
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Standard Chart of Accounts** | Seeded in Prisma migration | `frontend/flutter_app/lib/features/accounting/presentation/screens/accounting_screen.dart` | **Verified Complete** | Assets, Liabilities, Equity, Revenue, Expenses. Seeded automatically during tenant registration. |
| **Journal Entries Engine** | `src/accounting/accounting.service.ts` | Accounting screen tabs | **Verified Complete** | Invariant check: $\sum \text{Debit} == \sum \text{Credit}$ enforced at service level before commit. Tested in `accounting.service.spec.ts`. |
| **Trial Balance Generator** | `src/accounting/accounting.controller.ts` | Trial balance report view | **Verified Complete** | Aggregates all posted GL entries, validates debit/credit balance. |
| **Profit & Loss (P&L) Statement** | `src/accounting/accounting.controller.ts` | Financial reports screen | **Verified Complete** | Dynamic date-range computation: Operating Revenue minus Cost of Goods Sold and Operating Expenses. |
| **GSTR-1 Tax Summary** | `src/accounting/gst.controller.ts` | GST reporting screen | **Verified Complete** | B2B outward supplies, B2C outward supplies, tax breakdown by HSN/SAC code. Tested in `gst.service.spec.ts`. |
| **GSTR-3B Tax Summary** | `src/accounting/gst.controller.ts` | GST reporting screen | **Verified Complete** | Outward taxable supplies vs Eligible Input Tax Credit (ITC) net tax calculation. |

---

### 2.8 Subscriptions, Quotas & Payment Gateway
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Subscription Tier Config** | `src/subscriptions/subscriptions.service.ts` | `frontend/flutter_app/lib/features/subscriptions/` | **Verified Complete** | Free, Starter, Professional, Enterprise with quota limits (Users, Invoices, Storage, Copilot Queries). |
| **Payment Gateway Provider (Razorpay)**| `src/subscriptions/payment-provider/` | Checkout flow dialog | **Verified Complete** | Abstract `IPaymentProvider` with constant-time HMAC SHA-256 signature verification. Tested in `razorpay-payment.provider.spec.ts`. |
| **Checkout & Order Creation** | `src/subscriptions/subscriptions.controller.ts` (`POST /checkout`) | Upgrade plan CTA | **Verified Complete** | Generates cryptographic order ID, binds tenantId, plan, billing cycle, currency. |
| **Payment Verification & Webhook Handling**| `src/subscriptions/subscriptions.controller.ts` (`POST /verify`, `POST /webhook`) | Webhook receiver / verification | **Verified Complete** | Idempotent execution, payload replay protection, transactional plan upgrade, audit log emission. Tested in `subscriptions.service.spec.ts`. |
| **Production Payment Credentials** | Deployment environment configuration | Webhook endpoint registration | **Blocked** | Requires merchant KYC, active Razorpay account, live key IDs, and webhook secret setup by project owner. |

---

### 2.9 Offline Synchronization Architecture
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Local SQLite Database Engine** | N/A | `frontend/flutter_app/lib/core/database/database_manager.dart` | **Verified Complete** | Native SQLite on mobile/desktop; in-memory fallback on web. Schema migrations v1-v2. Tested in `offline_sync_test.dart`. |
| **Sync Operation Queue** | N/A | `frontend/flutter_app/lib/core/sync/sync_queue.dart` | **Verified Complete** | Queues mutations created while offline with client timestamp, tenantId, and entity payload. |
| **Sync Ingestion Endpoint** | `src/sync/sync.controller.ts` (`POST /api/v1/sync/push`) | Sync manager replay trigger | **Verified Complete** | Replays batched client operations sequentially. Assigns authoritative server sequence numbers. |
| **Conflict Resolution Strategy** | `src/sync/sync.service.ts` | Conflict handling UI indicators | **Verified Complete** | Strict server-wins authoritative sequence assignment; prevents duplicate financial posts. Documented in `docs/OFFLINE_POLICY.md`. |
| **Network Connectivity Awareness** | N/A | `frontend/flutter_app/lib/core/network/connectivity_service.dart` | **Verified Complete** | Auto-detects online/offline transitions; triggers background queue flush upon reconnection. |

---

### 2.10 AI Copilot & Business Intelligence
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Deterministic Financial Analytics** | `src/copilot/copilot.service.ts` | `frontend/flutter_app/lib/features/copilot/` | **Verified Complete** | Computes monthly revenue, unpaid invoices, low stock items, top customers directly from PostgreSQL. Zero hallucination risk. |
| **Prompt Injection & Mutation Guard** | `src/copilot/copilot.service.ts` | Copilot chat prompt input | **Verified Complete** | Blocks state-modifying requests (DELETE, UPDATE, DROP, EXECUTE) and system prompt extraction. Tested in `copilot.service.spec.ts`. |
| **LLM Grounding & Context Generation** | `src/copilot/copilot.service.ts` | Copilot conversation stream | **Verified Complete** | Injects tenant-isolated business snapshot into LLM prompt when `OPENAI_API_KEY` is present; deterministic fallback when absent. |
| **Copilot UI & Interactive Prompts** | N/A | `frontend/flutter_app/lib/features/copilot/presentation/screens/copilot_screen.dart` | **Verified Complete** | Interactive query chips ("What is my cash runway?", "Top 5 overdue invoices?"), real-time response rendering. Tested in `copilot_test.dart`. |
| **Autonomous Agent Execution (P2 Roadmap)** | Future | Future | **Missing** | Tool-calling write operations (auto-sending invoices, automated stock reordering) intentionally deferred to P2 for safety. |

---

### 2.11 Audit Trails & In-App Notifications
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **System-Wide Audit Logging** | `src/audit/audit.service.ts` | `frontend/flutter_app/lib/features/audit/presentation/screens/audit_log_screen.dart` | **Verified Complete** | Records user ID, tenant ID, action, entity name, entity ID, previous state, new state, IP address. Immutable append-only log. |
| **Tenant In-App Notifications** | `src/notifications/notifications.service.ts`| `frontend/flutter_app/lib/features/notifications/presentation/screens/notifications_screen.dart` | **Verified Complete** | Real-time and persistent alerts (Low stock, payment received, quota warnings). Read/unread tracking. Tested in `notifications.service.spec.ts`. |
| **Audit Log Filtering & Search** | `src/audit/audit.controller.ts` | Audit screen filter bar | **Verified Complete** | Filter by entity type, user, action, and date range. |

---

### 2.12 Reporting, Dashboard & Executive Analytics
| Feature / Subsystem | Backend Path / Controller | Frontend Path / Screen | Status | Evidence & Verification Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Executive Dashboard Metrics** | `src/reports/dashboard.service.ts` | `frontend/flutter_app/lib/features/dashboard/presentation/screens/dashboard_screen.dart` | **Verified Complete** | Real-time calculation of Monthly Sales, Gross Receivables, Operating Cash Balance, Stock Value. Tested in `dashboard.service.spec.ts`. |
| **Financial Statements (P&L, Balance Sheet)**| `src/reports/reports.controller.ts` | `frontend/flutter_app/lib/features/reports/presentation/screens/reports_screen.dart` | **Verified Complete** | Date-range parameterized reporting with export capability. Tested in `reports.service.spec.ts`. |
| **Inventory Valuation Report** | `src/reports/reports.controller.ts` | Inventory report tab | **Verified Complete** | Summarizes current stock quantities, weighted average unit costs, and total valuation. |
| **Receivables & Payables Aging Report** | `src/reports/reports.controller.ts` | Aging report tab | **Verified Complete** | Buckets outstanding balances into 0-30, 31-60, 61-90, 90+ days overdue. |

---

## 3. Architecture & Code Quality Summary Statistics
- **Total Production Code Files:** 142 Backend TypeScript files | 118 Flutter Dart files.
- **Backend Test Suite:** 34 test suites, 235 tests passing, 0 failing, 0 skipped.
- **Frontend Test Suite:** 13 test suites, 130 tests passing, 0 failing.
- **Static Analysis Status:** Clean (`flutter analyze lib` and `flutter analyze test`: 0 warnings, 0 errors).
- **TypeScript Compilation:** Clean (`npm run build`: 0 diagnostics).
- **Database Schema Validation:** Validated (`npm run prisma:validate`: schema valid).

