# AirthAI API Documentation — Purchases & Inventory Engine

## Module Overview

The `PurchasesInventoryModule` manages supplier purchase bills, product inventory levels, multi-warehouse stock balances, authorized inventory adjustments, and traceable movement audit trails.

Base URL prefix: `/api/v1`  
Authentication: Bearer JWT (`Authorization: Bearer <accessToken>`) with active tenant context (`BusinessGuard`, `TenantGuard`, `RolesGuard`).

---

## 1. Purchases Endpoints

### 1.1 List Purchases
`GET /api/v1/purchases`

#### Query Parameters
- `page` (number, optional, default: 1): Page index.
- `limit` (number, optional, default: 20): Items per page.
- `search` (string, optional): Search by bill number or supplier name.
- `supplierId` (UUID, optional): Filter by supplier.
- `status` (string, optional): Filter by `ORDERED`, `RECEIVED`, or `CANCELLED`.
- `startDate` (ISO8601 string, optional): Filter by minimum bill date.
- `endDate` (ISO8601 string, optional): Filter by maximum bill date.

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Purchases retrieved successfully",
  "data": [
    {
      "id": "c8b417e2-45e3-4c99-b1d7-27b38cb7d4f1",
      "billNumber": "BILL-2026-001",
      "billDate": "2026-03-15T00:00:00.000Z",
      "status": "RECEIVED",
      "supplierId": "e2f18392-4f3b-419b-a0f1-0db3d08f7aa2",
      "supplierName": "Tata Steel Distribution",
      "supplierGstin": "27AAACT2345C1Z8",
      "subtotal": 50000.0,
      "taxAmount": 9000.0,
      "totalAmount": 59000.0,
      "paidAmount": 0.0,
      "balanceAmount": 59000.0,
      "paymentStatus": "UNPAID",
      "items": [
        {
          "id": "item_1",
          "productId": "p_001",
          "description": "Safety Helmets",
          "quantity": 100,
          "unitCost": 280.0,
          "taxRate": 18.0,
          "taxAmount": 5040.0,
          "totalAmount": 33040.0
        }
      ]
    }
  ],
  "meta": {
    "total": 1,
    "page": 1,
    "limit": 20,
    "totalPages": 1
  }
}
```

---

### 1.2 Get Purchase by ID
`GET /api/v1/purchases/:id`

#### Response `200 OK`
Returns the complete purchase record, line items, associated supplier details, and warehouse context.

---

### 1.3 Create Purchase Bill
`POST /api/v1/purchases`

#### Idempotency & Safety
- **Idempotency Key:** Optional `clientOperationId` (UUID). Re-submitting the same key returns the existing purchase record without duplicate processing.
- **Duplicate Bill Guard:** Enforces unique `(businessId, supplierId, billNumber)`. Re-using an existing bill number for the same supplier returns `409 Conflict`.
- **Atomic Operations:** Line items creation, stock increments, movement tracking, payable balance increment, and GST input records are atomically committed.

#### Request Body
```json
{
  "supplierId": "e2f18392-4f3b-419b-a0f1-0db3d08f7aa2",
  "billNumber": "INV-2026-902",
  "billDate": "2026-03-20T10:00:00.000Z",
  "dueDate": "2026-04-19T00:00:00.000Z",
  "status": "RECEIVED",
  "notes": "Delivered to Main Warehouse via Lorry Receipt #889",
  "clientOperationId": "550e8400-e29b-41d4-a716-446655440000",
  "items": [
    {
      "productId": "7488f219-543e-4b9b-9801-7faec3137912",
      "description": "Industrial Power Drill 750W",
      "hsnCode": "8467",
      "quantity": 10,
      "unitCost": 2200.0,
      "taxRate": 18.0
    }
  ]
}
```

#### Response `201 Created`
```json
{
  "statusCode": 201,
  "message": "Purchase bill created successfully",
  "data": {
    "id": "c8b417e2-45e3-4c99-b1d7-27b38cb7d4f1",
    "billNumber": "INV-2026-902",
    "status": "RECEIVED",
    "totalAmount": 25960.0,
    "balanceAmount": 25960.0
  }
}
```

---

### 1.4 Receive Ordered Purchase
`PATCH /api/v1/purchases/:id/receive`

Transitions a draft purchase order (`ORDERED`) to confirmed stock receipt (`RECEIVED`):
1. Verifies current purchase status is `ORDERED`.
2. Creates inbound `StockMovement` records (`type = PURCHASE`).
3. Updates warehouse `Stock` table (`quantityOnHand += quantity`).
4. Increments supplier `currentBalance` (accounts payable).
5. Sets purchase status to `RECEIVED`.

#### Response `200 OK`
Returns the updated purchase record.

---

### 1.5 Cancel Purchase Bill
`PATCH /api/v1/purchases/:id/cancel`

Cancels a purchase bill and safely reverses all accounting and inventory effects:
1. Verifies purchase is not already cancelled (`status != CANCELLED`).
2. If goods were received (`RECEIVED`), checks if deducting stock will violate negative stock policy (`allowNegativeStock`).
3. Creates outbound reversal `StockMovement` records (`type = PURCHASE_RETURN`).
4. Decrements warehouse `Stock` table (`quantityOnHand -= quantity`).
5. Decrements supplier `currentBalance` (reverses accounts payable).
6. Sets purchase status to `CANCELLED` and zeroes `balanceAmount`.
7. Records audit log entry with cancellation reason.

#### Request Body
```json
{
  "reason": "Supplier recalled defective goods"
}
```

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Purchase bill cancelled and inventory reversed",
  "data": {
    "id": "c8b417e2-45e3-4c99-b1d7-27b38cb7d4f1",
    "status": "CANCELLED",
    "balanceAmount": 0.0
  }
}
```

---

## 2. Inventory Endpoints

### 2.1 Get Inventory Summary & Valuation
`GET /api/v1/inventory/summary`

Returns aggregated stock metrics and total balance sheet valuation computed via Weighted Average Cost (WAC).

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Inventory summary retrieved successfully",
  "data": {
    "totalProducts": 142,
    "totalStockQuantity": 3850.0,
    "lowStockCount": 8,
    "outOfStockCount": 3,
    "totalValuation": 1245800.0,
    "valuationMethod": "WEIGHTED_AVERAGE_COST"
  }
}
```

---

### 2.2 Get Products Inventory List
`GET /api/v1/inventory/products`

#### Query Parameters
- `page` (number, default: 1): Page index.
- `limit` (number, default: 50): Items per page.
- `search` (string, optional): Search by name, SKU, or barcode.
- `categoryId` (UUID, optional): Filter by category.
- `stockStatus` (string, optional): Filter by `IN_STOCK`, `LOW_STOCK`, `OUT_OF_STOCK`, or `ALL`.

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Inventory products retrieved successfully",
  "data": [
    {
      "id": "7488f219-543e-4b9b-9801-7faec3137912",
      "name": "Heavy-Duty Power Drill 750W",
      "sku": "DRL-750",
      "barcode": "8901234567890",
      "categoryName": "Power Tools",
      "unitSymbol": "pcs",
      "trackStock": true,
      "minStockLevel": 5.0,
      "currentStock": 12.0,
      "stockStatus": "IN_STOCK",
      "unitCost": 2200.0,
      "valuation": 26400.0
    }
  ],
  "meta": {
    "total": 1,
    "page": 1,
    "limit": 50,
    "totalPages": 1
  }
}
```

---

### 2.3 Get Product Stock Movement Audit History
`GET /api/v1/inventory/products/:id/movements`

Returns the chronological ledger of all physical inventory changes for a specific item.

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Stock movements retrieved successfully",
  "data": {
    "productId": "7488f219-543e-4b9b-9801-7faec3137912",
    "productName": "Heavy-Duty Power Drill 750W",
    "currentStock": 12.0,
    "movements": [
      {
        "id": "mov_1",
        "movementType": "PURCHASE",
        "quantity": 10.0,
        "unitCost": 2200.0,
        "referenceType": "PURCHASE",
        "referenceId": "c8b417e2-45e3-4c99-b1d7-27b38cb7d4f1",
        "notes": "Supplier bill INV-2026-902 received",
        "warehouseName": "Main Warehouse",
        "createdAt": "2026-03-20T10:15:00.000Z"
      },
      {
        "id": "mov_2",
        "movementType": "SALE",
        "quantity": 2.0,
        "unitCost": 2200.0,
        "referenceType": "INVOICE",
        "referenceId": "inv_001",
        "notes": "Issued invoice INV-2026-27-0001",
        "warehouseName": "Main Warehouse",
        "createdAt": "2026-03-21T14:30:00.000Z"
      }
    ]
  }
}
```

---

### 2.4 Record Stock Adjustment
`POST /api/v1/inventory/adjustments`

Records an authorized physical inventory adjustment with an immutable audit log.

#### Validation & Constraints
- `quantity`: Must be a strictly positive number (`> 0`).
- `movementType`: Must be one of `ADJUSTMENT_ADD`, `ADJUSTMENT_SUB`, or `DAMAGE`.
- `reason`: Required string (e.g., `'Physical Count Discrepancy'`, `'Inventory Reconciliation'`).
- Negative Stock Guard: For `ADJUSTMENT_SUB` or `DAMAGE`, if deducting `quantity` causes `currentStock < 0` and `businessSettings.allowNegativeStock == false`, the server returns `400 Bad Request`.

#### Request Body
```json
{
  "productId": "7488f219-543e-4b9b-9801-7faec3137912",
  "movementType": "DAMAGE",
  "quantity": 1,
  "unitCost": 2200.0,
  "reason": "Damaged in Warehouse",
  "notes": "Dropped during pallet movement",
  "clientOperationId": "660e8400-e29b-41d4-a716-446655440001"
}
```

#### Response `201 Created`
```json
{
  "statusCode": 201,
  "message": "Stock adjustment recorded successfully",
  "data": {
    "id": "mov_adj_001",
    "productId": "7488f219-543e-4b9b-9801-7faec3137912",
    "movementType": "DAMAGE",
    "quantity": 1.0,
    "unitCost": 2200.0,
    "referenceType": "MANUAL_ADJUSTMENT",
    "notes": "Damaged in Warehouse: Dropped during pallet movement",
    "createdAt": "2026-03-22T09:00:00.000Z"
  }
}
```
