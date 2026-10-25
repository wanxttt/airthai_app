# AirthAI API Documentation — Payments & Expenses Engine

## Module Overview

The `PaymentsExpensesModule` provides enterprise sub-ledger accounting APIs for managing customer receipts, supplier disbursements, invoice/bill allocation tables, payment voiding, expense tracking, and Input Tax Credit (ITC) reporting.

Base URL prefix: `/api/v1`  
Authentication: Bearer JWT (`Authorization: Bearer <accessToken>`) with active tenant context (`BusinessGuard`, `TenantGuard`, `RolesGuard`).

---

## 1. Payments Endpoints

### 1.1 Record Customer Receipt
`POST /api/v1/payments/receipts`

Records a receipt from a debtor customer, optionally allocating it across one or more open sales invoices.

#### Request Body
```json
{
  "customerId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "amount": 15000.0,
  "paymentMethod": "UPI",
  "paymentDate": "2026-10-25T10:00:00.000Z",
  "referenceNumber": "UPI/9876543210/PAY",
  "notes": "Payment for October orders",
  "clientOperationId": "c8b417e2-45e3-4c99-b1d7-27b38cb7d4f1",
  "allocations": [
    {
      "invoiceId": "d1e2f3a4-b5c6-4d7e-8f90-1a2b3c4d5e6f",
      "amount": 10000.0
    },
    {
      "invoiceId": "e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b",
      "amount": 5000.0
    }
  ]
}
```

#### Field Specifications
- `customerId` (UUID, required): The paying customer.
- `amount` (number > 0, required): Total receipt amount.
- `paymentMethod` (string, required): `CASH`, `BANK_TRANSFER`, `UPI`, `CHEQUE`, or `CARD`.
- `paymentDate` (ISO8601 string, required): Transaction date.
- `referenceNumber` (string, optional): UTR / Cheque number / transaction ID.
- `notes` (string, optional): Internal notes.
- `clientOperationId` (UUID, optional): Idempotency key. Duplicate calls with the same key safely return the previously created record.
- `allocations` (array, optional): Target invoice allocations.
  - `invoiceId` (UUID, required): Invoice to allocate against.
  - `amount` (number > 0, required): Allocated portion. Cannot exceed invoice balance or total receipt amount.

#### Response `201 Created`
```json
{
  "statusCode": 201,
  "message": "Customer receipt recorded successfully",
  "data": {
    "id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
    "businessId": "b1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
    "paymentNumber": "RCP-2026-27-0001",
    "paymentType": "CUSTOMER_RECEIPT",
    "amount": 15000.0,
    "paymentMethod": "UPI",
    "paymentDate": "2026-10-25T10:00:00.000Z",
    "referenceNumber": "UPI/9876543210/PAY",
    "notes": "Payment for October orders",
    "customerId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "customer": {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "name": "Acme Industries",
      "currentBalance": 35000.0
    },
    "allocations": [
      {
        "id": "alloc-001",
        "invoiceId": "d1e2f3a4-b5c6-4d7e-8f90-1a2b3c4d5e6f",
        "amount": 10000.0,
        "invoice": {
          "id": "d1e2f3a4-b5c6-4d7e-8f90-1a2b3c4d5e6f",
          "invoiceNumber": "INV-2026-27-0001",
          "status": "PAID",
          "balanceAmount": 0.0
        }
      }
    ],
    "isVoided": false,
    "createdAt": "2026-10-25T10:00:00.000Z"
  }
}
```

---

### 1.2 Record Supplier Payment
`POST /api/v1/payments/supplier-payments`

Records a disbursement to a vendor supplier, optionally allocating it across one or more open purchase bills.

#### Request Body
```json
{
  "supplierId": "e2f18392-4f3b-419b-a0f1-0db3d08f7aa2",
  "amount": 20000.0,
  "paymentMethod": "BANK_TRANSFER",
  "paymentDate": "2026-10-25T11:00:00.000Z",
  "referenceNumber": "NEFT/20261025/112233",
  "notes": "Settlement of batch bill",
  "allocations": [
    {
      "purchaseId": "c8b417e2-45e3-4c99-b1d7-27b38cb7d4f1",
      "amount": 20000.0
    }
  ]
}
```

#### Response `201 Created`
Returns the created `Payment` entity with `paymentType = 'SUPPLIER_PAYMENT'` and updated purchase bill statuses.

---

### 1.3 List Payments
`GET /api/v1/payments`

#### Query Parameters
- `page` (number, optional, default: 1): Page number.
- `limit` (number, optional, default: 20): Items per page.
- `search` (string, optional): Search by payment number or reference number.
- `paymentType` (string, optional): Filter by `CUSTOMER_RECEIPT` or `SUPPLIER_PAYMENT`.
- `method` (string, optional): Filter by `CASH`, `BANK_TRANSFER`, `UPI`, `CHEQUE`, or `CARD`.
- `customerId` (UUID, optional): Filter by customer.
- `supplierId` (UUID, optional): Filter by supplier.
- `isVoided` (boolean, optional): Filter by voided status (`true` / `false`).
- `startDate` (ISO8601 string, optional): Minimum transaction date.
- `endDate` (ISO8601 string, optional): Maximum transaction date.

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Payments retrieved successfully",
  "data": [ ... ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 42,
    "totalPages": 3,
    "totalReceipts": 350000.0,
    "totalSupplierPayments": 120000.0,
    "netCashFlow": 230000.0
  }
}
```

---

### 1.4 Get Customer Outstanding Invoices
`GET /api/v1/payments/customers/:customerId/outstanding`

Retrieves all issued and partially paid invoices for a given customer that have a non-zero remaining balance.

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Outstanding invoices retrieved",
  "data": [
    {
      "id": "d1e2f3a4-b5c6-4d7e-8f90-1a2b3c4d5e6f",
      "invoiceNumber": "INV-2026-27-0002",
      "invoiceDate": "2026-10-10T00:00:00.000Z",
      "dueDate": "2026-10-25T00:00:00.000Z",
      "totalAmount": 25000.0,
      "paidAmount": 10000.0,
      "balanceAmount": 15000.0,
      "status": "PARTIALLY_PAID"
    }
  ]
}
```

---

### 1.5 Get Supplier Outstanding Bills
`GET /api/v1/payments/suppliers/:supplierId/outstanding`

Retrieves all open or partially paid purchase bills for a given supplier with remaining payable balance.

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Outstanding bills retrieved",
  "data": [
    {
      "id": "c8b417e2-45e3-4c99-b1d7-27b38cb7d4f1",
      "billNumber": "BILL-2026-001",
      "billDate": "2026-10-12T00:00:00.000Z",
      "totalAmount": 59000.0,
      "paidAmount": 20000.0,
      "balanceAmount": 39000.0,
      "paymentStatus": "PARTIALLY_PAID"
    }
  ]
}
```

---

### 1.6 Get Payment Details
`GET /api/v1/payments/:id`

Retrieves full payment voucher information with customer/supplier relationship, allocation history, and void status.

---

### 1.7 Void / Reverse Payment Voucher
`POST /api/v1/payments/:id/void`

Atomically reverses a posted payment voucher, restoring invoice or purchase balances, reversing customer or supplier account balances, and recording an audit trail entry.

#### Request Body
```json
{
  "reason": "Customer cheque bounced (dishonoured)"
}
```

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Payment voided and balances reversed successfully",
  "data": {
    "id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
    "isVoided": true,
    "voidReason": "Customer cheque bounced (dishonoured)",
    "voidedAt": "2026-10-25T14:30:00.000Z"
  }
}
```

---

## 2. Expenses Endpoints

### 2.1 List / Auto-Seed Categories
`GET /api/v1/expenses/categories`

Returns all active categories for the business tenant. Automatically seeds standard MSME operational categories if none currently exist.

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Expense categories retrieved",
  "data": [
    {
      "id": "cat-01",
      "name": "Office Supplies & Stationery",
      "description": "Paper, printer toner, pens, and general supplies"
    },
    {
      "id": "cat-02",
      "name": "Rent & Facilities",
      "description": "Office rent, warehouse lease, facility maintenance"
    }
  ]
}
```

---

### 2.2 Create Custom Category
`POST /api/v1/expenses/categories`

#### Request Body
```json
{
  "name": "Cloud Infrastructure & Hosting",
  "description": "AWS, GCP, and domain registration expenses"
}
```

#### Response `201 Created`
Returns the created `ExpenseCategory` entity. Returns `409 Conflict` if the name already exists for the business.

---

### 2.3 Create Expense
`POST /api/v1/expenses`

Records a business expense with optional GST and tax-deductible tracking.

#### Request Body
```json
{
  "categoryId": "cat-01",
  "amount": 4720.0,
  "expenseDate": "2026-10-24T09:30:00.000Z",
  "paymentMethod": "UPI",
  "vendorName": "Staples Supplies Pvt Ltd",
  "vendorGstin": "27AAACS1234F1Z5",
  "taxInvoiceNumber": "INV-ST-9912",
  "gstAmount": 720.0,
  "isTaxDeductible": true,
  "notes": "Bulk stationery for Q3"
}
```

#### Field Specifications
- `categoryId` (UUID, required): Valid expense category.
- `amount` (number > 0, required): Total incurred expense.
- `expenseDate` (ISO8601 string, required): Date of expense.
- `paymentMethod` (string, required): `CASH`, `BANK_TRANSFER`, `UPI`, `CHEQUE`, or `CARD`.
- `vendorName` (string, optional): Merchant / vendor name.
- `vendorGstin` (string, optional): 15-character GSTIN.
- `taxInvoiceNumber` (string, optional): Vendor's bill number.
- `gstAmount` (number >= 0, optional): Input GST amount. Validated against `gstAmount <= amount`.
- `isTaxDeductible` (boolean, optional, default: true): Eligible for tax deduction.
- `notes` (string, optional): Narrative.

#### Response `201 Created`
```json
{
  "statusCode": 201,
  "message": "Expense created successfully",
  "data": {
    "id": "exp-001",
    "expenseNumber": "EXP-2026-27-0001",
    "amount": 4720.0,
    "gstAmount": 720.0,
    "expenseDate": "2026-10-24T09:30:00.000Z",
    "paymentMethod": "UPI",
    "vendorName": "Staples Supplies Pvt Ltd",
    "isTaxDeductible": true,
    "category": {
      "id": "cat-01",
      "name": "Office Supplies & Stationery"
    }
  }
}
```

---

### 2.4 List Expenses
`GET /api/v1/expenses`

#### Query Parameters
- `page` (number, optional, default: 1): Page number.
- `limit` (number, optional, default: 20): Items per page.
- `search` (string, optional): Search by expense number or vendor name.
- `categoryId` (UUID, optional): Filter by category.
- `paymentMethod` (string, optional): Filter by payment method.
- `isTaxDeductible` (boolean, optional): Filter tax-deductible expenses.
- `startDate` (ISO8601 string, optional): Minimum expense date.
- `endDate` (ISO8601 string, optional): Maximum expense date.

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Expenses retrieved successfully",
  "data": [ ... ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 15,
    "totalPages": 1
  }
}
```

---

### 2.5 Get Expense Summary & Tax Metrics
`GET /api/v1/expenses/summary`

Returns aggregated metrics for financial statements and GST Input Tax Credit (ITC) reconciliation.

#### Query Parameters
- `startDate` (ISO8601 string, optional)
- `endDate` (ISO8601 string, optional)

#### Response `200 OK`
```json
{
  "statusCode": 200,
  "message": "Expense summary calculated successfully",
  "data": {
    "totalExpenses": 145000.0,
    "taxDeductibleExpenses": 138000.0,
    "totalGstAmount": 21500.0,
    "expenseCount": 42,
    "byCategory": [
      {
        "categoryName": "Rent & Facilities",
        "totalAmount": 75000.0,
        "count": 3
      },
      {
        "categoryName": "Utilities (Electricity, Water, Internet)",
        "totalAmount": 25000.0,
        "count": 5
      }
    ]
  }
}
```

---

### 2.6 Delete Expense
`DELETE /api/v1/expenses/:id`

Permanently deletes an expense record. Writes an audit log entry prior to deletion.
