# AirthAI Database Schema Reference (PostgreSQL & Prisma)

## Overview

This document serves as the authoritative data dictionary for the **AirthAI MSME Business OS** database.
The server-side database is **PostgreSQL**, managed through **Prisma ORM**.

- **Primary Keys:** Every table uses standard `UUIDv4` strings (`String @id @default(uuid())`).
- **Multi-Tenancy:** Every tenant-owned record contains a mandatory `businessId` referencing `businesses(id)`.
- **Financial Precision:** All monetary amounts use exact `Decimal(12, 2)` (or `Decimal(14, 2)` for account balances). Floating-point types are strictly forbidden.
- **Timestamps:** Every mutable business record tracks `createdAt` and `updatedAt`.

---

## Enumerations

| Enum Name | Values | Purpose |
| :--- | :--- | :--- |
| `TaxType` | `UNREGISTERED`, `REGULAR`, `COMPOSITION` | Governs GST registration mode and automated tax behavior. |
| `BillFormat` | `A4_STANDARD`, `A5_COMPACT`, `THERMAL_80MM`, `THERMAL_58MM` | The 4 approved visual bill rendering layouts. |
| `ItemType` | `GOODS`, `SERVICE` | Distinguishes physical inventory items from non-stock services. |
| `InvoiceStatus` | `DRAFT`, `ISSUED`, `PARTIALLY_PAID`, `PAID`, `CANCELLED` | Legal sales document lifecycle state. |
| `PurchaseStatus` | `ORDERED`, `RECEIVED`, `CANCELLED` | Inward vendor bill lifecycle state. |
| `PaymentType` | `CUSTOMER_RECEIPT`, `SUPPLIER_PAYMENT` | Direction of financial settlement. |
| `PaymentMethod` | `CASH`, `UPI`, `BANK_TRANSFER`, `CHEQUE`, `CARD` | Monetary transaction instrument. |
| `PaymentStatus` | `UNPAID`, `PARTIALLY_PAID`, `PAID` | Settlement status of commercial invoices/bills. |
| `StockMovementType` | `PURCHASE`, `SALE`, `SALE_RETURN`, `PURCHASE_RETURN`, `ADJUSTMENT_ADD`, `ADJUSTMENT_SUB`, `DAMAGE`, `TRANSFER` | Immutable inventory ledger movement categories. |
| `AccountType` | `ASSET`, `LIABILITY`, `EQUITY`, `REVENUE`, `EXPENSE` | Standard double-entry accounting classifications. |
| `SyncStatus` | `SYNCED`, `PENDING`, `CONFLICT` | Offline synchronization state tracking. |

---

## Data Models

### 1. Identity & Multi-Tenancy

#### `users` (`User`)
*Global user account identity across the platform.*
- `id` (`String`, PK, UUID): Unique global user identifier.
- `email` (`String`, Unique): Login email address.
- `phone` (`String?`, Unique): Optional 10-digit mobile number.
- `passwordHash` (`String`): Bcrypt/Argon2 hashed password.
- `fullName` (`String`): User's legal full name.
- `avatarUrl` (`String?`): Profile image storage URL.
- `isActive` (`Boolean`, Default: `true`): Account active status.
- `createdAt` (`DateTime`): Account creation timestamp.
- `updatedAt` (`DateTime`): Last profile modification.

#### `businesses` (`Business`)
*The tenant boundary representing the legal operating organization.*
- `id` (`String`, PK, UUID): Tenant identifier (`businessId`).
- `name` (`String`): Trade/display name.
- `legalName` (`String?`): Official registered company name.
- `gstin` (`String?`): 15-character Indian Goods & Services Tax Identification Number.
- `pan` (`String?`): 10-character Indian Permanent Account Number.
- `phone` (`String?`): Primary business contact phone.
- `email` (`String?`): Primary business contact email.
- `addressLine1` (`String?`): Building, street, or landmark.
- `addressLine2` (`String?`): Area or sub-district.
- `city` (`String?`): City or municipality.
- `state` (`String?`): State or province name.
- `stateCode` (`String?`): 2-digit Indian GST State Code (e.g., `"07"` for Delhi).
- `pincode` (`String?`): Postal code.
- `currency` (`String`, Default: `"INR"`): Operating currency.
- `taxType` (`TaxType`, Default: `REGULAR`): Business tax registration status.
- `createdAt` (`DateTime`): Registration timestamp.
- `updatedAt` (`DateTime`): Last business update.

#### `business_settings` (`BusinessSettings`)
*Tenant-level operational configuration and feature toggles.*
- `id` (`String`, PK, UUID): Settings record identifier.
- `businessId` (`String`, Unique, FK -> `businesses.id`): Associated tenant.
- `trackInventory` (`Boolean`, Default: `true`): Global inventory toggle.
- `allowNegativeStock` (`Boolean`, Default: `false`): Strict stockout prevention toggle.
- `defaultBillFormat` (`BillFormat`, Default: `A4_STANDARD`): Default print layout.
- `enableGst` (`Boolean`, Default: `true`): GST engine activation status.
- `defaultGstRate` (`Decimal(5, 2)`, Default: `18.00`): Standard default rate.
- `financialYearStart` (`DateTime`): Active fiscal year beginning (e.g., April 1).
- `updatedAt` (`DateTime`): Last settings update.

#### `document_sequences` (`DocumentSequence`)
*Pessimistically locked sequence allocator for gapless/unique document numbering.*
- `id` (`String`, PK, UUID): Sequence record identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `documentType` (`String`): Document category (`INVOICE`, `PURCHASE`, `PAYMENT`, `EXPENSE`).
- `prefix` (`String`): Configured prefix (e.g., `"INV-2026-"`).
- `nextNumber` (`Int`, Default: `1`): Atomic incrementing integer counter.
- `fiscalYear` (`String`): Applicable fiscal cycle (e.g., `"2026-2027"`).
- `updatedAt` (`DateTime`): Last allocated timestamp.

#### `branches` (`Branch`)
*Physical retail stores, outlets, or operational branch offices.*
- `id` (`String`, PK, UUID): Branch identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `name` (`String`): Branch location name.
- `code` (`String?`): Short branch identifier code.
- `address` (`String?`): Physical address.
- `stateCode` (`String?`): Branch GST state code.
- `isMain` (`Boolean`, Default: `false`): Primary operating headquarters flag.
- `isActive` (`Boolean`, Default: `true`): Branch active status.
- `createdAt` (`DateTime`): Creation timestamp.
- `updatedAt` (`DateTime`): Last update timestamp.

#### `roles` (`Role`)
*Role-Based Access Control definitions (System Defaults & Custom Tenant Roles).*
- `id` (`String`, PK, UUID): Role identifier.
- `businessId` (`String?`, Nullable, FK -> `businesses.id`): `NULL` for global shared system roles; UUID for tenant-custom roles.
- `name` (`String`): Role name (e.g., `"OWNER"`, `"ADMIN"`, `"MANAGER"`, `"CASHIER"`, `"ACCOUNTANT"`).
- `description` (`String?`): Plain-language role scope explanation.
- `isSystem` (`Boolean`, Default: `false`): Flag identifying immutable global roles.
- `permissions` (`Json`): Array of granted permission strings.
- `createdAt` (`DateTime`): Creation timestamp.

#### `business_users` (`BusinessUser`)
*Junction assigning a User to a Business with a specific Role and Branch.*
- `id` (`String`, PK, UUID): Membership identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `userId` (`String`, FK -> `users.id`): Member identity.
- `roleId` (`String`, FK -> `roles.id`): Granted role.
- `defaultBranchId` (`String?`, FK -> `branches.id`): Assigned operating location.
- `isActive` (`Boolean`, Default: `true`): Active membership status.
- `createdAt` (`DateTime`): Join timestamp.
- `updatedAt` (`DateTime`): Last role/branch reassignment.

---

### 2. Master Data Layer

#### `customers` (`Customer`)
*Customer master directory for receivables, credit management, and GST.*
- `id` (`String`, PK, UUID): Customer identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `name` (`String`): Contact or enterprise trade name.
- `phone` (`String?`, Indexed): Contact mobile number.
- `email` (`String?`): Contact email address.
- `gstin` (`String?`): 15-character GSTIN.
- `billingAddress` (`String?`): Registered billing location.
- `shippingAddress` (`String?`): Delivery destination.
- `city` (`String?`): City name.
- `state` (`String?`): State name.
- `stateCode` (`String?`): 2-digit GST state code (critical for Place of Supply).
- `pincode` (`String?`): Area postal code.
- `openingBalance` (`Decimal(12, 2)`, Default: `0.00`): Initial balance carried forward.
- `currentBalance` (`Decimal(12, 2)`, Default: `0.00`): Live receivable balance (Positive = Customer owes us).
- `creditLimit` (`Decimal(12, 2)?`): Maximum permitted credit balance.
- `creditPeriodDays` (`Int`, Default: `0`): Credit grace period in days.
- `status` (`String`, Default: `"ACTIVE"`): Operational state (`ACTIVE` / `ARCHIVED`).
- `createdAt` (`DateTime`): Creation timestamp.
- `updatedAt` (`DateTime`): Last profile modification.

#### `suppliers` (`Supplier`)
*Vendor master directory for purchases, payables, and Input Tax Credit (ITC).*
- `id` (`String`, PK, UUID): Supplier identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `name` (`String`): Vendor trade name.
- `phone` (`String?`): Vendor contact number.
- `email` (`String?`): Vendor email address.
- `gstin` (`String?`): Vendor GSTIN.
- `pan` (`String?`): Vendor PAN.
- `address` (`String?`): Physical office address.
- `city` (`String?`): City name.
- `state` (`String?`): State name.
- `stateCode` (`String?`): 2-digit GST state code.
- `bankName` (`String?`): Payee bank name.
- `accountNumber` (`String?`): Payee bank account number.
- `ifscCode` (`String?`): Payee bank IFSC routing code.
- `openingBalance` (`Decimal(12, 2)`, Default: `0.00`): Opening payable balance.
- `currentBalance` (`Decimal(12, 2)`, Default: `0.00`): Live payable balance (Positive = We owe supplier).
- `status` (`String`, Default: `"ACTIVE"`): Operational state.
- `createdAt` (`DateTime`): Creation timestamp.
- `updatedAt` (`DateTime`): Last profile modification.

#### `categories` (`Category`) & `units` (`Unit`)
- **`categories`:** `id`, `businessId`, `name`, `parentId` (Nullable self-relation).
- **`units`:** `id`, `businessId`, `name` (e.g. "Piece", "Kilogram"), `symbol` (e.g. "PCS", "KG").

#### `products` (`Product`)
*Master inventory and service catalog repository.*
- `id` (`String`, PK, UUID): Product identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `categoryId` (`String?`, FK -> `categories.id`): Item classification.
- `unitId` (`String?`, FK -> `units.id`): Standard measurement unit.
- `name` (`String`, Indexed): Product/service title.
- `sku` (`String?`, Indexed): Stock Keeping Unit code.
- `barcode` (`String?`, Indexed): Scannable barcode string (EAN/UPC).
- `description` (`String?`): Extended item description.
- `hsnCode` (`String?`): Indian HSN (Goods) or SAC (Services) tax code.
- `itemType` (`ItemType`, Default: `GOODS`): `GOODS` or `SERVICE`.
- `trackStock` (`Boolean`, Default: `true`): Item-level stock tracking toggle (always `false` for services).
- `gstRate` (`Decimal(5, 2)`, Default: `0.00`): GST tax bracket percentage (0, 5, 12, 18, 28).
- `cessRate` (`Decimal(5, 2)`, Default: `0.00`): Additional cess percentage.
- `purchasePrice` (`Decimal(12, 2)`, Default: `0.00`): Default inward purchase rate.
- `salePrice` (`Decimal(12, 2)`, Default: `0.00`): Standard selling rate.
- `mrp` (`Decimal(12, 2)?`): Maximum Retail Price.
- `minStockLevel` (`Decimal(12, 2)`, Default: `0.00`): Low stock alert threshold.
- `currentStock` (`Decimal(12, 2)`, Default: `0.00`): Cached aggregate physical stock count.
- `status` (`String`, Default: `"ACTIVE"`): Item state (`ACTIVE` / `INACTIVE`).
- `createdAt` (`DateTime`): Creation timestamp.
- `updatedAt` (`DateTime`): Last modification timestamp.

#### `product_variants` (`ProductVariant`)
*Attributes extending base catalog items (e.g. Size, Color, Pack).*
- `id` (`String`, PK, UUID): Variant identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `productId` (`String`, FK -> `products.id`): Base product reference.
- `name` (`String`): Variant specification name (e.g., "500ml", "Size XL").
- `sku` (`String?`): Variant specific SKU.
- `barcode` (`String?`): Variant specific barcode.
- `salePrice` (`Decimal(12, 2)`): Selling price override.
- `purchasePrice` (`Decimal(12, 2)`): Cost price override.
- `createdAt` (`DateTime`): Creation timestamp.

---

### 3. Inventory & Warehouses Layer

#### `warehouses` (`Warehouse`)
*Designated physical storage space, godown, or store shelf.*
- `id` (`String`, PK, UUID): Warehouse identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `branchId` (`String?`, FK -> `branches.id`): Associated operational branch.
- `name` (`String`): Storage facility name.
- `address` (`String?`): Physical address.
- `isDefault` (`Boolean`, Default: `false`): Primary dispatch warehouse flag.
- `createdAt` (`DateTime`): Creation timestamp.

#### `stocks` (`Stock`)
*Physical on-hand quantity balances per warehouse, product, and variant.*
- `id` (`String`, PK, UUID): Stock record identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `warehouseId` (`String`, FK -> `warehouses.id`): Storage location.
- `productId` (`String`, FK -> `products.id`): Inventoried product.
- `variantId` (`String?`, FK -> `product_variants.id`): Optional variant specifier.
- `quantityOnHand` (`Decimal(12, 2)`, Default: `0.00`): Physical stock count.
- `updatedAt` (`DateTime`): Last balance modification.

#### `stock_movements` (`StockMovement`)
*Immutable chronological ledger of all physical stock movements.*
- `id` (`String`, PK, UUID): Movement entry identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `warehouseId` (`String`, FK -> `warehouses.id`): Storage location.
- `productId` (`String`, FK -> `products.id`): Moved catalog item.
- `variantId` (`String?`): Optional variant identifier.
- `movementType` (`StockMovementType`): Transaction nature (`PURCHASE`, `SALE`, `SALE_RETURN`, `PURCHASE_RETURN`, `ADJUSTMENT_ADD`, `ADJUSTMENT_SUB`, `DAMAGE`, `TRANSFER`).
- `quantity` (`Decimal(12, 2)`): Positive scalar quantity moved.
- `unitCost` (`Decimal(12, 2)`): Valuation cost per unit at time of movement.
- `referenceType` (`String?`): Originating document type (`"INVOICE"`, `"PURCHASE"`, `"ADJUSTMENT"`).
- `referenceId` (`String?`): Originating document identifier.
- `notes` (`String?`): Audit explanation.
- `createdAt` (`DateTime`): Timestamp of movement.

---

### 4. Commercial Transactions Layer

#### `invoices` (`Invoice`)
*The central legal tax invoice and customer receivable document.*
- `id` (`String`, PK, UUID): Invoice identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `branchId` (`String`, FK -> `branches.id`): Issuing branch location.
- `customerId` (`String?`, FK -> `customers.id`): Billed customer (nullable for quick walk-in cash sales).
- `invoiceNumber` (`String`, Unique per tenant): Sequential billing number (e.g., `"INV-2026-0001"`).
- `invoiceDate` (`DateTime`): Legal tax invoice issue date.
- `dueDate` (`DateTime?`): Payment deadline.
- `status` (`InvoiceStatus`, Default: `ISSUED`): Commercial status (`DRAFT`, `ISSUED`, `PARTIALLY_PAID`, `PAID`, `CANCELLED`).
- `billFormat` (`BillFormat`, Default: `A4_STANDARD`): Selected print/render layout.
- `placeOfSupply` (`String`): 2-digit Indian GST State Code (determines CGST+SGST vs IGST).
- `isInterState` (`Boolean`): `true` if business state != place of supply.
- `isReverseCharge` (`Boolean`, Default: `false`): GST Reverse Charge Mechanism (RCM) flag.
- `subtotal` (`Decimal(12, 2)`): Gross sum of all item taxable values.
- `discountType` (`String?`): Global discount mode (`"PERCENT"` or `"FIXED"`).
- `discountAmount` (`Decimal(12, 2)`, Default: `0.00`): Total discount deduction.
- `taxableAmount` (`Decimal(12, 2)`): Net taxable assessment value.
- `cgstAmount` (`Decimal(12, 2)`, Default: `0.00`): Central GST total.
- `sgstAmount` (`Decimal(12, 2)`, Default: `0.00`): State GST total.
- `igstAmount` (`Decimal(12, 2)`, Default: `0.00`): Integrated (interstate) GST total.
- `cessAmount` (`Decimal(12, 2)`, Default: `0.00`): Ad-valorem/specific cess total.
- `roundOff` (`Decimal(5, 2)`, Default: `0.00`): Rounding adjustment fraction.
- `totalAmount` (`Decimal(12, 2)`): Final invoice payable amount.
- `receivedAmount` (`Decimal(12, 2)`, Default: `0.00`): Total collected funds against invoice.
- `balanceAmount` (`Decimal(12, 2)`): Outstanding balance remaining (`totalAmount - receivedAmount`).
- `notes` (`String?`): Public notes displayed on bill.
- `terms` (`String?`): Legal terms and conditions.
- `cancelledAt` (`DateTime?`): Cancellation timestamp.
- `cancellationReason` (`String?`): Reason for voiding document.
- `clientOperationId` (`String?`, Unique non-null per tenant): Offline client idempotency token.
- `syncStatus` (`SyncStatus`, Default: `SYNCED`): Synchronization state.
- `version` (`Int`, Default: `1`): Optimistic concurrency lock counter.
- `createdAt` (`DateTime`): Record creation timestamp.
- `updatedAt` (`DateTime`): Last record modification.

#### `invoice_items` (`InvoiceItem`)
*Itemized billing line containing pricing, quantity, and tax splits.*
- `id` (`String`, PK, UUID): Line item identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `invoiceId` (`String`, FK -> `invoices.id` ON DELETE CASCADE): Parent invoice.
- `productId` (`String?`, FK -> `products.id` ON DELETE RESTRICT): Catalog item reference (Nullable for custom lines / non-stock services).
- `variantId` (`String?`): Optional variant specifier.
- `description` (`String`): Display name or custom description.
- `hsnCode` (`String?`): Applicable 4/6/8-digit HSN/SAC code.
- `quantity` (`Decimal(12, 2)`): Billed quantity.
- `unitPrice` (`Decimal(12, 2)`): Base selling price per unit.
- `discountAmount` (`Decimal(12, 2)`, Default: `0.00`): Line-level discount.
- `taxableAmount` (`Decimal(12, 2)`): Line net taxable base (`quantity * unitPrice - discountAmount`).
- `gstRate` (`Decimal(5, 2)`): Applicable GST percentage.
- `cgstAmount` (`Decimal(12, 2)`, Default: `0.00`): CGST component.
- `sgstAmount` (`Decimal(12, 2)`, Default: `0.00`): SGST component.
- `igstAmount` (`Decimal(12, 2)`, Default: `0.00`): IGST component.
- `cessAmount` (`Decimal(12, 2)`, Default: `0.00`): Cess component.
- `totalAmount` (`Decimal(12, 2)`): Line gross total (`taxableAmount + taxes`).

#### `purchases` (`Purchase`) & `purchase_items` (`PurchaseItem`)
*Inward vendor bills for inventory receipt, accounts payable, and Input Tax Credit (ITC).*
- **`purchases`:** `id`, `businessId`, `branchId`, `supplierId`, `billNumber`, `billDate`, `status`, `subtotal`, `taxAmount`, `totalAmount`, `paidAmount`, `balanceAmount`, `paymentStatus`, `clientOperationId?`.
- **`purchase_items`:** `id`, `businessId`, `purchaseId`, `productId`, `description`, `hsnCode`, `quantity`, `unitCost`, `taxRate`, `taxAmount`, `totalAmount`.

#### `quotations` (`Quotation`) & `sales_orders` (`SalesOrder`)
*Pre-sale commercial documents converting into invoices without moving stock.*
- **`quotations` / `quotation_items`:** Estimates and quotes with expiration dates.
- **`sales_orders` / `sales_order_items`:** Confirmed buyer orders pending dispatch.

---

### 5. Settlements & Double-Entry Accounting

#### `payments` (`Payment`)
*Monetary settlement transaction (Inward Customer Receipt or Outward Supplier Payment).*
- `id` (`String`, PK, UUID): Payment voucher identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `paymentNumber` (`String`, Unique per tenant): Document identifier (e.g., `"PAY-2026-0001"`).
- `paymentType` (`PaymentType`): `CUSTOMER_RECEIPT` or `SUPPLIER_PAYMENT`.
- `customerId` (`String?`, FK -> `customers.id`): Payer customer (mandatory for customer receipts).
- `supplierId` (`String?`, FK -> `suppliers.id`): Payee supplier (mandatory for supplier payments).
- `paymentDate` (`DateTime`): Transaction date.
- `amount` (`Decimal(12, 2)`): Total monetary value transferred.
- `paymentMethod` (`PaymentMethod`): `CASH`, `UPI`, `BANK_TRANSFER`, `CHEQUE`, or `CARD`.
- `referenceNumber` (`String?`): Bank reference number, UPI UTR, or Cheque number.
- `notes` (`String?`): Transaction narration.
- `clientOperationId` (`String?`): Offline client idempotency token.
- `syncStatus` (`SyncStatus`, Default: `SYNCED`): Synchronization state.
- `createdAt` (`DateTime`): Creation timestamp.

#### `payment_allocations` (`PaymentAllocation`)
*Settlement bridge mapping a single payment across specific invoices or purchase bills.*
- `id` (`String`, PK, UUID): Allocation identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `paymentId` (`String`, FK -> `payments.id` ON DELETE CASCADE): Originating payment.
- `invoiceId` (`String?`, FK -> `invoices.id` ON DELETE RESTRICT): Settled sales invoice.
- `purchaseId` (`String?`, FK -> `purchases.id` ON DELETE RESTRICT): Settled purchase bill.
- `amount` (`Decimal(12, 2)`): Allocated fraction of payment.
- `createdAt` (`DateTime`): Allocation timestamp.

#### `expenses` (`Expense`) & `expense_categories` (`ExpenseCategory`)
*Operating expenditure records for profit and loss accounting.*
- **`expense_categories`:** `id`, `businessId`, `name` (e.g. "Rent", "Electricity", "Wages", "Marketing").
- **`expenses`:** `id`, `businessId`, `branchId?`, `categoryId`, `expenseNumber`, `date`, `amount`, `paymentMethod`, `vendor`, `gstin`, `gstAmount`, `isTaxDeductible`, `receiptUrl`, `notes`, `createdAt`.

#### `accounts` (`Account`)
*Standard Chart of Accounts (COA) holding continuous real-time ledger balances.*
- `id` (`String`, PK, UUID): Account identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `code` (`String`): Account code (e.g., `"1010"` for Cash, `"1020"` for Bank, `"1030"` for AR).
- `name` (`String`): Account title (e.g., `"Cash on Hand"`, `"Accounts Receivable"`).
- `type` (`AccountType`): `ASSET`, `LIABILITY`, `EQUITY`, `REVENUE`, or `EXPENSE`.
- `balance` (`Decimal(14, 2)`, Default: `0.00`): Live account balance.
- `createdAt` (`DateTime`): Creation timestamp.

#### `journal_entries` (`JournalEntry`)
*Double-entry transaction header grouping balanced debit and credit legs.*
- `id` (`String`, PK, UUID): Journal voucher identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `entryNumber` (`String`, Unique per tenant): Sequential journal voucher number.
- `date` (`DateTime`): Effective posting date.
- `narration` (`String`): Description of transaction cause.
- `referenceType` (`String?`): Commercial link (`"INVOICE"`, `"PAYMENT"`, `"PURCHASE"`, `"EXPENSE"`).
- `referenceId` (`String?`): Commercial document identifier.
- `createdAt` (`DateTime`): Posting timestamp.

#### `ledger_entries` (`LedgerEntry`)
*Individual debit or credit posting leg.*
- `id` (`String`, PK, UUID): Entry line identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `journalEntryId` (`String`, FK -> `journal_entries.id` ON DELETE CASCADE): Parent journal header.
- `accountId` (`String`, FK -> `accounts.id` ON DELETE RESTRICT): Target Chart of Account.
- `debit` (`Decimal(12, 2)`, Default: `0.00`): Debit amount.
- `credit` (`Decimal(12, 2)`, Default: `0.00`): Credit amount.

#### `gst_records` (`GstRecord`)
*Dedicated tax transaction repository indexed for instant GSTR-1 & GSTR-3B generation.*
- `id` (`String`, PK, UUID): Record identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `returnPeriod` (`String`, Indexed): Return month (Format `"YYYY-MM"`, e.g., `"2026-10"`).
- `transactionType` (`String`): Supply direction (`"SALE"` or `"PURCHASE"`).
- `invoiceId` (`String?`, FK -> `invoices.id` ON DELETE RESTRICT): Sales invoice link.
- `purchaseId` (`String?`, FK -> `purchases.id` ON DELETE RESTRICT): Purchase bill link.
- `gstin` (`String?`): Customer or supplier GSTIN.
- `placeOfSupply` (`String`): 2-digit Indian State code.
- `taxableValue` (`Decimal(12, 2)`): Net taxable assessment value.
- `cgstAmount` (`Decimal(12, 2)`, Default: `0.00`): Central tax.
- `sgstAmount` (`Decimal(12, 2)`, Default: `0.00`): State tax.
- `igstAmount` (`Decimal(12, 2)`, Default: `0.00`): Integrated tax.
- `cessAmount` (`Decimal(12, 2)`, Default: `0.00`): Cess.
- `hsnSummary` (`Json?`): Array of HSN totals `{ hsn, qty, taxable, tax }`.
- `isCancelled` (`Boolean`, Default: `false`): Cancellation flag.
- `createdAt` (`DateTime`): Record creation timestamp.

---

### 6. Audit & Synchronization Infrastructure

#### `audit_logs` (`AuditLog`)
*Immutable security and operational event trail.*
- `id` (`String`, PK, UUID): Audit entry identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `userId` (`String?`, FK -> `users.id`): Operating user identity.
- `action` (`String`): Action code (e.g., `"INVOICE_CREATE"`, `"INVOICE_CANCEL"`, `"STOCK_ADJUST"`).
- `entityName` (`String`): Modified entity (`"Invoice"`, `"Product"`, `"Customer"`).
- `entityId` (`String`): Target record identifier.
- `oldValues` (`Json?`): Prior state snapshot.
- `newValues` (`Json?`): Post-mutation state snapshot.
- `ipAddress` (`String?`): Client IP address.
- `userAgent` (`String?`): Client platform user agent.
- `timestamp` (`DateTime`): Exact UTC event timestamp.

#### `sync_queues` (`SyncQueue`)
*Server-side offline sync operation queue and idempotency registrar.*
- `id` (`String`, PK, UUID): Queue entry identifier.
- `businessId` (`String`, FK -> `businesses.id`): Associated tenant.
- `clientOperationId` (`String`, Unique per tenant): Client UUID token.
- `entityType` (`String`): Entity classification.
- `entityId` (`String`): Target entity identifier.
- `operation` (`String`): Operation mode (`"INSERT"`, `"UPDATE"`, `"DELETE"`).
- `payload` (`Json`): Full serialized payload.
- `status` (`String`, Default: `"PENDING"`): State (`PENDING`, `PROCESSED`, `FAILED`, `CONFLICT`).
- `processedAt` (`DateTime?`): Processing timestamp.
- `errorMessage` (`String?`): Error narration on rejection.
- `createdAt` (`DateTime`): Creation timestamp.

---

### 7. Future Scope Entities (Minimal Placeholders)

- **`plans` (`Plan`):** `id`, `name`, `maxUsers`, `maxInvoicesMonthly`, `priceMonthly`.
- **`subscriptions` (`Subscription`):** `id`, `businessId`, `planId`, `status`, `validUntil`.
- **`ai_conversations` (`AiConversation`):** `id`, `businessId`, `userId`, `title`.
- **`ai_query_logs` (`AiQueryLog`):** `id`, `businessId`, `userId`, `conversationId`, `prompt`, `response`, `tokenCount`, `latencyMs`.
- Minimal future-proofed models strictly preventing schema redesign in Phases 15–23.
