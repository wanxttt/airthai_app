# AirthAI MSME Operating System — Database & Data Integrity Audit

**Document Version:** 1.0.0  
**Audit Date:** October 2026  
**Auditor Classification:** PostgreSQL Database Architect & Financial Systems Engineer  
**Target Repository:** `C:\Users\Lenovo\Airthai_app_b\airthai_app`  
**Prisma Schema Baseline:** `backend/api/prisma/schema.prisma` (1018 lines)  
**Integrity Status:** Verified, Strong Multi-Tenant Composite Key Isolation, Strict Decimal Precision  

---

## 1. Schema Architecture & Multi-Tenant Relational Isolation

The AirthAI persistence layer is governed by Prisma ORM 6 against PostgreSQL. The schema employs an **explicit multi-tenant composite foreign-key architecture**.

### 1.1 Mandatory Multi-Tenant Foreign Key Hierarchy
Rather than relying solely on simple surrogate foreign keys (`customerId -> id`), every domain table enforces a composite reference keyed on `[businessId, ...]`:
```prisma
model Invoice {
  id         String   @id @default(uuid())
  businessId String
  customerId String?
  customer   Customer? @relation(fields: [businessId, customerId], references: [businessId, id], onDelete: Restrict)
  ...
}
```
**Physical Guarantee:** This prevents any accidental data cross-link across tenants at the PostgreSQL engine level. If an API request attempts to associate Tenant A's invoice with Tenant B's customer, the PostgreSQL foreign key constraint immediately rejects the insert with a foreign key violation (`P2003`), providing physical data isolation above and beyond application-level guards.

---

## 2. Referential Integrity & Deletion Safeguards

### 2.1 Restrict vs. Cascade Policies
A critical review of `schema.prisma` confirms strict financial data retention safeguards:
- **`onDelete: Restrict` (Protected Financial & Master Records):**
  - `Invoice` -> `Business`: Restrict
  - `Customer` -> `Business`: Restrict
  - `Product` -> `Business`: Restrict
  - `JournalEntry` -> `Business`: Restrict
  - `Account` -> `Business`: Restrict
  - `Payment` -> `Business`: Restrict
  - `StockMovement` -> `Business`: Restrict
  *Rationale:* MSME statutory compliance requires complete auditability. Historical invoices, stock ledgers, and journals cannot be inadvertently dropped if a user or category is modified.
- **`onDelete: Cascade` (Strictly Bound Child Line Items):**
  - `InvoiceItem` -> `Invoice`: Cascade
  - `PurchaseItem` -> `Purchase`: Cascade
  - `LedgerEntry` -> `JournalEntry`: Cascade
  - `PaymentAllocation` -> `Payment`: Cascade
  *Rationale:* Child line items have no standalone semantic existence outside their parent transaction voucher.

---

## 3. Financial Decimal Precision & Arithmetic Safety

Floating-point inaccuracies (e.g., `0.1 + 0.2 = 0.30000000000000004`) in billing and tax computation lead to statutory penalties, audit failure, and customer distrust.

### 3.1 Schema-Enforced Decimal Precision
All monetary, inventory quantity, and tax rate fields in `schema.prisma` are strictly typed as:
$$\text{Decimal}(12, 2)$$
This provides an exact numeric range of up to:
$$\pm 9,999,999,999.99$$
(nearly 10 billion currency units) with exact 2-decimal-place cent/paisa precision.

### 3.2 Key Precision Audit Across Entities:
| Entity | Field | Type | Invariant / Validation |
| :--- | :--- | :--- | :--- |
| `Invoice` | `subtotal`, `taxAmount`, `totalAmount`, `paidAmount` | `@db.Decimal(12, 2)` | $\text{totalAmount} = \text{subtotal} + \text{taxAmount}$ |
| `InvoiceItem` | `quantity`, `unitPrice`, `taxRate`, `taxAmount`, `total` | `@db.Decimal(12, 2)` | $\text{total} = (\text{qty} \times \text{price}) + \text{tax}$ |
| `LedgerEntry` | `debit`, `credit` | `@db.Decimal(12, 2)` | Monotonically positive; one side must be 0.00 |
| `StockMovement`| `quantity`, `unitCost` | `@db.Decimal(12, 2)` | Revaluation updates moving average unit cost |
| `GstRecord` | `taxableValue`, `cgstAmount`, `sgstAmount`, `igstAmount` | `@db.Decimal(12, 2)` | Matches statutory GST rates (0%, 5%, 12%, 18%, 28%) |
| `SubscriptionOrder` | `amount` | `Int` (in paise/cents) | Integer base units for payment gateway compatibility |

---

## 4. Double-Entry General Ledger Invariants

The accounting subsystem (`src/accounting/accounting.service.ts`) enforces the fundamental equation of double-entry bookkeeping:
$$\sum \text{Debits} \equiv \sum \text{Credits}$$
$$\text{Assets} \equiv \text{Liabilities} + \text{Equity}$$

### 4.1 Transactional Invariant Validation
Before any `JournalEntry` is committed to PostgreSQL via Prisma:
1. The service calculates total debits and total credits across all `ledgerEntries`.
2. A strict difference threshold of $| \text{Debits} - \text{Credits} | < 0.001$ is enforced.
3. If unbalanced, the transaction immediately aborts with `BadRequestException("Journal entry is not balanced")` without altering account balances.
4. Verified in `backend/api/src/accounting/accounting.service.spec.ts`.

---

## 5. Document State Lifecycles & Immutability

### 5.1 Sales Invoice Lifecycle
```
[DRAFT]  ---> (Issue / Post) --->  [ISSUED]  ---> (Payment Allocated) ---> [PARTIALLY_PAID] ---> [PAID]
   |                                  |
   +-----> (Cancel) ---> [CANCELLED]  +-----> (Cancel / Credit Note) ---> [CANCELLED]
```
- Once an invoice transitions from `DRAFT` to `ISSUED`:
  - An immutable sequential invoice number (`INV-YYYY-XXXX`) is allocated.
  - A corresponding balanced `JournalEntry` is automatically posted.
  - Stock movements (`SALE`) are registered against physical stock.
  - Line items become immutable.

### 5.2 Subscription Order Lifecycle (SEC-PAY-01/02/03)
```
[PENDING] ---> (Gateway Checkout) ---> [PROCESSING] ---> (HMAC Signature Verified) ---> [PAID]
    |                                                                                     |
    +-----> (Timeout / Failure) ---> [FAILED]                       (Tenant Plan Upgraded & Audit Emitted)
```
- Orders store unique `gatewayOrderId` with an `@unique` index.
- Duplicate webhook payloads check existing state; if already `PAID`, the webhook returns HTTP 200 without duplicate quota modification.

---

## 6. Concurrency Control & Atomic Transactions

### 6.1 Prisma `$transaction` Isolation
Multi-table mutations are wrapped in atomic database transactions:
- **Invoice Creation:** Generates sequence number, creates invoice header, creates invoice line items, inserts stock movements, decrements stock on hand, and inserts GL journal entries inside a single `prisma.$transaction`.
- **Payment Allocation:** Inserts `Payment`, allocates portions to target `Invoice` records, updates invoice `paidAmount` and status, and posts cash/bank debit and AR credit in a single transaction.

### 6.2 Sequence Number Race-Condition Protection
- Document sequences (`DocumentSequence` model) utilize unique compound keys `[businessId, documentType]`.
- Future enhancement: Use PostgreSQL `SELECT ... FOR UPDATE` row-level locks on `DocumentSequence` during peak concurrent billing rushes.

---

## 7. Migration Baseline & Recommendations
- Current Prisma schema is fully validated: `npm run prisma:validate` exits 0.
- Database migrations use declarative Prisma migrations under `prisma/migrations/`.
- **Recommendation:** Implement automated pre-deployment migration dry-runs (`prisma migrate deploy`) in GitHub Actions CI/CD to prevent migration stalls in production.

