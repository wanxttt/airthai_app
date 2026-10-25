# AirthAI Accounting & GST API Specification

This document details the REST API endpoints for Chart of Accounts, Journal Entries, Financial Reports (Trial Balance, P&L, Sub-Ledgers), and GST Statutory Preparation Reports (GSTR-1, GSTR-3B).

All endpoints require authentication via JWT Bearer token and enforce tenant isolation through the authenticated user's active business context.

---

## 1. Chart of Accounts

### 1.1 List Accounts
Retrieves the complete Chart of Accounts for the business tenant. Automatically seeds default standard Indian MSME accounts if the business has none configured.

- **URL:** `/api/v1/accounting/accounts`
- **Method:** `GET`
- **Headers:** `Authorization: Bearer <access_token>`
- **Response `200 OK`:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "id": "c1010-uuid",
      "businessId": "b1-uuid",
      "code": "1010",
      "name": "Cash on Hand",
      "type": "ASSET",
      "description": "Physical currency in cash drawer",
      "currentBalance": "15200.00",
      "isDebitNormal": true,
      "isSystem": true,
      "isActive": true,
      "createdAt": "2026-10-25T10:00:00.000Z",
      "updatedAt": "2026-10-25T10:00:00.000Z"
    },
    {
      "id": "c1030-uuid",
      "businessId": "b1-uuid",
      "code": "1030",
      "name": "Trade Receivables",
      "type": "ASSET",
      "description": "Customer balances owed on sales invoices",
      "currentBalance": "45000.00",
      "isDebitNormal": true,
      "isSystem": true,
      "isActive": true,
      "createdAt": "2026-10-25T10:00:00.000Z",
      "updatedAt": "2026-10-25T10:00:00.000Z"
    }
  ]
}
```

### 1.2 Create Custom Account
Adds a custom account to the business Chart of Accounts.

- **URL:** `/api/v1/accounting/accounts`
- **Method:** `POST`
- **Headers:** `Authorization: Bearer <access_token>`, `Content-Type: application/json`
- **Request Body:**
```json
{
  "code": "5040",
  "name": "Software & Cloud Subscriptions",
  "type": "EXPENSE",
  "description": "SaaS tools and hosting infrastructure"
}
```
- **Response `201 Created`:**
```json
{
  "success": true,
  "statusCode": 201,
  "data": {
    "id": "c5040-uuid",
    "businessId": "b1-uuid",
    "code": "5040",
    "name": "Software & Cloud Subscriptions",
    "type": "EXPENSE",
    "description": "SaaS tools and hosting infrastructure",
    "currentBalance": "0.00",
    "isDebitNormal": true,
    "isSystem": false,
    "isActive": true,
    "createdAt": "2026-10-25T10:05:00.000Z",
    "updatedAt": "2026-10-25T10:05:00.000Z"
  }
}
```

---

## 2. General Ledger & Journal Entries

### 2.1 List Journal Entries
Retrieves paginated journal entries with line items, debit/credit distributions, and source document references.

- **URL:** `/api/v1/accounting/journals`
- **Method:** `GET`
- **Headers:** `Authorization: Bearer <access_token>`
- **Query Parameters:**
  - `page`: Page number (default: 1)
  - `limit`: Records per page (default: 20)
  - `entryType`: Filter by type (`GENERAL`, `SALES`, `PURCHASE`, `RECEIPT`, `PAYMENT`, `EXPENSE`, `REVERSAL`)
  - `startDate`: ISO 8601 start date
  - `endDate`: ISO 8601 end date
- **Response `200 OK`:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "id": "j-uuid-1",
      "businessId": "b1-uuid",
      "entryNumber": "JRN-2026-0001",
      "entryDate": "2026-10-25T00:00:00.000Z",
      "entryType": "SALES",
      "reference": "INV-2026-0042",
      "description": "Sales Invoice INV-2026-0042 to Apex Traders",
      "lines": [
        {
          "id": "l-1",
          "accountId": "c1030-uuid",
          "accountCode": "1030",
          "accountName": "Trade Receivables",
          "debit": "11800.00",
          "credit": "0.00",
          "description": "Gross invoice receivable"
        },
        {
          "id": "l-2",
          "accountId": "c4010-uuid",
          "accountCode": "4010",
          "accountName": "Sales Revenue",
          "debit": "0.00",
          "credit": "10000.00",
          "description": "Taxable sales revenue"
        },
        {
          "id": "l-3",
          "accountId": "c2020-uuid",
          "accountCode": "2020",
          "accountName": "Output CGST",
          "debit": "0.00",
          "credit": "900.00",
          "description": "Central GST 9%"
        },
        {
          "id": "l-4",
          "accountId": "c2030-uuid",
          "accountCode": "2030",
          "accountName": "Output SGST",
          "debit": "0.00",
          "credit": "900.00",
          "description": "State GST 9%"
        }
      ],
      "totalDebit": "11800.00",
      "totalCredit": "11800.00",
      "isBalanced": true,
      "createdAt": "2026-10-25T10:00:00.000Z"
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

### 2.2 Record Manual Journal Entry
Creates a manual general journal entry. Enforces strict double-entry equality ($\sum \text{debits} == \sum \text{credits}$) and minimum of 2 ledger lines.

- **URL:** `/api/v1/accounting/journals`
- **Method:** `POST`
- **Headers:** `Authorization: Bearer <access_token>`, `Content-Type: application/json`
- **Request Body:**
```json
{
  "entryDate": "2026-10-25T00:00:00.000Z",
  "description": "Depreciation adjustment for machinery",
  "reference": "ADJ-2026-10",
  "lines": [
    {
      "accountId": "c5030-uuid",
      "debit": 5000.00,
      "credit": 0.00,
      "description": "Depreciation expense"
    },
    {
      "accountId": "c1040-uuid",
      "debit": 0.00,
      "credit": 5000.00,
      "description": "Accumulated depreciation"
    }
  ]
}
```
- **Response `201 Created`:**
```json
{
  "success": true,
  "statusCode": 201,
  "data": {
    "id": "j-uuid-2",
    "entryNumber": "JRN-2026-0002",
    "entryDate": "2026-10-25T00:00:00.000Z",
    "entryType": "GENERAL",
    "reference": "ADJ-2026-10",
    "description": "Depreciation adjustment for machinery",
    "totalDebit": "5000.00",
    "totalCredit": "5000.00",
    "isBalanced": true
  }
}
```

---

## 3. Financial Reports

### 3.1 Trial Balance
Calculates aggregated debit and credit activity for all accounts within the period and validates that total debits strictly equal total credits.

- **URL:** `/api/v1/accounting/reports/trial-balance`
- **Method:** `GET`
- **Headers:** `Authorization: Bearer <access_token>`
- **Query Parameters:**
  - `startDate`: ISO 8601 start date
  - `endDate`: ISO 8601 end date
- **Response `200 OK`:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "startDate": "2026-10-01T00:00:00.000Z",
    "endDate": "2026-10-31T23:59:59.999Z",
    "accounts": [
      {
        "accountId": "c1010-uuid",
        "accountCode": "1010",
        "accountName": "Cash on Hand",
        "accountType": "ASSET",
        "totalDebit": "50000.00",
        "totalCredit": "10000.00",
        "netBalance": "40000.00"
      },
      {
        "accountId": "c4010-uuid",
        "accountCode": "4010",
        "accountName": "Sales Revenue",
        "accountType": "REVENUE",
        "totalDebit": "0.00",
        "totalCredit": "40000.00",
        "netBalance": "40000.00"
      }
    ],
    "totalDebit": "50000.00",
    "totalCredit": "50000.00",
    "difference": "0.00",
    "isBalanced": true
  }
}
```

### 3.2 Profit & Loss Statement (Income Statement)
Calculates operating revenue, operating expenses, and net profit or loss.

- **URL:** `/api/v1/accounting/reports/profit-loss`
- **Method:** `GET`
- **Headers:** `Authorization: Bearer <access_token>`
- **Query Parameters:**
  - `startDate`: ISO 8601 start date
  - `endDate`: ISO 8601 end date
- **Response `200 OK`:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "startDate": "2026-10-01T00:00:00.000Z",
    "endDate": "2026-10-31T23:59:59.999Z",
    "revenueAccounts": [
      {
        "accountCode": "4010",
        "accountName": "Sales Revenue",
        "amount": "125000.00"
      }
    ],
    "expenseAccounts": [
      {
        "accountCode": "5010",
        "accountName": "Cost of Goods Sold (Purchases)",
        "amount": "65000.00"
      },
      {
        "accountCode": "5020",
        "accountName": "Rent & Occupancy Expense",
        "amount": "15000.00"
      }
    ],
    "totalRevenue": "125000.00",
    "totalExpenses": "80000.00",
    "netProfit": "45000.00"
  }
}
```

### 3.3 Customer Receivables Sub-Ledger
Summarizes outstanding debtor balances, overdue days, and last transaction dates.

- **URL:** `/api/v1/accounting/reports/receivables`
- **Method:** `GET`
- **Headers:** `Authorization: Bearer <access_token>`
- **Response `200 OK`:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "reportType": "CUSTOMER_RECEIVABLES",
    "items": [
      {
        "partyId": "cust-1-uuid",
        "partyName": "Apex Trading Corp",
        "phone": "+919876543210",
        "gstin": "27AABCA1234F1Z5",
        "currentBalance": "24500.00",
        "unallocatedCredit": "0.00",
        "netReceivable": "24500.00"
      }
    ],
    "totalOutstanding": "24500.00"
  }
}
```

### 3.4 Supplier Payables Sub-Ledger
Summarizes creditor balances owed on confirmed purchase bills.

- **URL:** `/api/v1/accounting/reports/payables`
- **Method:** `GET`
- **Headers:** `Authorization: Bearer <access_token>`
- **Response `200 OK`:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "reportType": "SUPPLIER_PAYABLES",
    "items": [
      {
        "partyId": "supp-1-uuid",
        "partyName": "Global Steel Industries",
        "phone": "+919123456789",
        "gstin": "27GGGGG1234F1Z8",
        "currentBalance": "18000.00",
        "unallocatedDebit": "0.00",
        "netPayable": "18000.00"
      }
    ],
    "totalOutstanding": "18000.00"
  }
}
```

---

## 4. GST Return Preparation Summaries

### 4.1 Form GSTR-1 Preparation Summary
Generates Table 4 (B2B Taxable Invoices), Table 7 (B2C Others), and Table 12 (HSN/SAC Summary) for statutory GSTR-1 preparation.

- **URL:** `/api/v1/gst/gstr-1`
- **Method:** `GET`
- **Headers:** `Authorization: Bearer <access_token>`
- **Query Parameters:**
  - `month`: 1 to 12
  - `year`: 4-digit year (e.g. 2026)
- **Response `200 OK`:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "returnPeriod": "10-2026",
    "b2bInvoices": [
      {
        "invoiceNumber": "INV-2026-0042",
        "invoiceDate": "2026-10-25T00:00:00.000Z",
        "customerGstin": "27AABCA1234F1Z5",
        "customerName": "Apex Trading Corp",
        "placeOfSupply": "27-Maharashtra",
        "taxableValue": "10000.00",
        "cgst": "900.00",
        "sgst": "900.00",
        "igst": "0.00",
        "cess": "0.00",
        "totalInvoiceValue": "11800.00"
      }
    ],
    "b2cSummary": [
      {
        "placeOfSupply": "27-Maharashtra",
        "taxRate": "18.00",
        "taxableValue": "5000.00",
        "cgst": "450.00",
        "sgst": "450.00",
        "igst": "0.00",
        "cess": "0.00"
      }
    ],
    "hsnSummary": [
      {
        "hsnCode": "84713010",
        "description": "Laptops & Processing Units",
        "unit": "NOS",
        "totalQuantity": 5,
        "totalTaxableValue": "15000.00",
        "cgst": "1350.00",
        "sgst": "1350.00",
        "igst": "0.00",
        "cess": "0.00"
      }
    ],
    "totals": {
      "totalInvoices": 2,
      "totalTaxableValue": "15000.00",
      "totalCgst": "1350.00",
      "totalSgst": "1350.00",
      "totalIgst": "0.00",
      "totalCess": "0.00",
      "totalValue": "17700.00"
    },
    "disclaimer": "Form GSTR-1 preparation summary generated for reconciliation and return review. Does not constitute official electronic submission to the GST Common Portal."
  }
}
```

### 4.2 Form GSTR-3B Preparation Summary
Generates Table 3.1 (Outward Supplies & Tax Liability), Table 4 (Eligible Input Tax Credit), and Net Tax Payable calculation.

- **URL:** `/api/v1/gst/gstr-3b`
- **Method:** `GET`
- **Headers:** `Authorization: Bearer <access_token>`
- **Query Parameters:**
  - `month`: 1 to 12
  - `year`: 4-digit year (e.g. 2026)
- **Response `200 OK`:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "returnPeriod": "10-2026",
    "table31Outward": {
      "taxableValue": "15000.00",
      "cgst": "1350.00",
      "sgst": "1350.00",
      "igst": "0.00",
      "cess": "0.00"
    },
    "table4Itc": {
      "taxableValue": "10000.00",
      "cgst": "900.00",
      "sgst": "900.00",
      "igst": "0.00",
      "cess": "0.00"
    },
    "netTaxPayable": {
      "cgst": "450.00",
      "sgst": "450.00",
      "igst": "0.00",
      "cess": "0.00",
      "total": "900.00"
    },
    "disclaimer": "Form GSTR-3B preparation summary generated for self-assessment calculation. Does not constitute official electronic submission to the GST Common Portal."
  }
}
```
