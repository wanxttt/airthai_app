# AirthAI Inventory Valuation & Accounting Architecture

## 1. Regulatory Context & Accounting Standards

AirthAI's inventory engine adheres to **Indian Accounting Standard (Ind AS) 2** and **Accounting Standard (AS) 2: Valuation of Inventories**. 

### Standard Requirements
1. **Lower of Cost and Net Realizable Value (NRV):** Inventories must be valued at cost or net realizable value, whichever is lower.
2. **Permitted Cost Formulas:**
   - **Weighted Average Cost (WAC)** (Recommended & default in AirthAI).
   - **First-In, First-Out (FIFO)**.
   - *Last-In, First-Out (LIFO) is strictly prohibited under Indian GAAP and Ind AS 2.*

---

## 2. Inventory Valuation Methodology: Weighted Average Cost (WAC)

AirthAI calculates unit inventory cost and aggregate stock valuation using the **Periodic / Moving Weighted Average Cost** model.

### 2.1 Formula

$$\text{Weighted Average Unit Cost} = \frac{\sum_{i=1}^{n} (\text{Purchased Quantity}_i \times \text{Unit Purchase Price}_i)}{\sum_{i=1}^{n} \text{Purchased Quantity}_i}$$

Where:
- $\text{Purchased Quantity}_i$ is the quantity received under purchase bill $i$.
- $\text{Unit Purchase Price}_i$ is the landed unit cost (exclusive of recoverable input tax credit such as CGST/SGST/IGST).
- If no historical purchase transactions exist for a catalog item, the engine falls back to the configured baseline catalog `purchasePrice` on the `Product` entity.

### 2.2 Total Inventory Valuation

$$\text{Total Valuation} = \sum_{p \in \text{Products}} \left( \text{Current Stock Quantity}_p \times \text{Unit Cost}_p \right)$$

Only active catalog items with `trackStock = true` and `currentStock > 0` are evaluated in the balance sheet valuation.

---

## 3. Financial Exactness & Floating-Point Protection

AUTHORITATIVE VALUATIONS AND TOTALS ARE EXCLUSIVELY CALCULATED BY THE BACKEND SERVER.

- **Storage Type:** PostgreSQL `DECIMAL(14, 2)` or `DECIMAL(12, 3)` mapped to Prisma's `Prisma.Decimal`.
- **Runtime Calculations:** Implemented using exact arbitrary-precision arithmetic (`decimal.js` via Prisma). Binary IEEE-754 floating-point arithmetic (`number` in JavaScript/Dart) is prohibited for financial ledgers.
- **Rounding Convention:** Half-up rounding (`ROUND_HALF_UP`) to two decimal places for currency, and three decimal places for fractional measurement units (e.g., kg, meters).

---

## 4. Traceable Stock Movement Audit Trail

AirthAI enforces an absolute invariant: **No inventory balance may change without a traceable `StockMovement` entry.**

### 4.1 Movement Types & Directions

| Movement Type | Direction | Sign | Triggering Transaction |
|---|---|---|---|
| `PURCHASE` | Inbound | `+` | Confirmed supplier purchase bill (`RECEIVED` or `receive()`) |
| `SALE` | Outbound | `-` | Issued tax invoice (`ISSUED`) |
| `PURCHASE_RETURN` | Outbound | `-` | Purchase bill cancellation (`cancel()`) |
| `SALE_RETURN` | Inbound | `+` | Invoice cancellation (`cancel()`) / Credit note |
| `ADJUSTMENT_ADD` | Inbound | `+` | Stock reconciliation surplus / Physical count adjustment |
| `ADJUSTMENT_SUB` | Outbound | `-` | Stock reconciliation shortage / Audit write-off |
| `DAMAGE` | Outbound | `-` | Damaged, expired, or spoiled goods write-off |
| `TRANSFER` | Relocation | `0` | Inter-warehouse stock transfer |

### 4.2 Audit Properties Logged
Each movement record contains:
- `businessId`: Tenant isolation key.
- `productId`: Targeted product entity.
- `warehouseId`: Warehouse facility storing the stock.
- `movementType`: Specific enum indicating business nature.
- `quantity`: Exact units moved.
- `unitCost`: Cost rate at the time of movement.
- `referenceType`: System source (e.g. `PURCHASE`, `INVOICE`, `MANUAL_ADJUSTMENT`).
- `referenceId`: Transaction document identifier (e.g., purchase ID, invoice ID).
- `notes`: Justification or audit remarks.
- `createdAt`: Immutable timestamp.

---

## 5. Negative Stock Guard & Concurrency Safety

### 5.1 Business Setting Guard
AirthAI supports an explicit tenant-level setting: `BusinessSettings.allowNegativeStock` (default: `false`).
- When `allowNegativeStock = false`: Any outbound stock movement (`SALE`, `ADJUSTMENT_SUB`, `DAMAGE`) that would reduce `quantityOnHand` below `0.0` is aborted with an unprocessable entity error (`422 Unprocessable Entity` or `400 Bad Request`).
- When `allowNegativeStock = true`: Allowed for high-velocity FMCG or retail counters where billing precedes back-office goods receipt, with prominent warning indicators.

### 5.2 Atomic Database Transactions
All stock adjustments and purchase receipts execute inside `prisma.$transaction(...)`:
1. Check supplier and product tenant ownership (`businessId`).
2. Read current stock with row locking where applicable.
3. Validate negative stock limits.
4. Insert `StockMovement` audit record.
5. Upsert `Stock` balance record.
6. Commit or rollback atomically.

---

## 6. Multi-Warehouse Scope in Approved MVP

The schema defines a `Warehouse` entity per business:
- Each business tenant creates a default warehouse (`"Main Warehouse"`) upon tenant onboarding.
- All purchases, sales, and stock adjustments associate with the business's active warehouse.
- Multi-location expansion is prepared without requiring database migration or breaking changes.
