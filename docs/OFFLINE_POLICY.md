# AirthAI — Offline-First Architecture & Synchronization Policy

This document defines the authoritative offline-first storage and synchronization policy for the AirthAI business management application.

---

## 1. Architecture Overview

AirthAI utilizes a durable offline-first architecture comprising:
- **Flutter Client:** Relational local storage (`AppDatabase`), schema migrations, and a persistent operation queue (`SyncQueue`).
- **NestJS Modular Monolith:** Authoritative business logic, financial validation, double-entry accounting journals, and sequence generation.
- **PostgreSQL Database:** The single authoritative source of truth.
- **Durable Operation Queue (`local_sync_queue` & server `sync_queues`):** Guarantees at-least-once delivery with exactly-once idempotent execution.

---

## 2. Core Offline Operations (Supported Locally)

The following core commercial transactions are fully authorized for offline creation and editing when network connectivity is unavailable:

| Operation | Local Storage Table | Offline Document Number | Server Sync Action |
|---|---|---|---|
| **Create Sales Invoice** | `local_invoices`, `local_invoice_items` | `OFFLINE-INV-<HEX>` | Computes taxes, books stock movement, books double-entry receivable journal, issues authoritative canonical invoice number (`INV-YYYY-YY-XXXX`). |
| **Create Purchase Bill** | `local_purchases`, `local_purchase_items` | `OFFLINE-PUR-<HEX>` | Books stock intake, creates payable journal, issues canonical purchase number (`PUR-YYYY-YY-XXXX`). |
| **Record Customer Receipt** | `local_payments`, `local_payment_allocations` | `OFFLINE-PAY-<HEX>` | Allocates payment to invoice, credits customer receivable, debits cash/bank ledger, issues canonical receipt number. |
| **Record Supplier Payment** | `local_payments`, `local_payment_allocations` | `OFFLINE-PAY-<HEX>` | Allocates payment to purchase, debits supplier payable, credits cash/bank ledger. |
| **Record Business Expense** | `local_expenses` | `OFFLINE-EXP-<HEX>` | Verifies category, debits expense account, credits payment method account. |
| **Master Data Creation** | `local_customers`, `local_suppliers`, `local_products` | Local UUID | Synchronizes master data entity with server ID mapping. |

All local mutations are committed **atomically** with their pending sync queue record using `AppDatabase.transaction(...)`. If any validation or storage error occurs, the entire transaction rolls back.

---

## 3. Operations That MUST Remain Online-Only

Certain operations require real-time centralized synchronization or external statutory authority and **cannot be performed offline**:

1. **User Registration & Business Tenant Provisioning:**
   - *Reason:* Enforces global uniqueness of user emails, provisions database tenant isolation, generates cryptographically signed JWT credentials.
2. **Financial Year Closure & Ledger Freezing:**
   - *Reason:* Closing books requires locking all journals across all devices and generating final retained earnings equity entries.
3. **Statutory Government E-Invoicing & E-Way Bill Generation:**
   - *Reason:* Directly interacts with government GSTN/NIC APIs; signed QR codes and IRN numbers must be obtained in real-time from the tax authority.
4. **Subscription Management & Payment Gateway Processing:**
   - *Reason:* Third-party PCI-DSS payment gateways (Stripe, Razorpay) require live transaction webhooks.

---

## 4. Document Numbering & Sequence Safety

### Non-Authoritative Offline Numbering
- Devices working offline cannot safely predict canonical sequential invoice numbers without risking collision with other devices or sequence gaps.
- While offline, transactions receive a temporary, explicitly flagged document number:
  - `OFFLINE-INV-<TIMESTAMP_HEX>`
  - `OFFLINE-PUR-<TIMESTAMP_HEX>`
  - `OFFLINE-PAY-<TIMESTAMP_HEX>`
- The UI explicitly renders these as `[Pending Sync - OFFLINE-...]`.

### Authoritative Server Confirmation
- Upon network restoration, the sync engine transmits the operation to NestJS `/api/v1/sync/batch`.
- NestJS `SequenceService` generates the official canonical sequential number (e.g. `INV-2026-27-0042`) under a database transaction lock.
- The server returns an acknowledgement payload containing `canonicalDocumentNumber`.
- `SyncRepository.applyServerAcknowledgement` atomically updates `local_invoices`, replacing the temporary offline number with the authoritative number and updating `sync_status = SYNCED`.

---

## 5. Idempotent Processing & Duplicate Prevention

To prevent duplicate invoices, duplicate payment allocations, duplicate stock movements, or duplicate accounting entries when requests are retried:
1. Every offline transaction originates with a cryptographically secure, stable **`clientOperationId` (RFC-4122 v4 UUID)**.
2. The `clientOperationId` remains constant across all network retries, timeouts, and device reboots.
3. NestJS controllers and services check `clientOperationId`:
   - If an operation with this ID was already processed, the backend immediately returns the existing transaction record with `idempotentReplay: true`.
   - **No secondary journals, stock movements, or balance changes are posted.**

---

## 6. Versioning & Conflict Resolution Policy

### Optimistic Concurrency Control
- All mutable entities maintain a monotonic `version` integer (initial value: 1).
- When a client submits an update operation, it includes its known `version`.
- If the server has a higher version (indicating concurrent edits from another device):
  1. The server flags the response with `status: 'CONFLICT'`.
  2. The server returns the authoritative server entity.
  3. The client updates local entity status to `SyncStatus.conflict`.
  4. **Data is never silently overwritten.** Both the local edits and server record are preserved for user inspection and explicit resolution.

---

## 7. Bounded Retries & Exponential Backoff

The sync engine employs bounded retries to prevent network flooding and battery drain:
- **Maximum Retries:** 5 attempts.
- **Backoff Formula:** `Delay = BaseDelay (1000ms) * 2^retryCount + Jitter`.
- **Status Lifecycle:**
  - `localDraft`: In-progress draft, not yet queued.
  - `pending`: Saved locally, queued in `local_sync_queue`.
  - `inProgress`: Actively transmitting to server.
  - `synced`: Server acknowledged with canonical sequence.
  - `conflict`: Version mismatch, user intervention required.
  - `failed`: Retries exhausted or non-retryable 4xx rejection.
- **Manual Retry:** Users can trigger `retryAllFailed()` or retry individual operations directly via the top AppBar sync badge.

---

## 8. Security & Multi-Tenant Data Scoping

- All local SQLite/in-memory tables enforce tenant scoping via `business_id`.
- On user logout or account switching:
  - `DatabaseManager.instance.clearTenantData(businessId)` purges all local tenant invoices, line items, customers, suppliers, inventory, and sync queue items.
  - `SyncManager.instance.reset()` terminates active sync operations.
  - Sensitive cached tokens and session keys are deleted from secure storage.

