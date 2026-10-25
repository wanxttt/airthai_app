# Master Data Management APIs

The AirthAI Master Data API provides endpoints for managing core business entities: **Products**, **Categories**, **Units of Measure**, **Customers**, and **Suppliers**.

All endpoints are built on a multi-tenant architecture where every business operates in isolated tenant space.

---

## 1. Authentication & Security

### Authorization Header
All master data endpoints require a valid JWT Bearer token:
```http
Authorization: Bearer <jwt_access_token>
```

### Multi-Tenant Isolation
- The authenticated user's `businessId` is resolved from their active business membership.
- All database operations are filtered by composite keys `@@unique([businessId, id])`.
- Cross-tenant references are strictly rejected:
  - When associating a `categoryId` or `unitId` with a product, the backend verifies that the category and unit belong to the caller's `businessId`.
  - Opening stock creation creates stock records only within warehouses belonging to the caller's business.

### Role-Based Access Control (RBAC)
| Resource | Read (`GET`) | Write (`POST`, `PUT`, `PATCH`) | Delete (`DELETE`) |
| :--- | :--- | :--- | :--- |
| **Products** | `OWNER`, `ADMIN`, `MANAGER`, `STAFF`, `VIEWER` | `OWNER`, `ADMIN`, `MANAGER` | `OWNER`, `ADMIN` |
| **Categories** | `OWNER`, `ADMIN`, `MANAGER`, `STAFF`, `VIEWER` | `OWNER`, `ADMIN`, `MANAGER` | `OWNER`, `ADMIN` |
| **Units** | `OWNER`, `ADMIN`, `MANAGER`, `STAFF`, `VIEWER` | `OWNER`, `ADMIN`, `MANAGER` | `OWNER`, `ADMIN` |
| **Customers** | `OWNER`, `ADMIN`, `MANAGER`, `STAFF`, `VIEWER` | `OWNER`, `ADMIN`, `MANAGER` | `OWNER`, `ADMIN` |
| **Suppliers** | `OWNER`, `ADMIN`, `MANAGER`, `STAFF`, `VIEWER` | `OWNER`, `ADMIN`, `MANAGER` | `OWNER`, `ADMIN` |

---

## 2. Categories API (`/api/v1/categories`)

### Endpoints

#### `GET /api/v1/categories`
Returns a hierarchical list of product categories for the active tenant.
- **Response `200 OK`**:
```json
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "id": "cat_001",
      "name": "Electronics",
      "description": "Electronic components and equipment",
      "parentId": null,
      "productCount": 12,
      "children": []
    }
  ]
}
```

#### `POST /api/v1/categories`
Creates a new category.
- **Request Body**:
```json
{
  "name": "Safety Gear",
  "description": "Industrial personal protective equipment",
  "parentId": null
}
```
- **Response `201 Created`**: Returns created category object.
- **Errors**: `409 Conflict` if a category with the same name already exists in this tenant.

#### `GET /api/v1/categories/:id`
Retrieves a single category by ID with its parent, child categories, and linked product count.

#### `PUT /api/v1/categories/:id`
Updates category name, description, or parent category.

#### `DELETE /api/v1/categories/:id`
Deletes a category.
- **Integrity Protection**:
  - `400 Bad Request` if child subcategories exist (`"Cannot delete category that has subcategories"`).
  - `400 Bad Request` if products are linked to this category (`"Cannot delete category with 5 linked products. Reassign or delete products first."`).

---

## 3. Units of Measure API (`/api/v1/units`)

### Endpoints

#### `GET /api/v1/units`
Lists all measurement units configured for the active business.
- **Response `200 OK`**:
```json
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "id": "unit_001",
      "name": "Pieces",
      "symbol": "PCS",
      "isDecimal": false,
      "productCount": 24
    }
  ]
}
```

#### `POST /api/v1/units`
Creates a new measurement unit.
- **Request Body**:
```json
{
  "name": "Kilograms",
  "symbol": "KG",
  "isDecimal": true
}
```
- **Response `201 Created`**
- **Errors**: `409 Conflict` if a unit with the same symbol already exists in this tenant.

#### `GET /api/v1/units/:id`
Retrieves unit details and linked product count.

#### `PUT /api/v1/units/:id`
Updates unit name, symbol, or decimal precision setting.

#### `DELETE /api/v1/units/:id`
Deletes a measurement unit.
- **Integrity Protection**:
  - `400 Bad Request` if products reference this unit (`"Cannot delete unit referenced by 8 products"`).

---

## 4. Products API (`/api/v1/products`)

### Endpoints

#### `GET /api/v1/products`
Retrieves paginated and filtered products.
- **Query Parameters**:
  - `search` (optional): Filter by name, SKU, or barcode (case-insensitive partial match).
  - `categoryId` (optional): Filter by specific category.
  - `status` (optional): `ACTIVE` (default), `ARCHIVED`, or `ALL`.
  - `page` (optional, default `1`): Page number.
  - `limit` (optional, default `50`): Items per page (max 100).
- **Response `200 OK`**:
```json
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "id": "prod_001",
      "name": "Industrial Safety Helmet",
      "sku": "SAFE-001",
      "barcode": "8901234567890",
      "description": "High-density polyethylene safety helmet",
      "salePrice": 450.00,
      "purchasePrice": 280.00,
      "mrp": 550.00,
      "gstRate": 18.00,
      "cessRate": 0.00,
      "hsnCode": "650610",
      "trackStock": true,
      "minStockLevel": 10.0,
      "currentStock": 45.0,
      "status": "ACTIVE",
      "categoryId": "cat_001",
      "categoryName": "Safety Gear",
      "unitId": "unit_001",
      "unitSymbol": "PCS"
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

#### `POST /api/v1/products`
Creates a new product with optional opening stock initialization.
- **Request Body**:
```json
{
  "name": "Heavy-Duty Power Drill 750W",
  "sku": "DRL-750",
  "barcode": "8909876543210",
  "description": "Variable speed 13mm impact drill",
  "categoryId": "cat_001",
  "unitId": "unit_001",
  "salePrice": 3200.00,
  "purchasePrice": 2100.00,
  "mrp": 3800.00,
  "gstRate": 18.00,
  "cessRate": 0.00,
  "hsnCode": "846721",
  "trackStock": true,
  "minStockLevel": 5.0,
  "openingStock": 15.0
}
```
- **Opening Stock Handling**: When `openingStock > 0` and `trackStock = true`, the system automatically resolves or creates the default business warehouse and logs a `StockMovement` of type `ADJUSTMENT_ADD` recording the initial quantity and unit purchase cost.
- **Response `201 Created`**

#### `GET /api/v1/products/:id`
Retrieves full details for a product including current stock and category/unit metadata.

#### `PUT /api/v1/products/:id`
Updates product specifications, pricing, tax rates, and categorization.

#### `PATCH /api/v1/products/:id/archive`
Toggles product status between `ACTIVE` and `ARCHIVED`. Archived products are hidden from standard billing auto-complete but retained for historical records.

#### `DELETE /api/v1/products/:id`
Deletes a product.
- **Integrity Protection**:
  - `400 Bad Request` if referenced by any invoices, purchases, quotations, or sales orders (`"Cannot delete product with existing transactions (e.g. invoices, purchases). Consider archiving it instead."`).

---

## 5. Customers API (`/api/v1/customers`)

### Endpoints

#### `GET /api/v1/customers`
Retrieves paginated customer directory with receivable balances.
- **Query Parameters**:
  - `search` (optional): Filter by name, phone, email, or GSTIN.
  - `status` (optional): `ACTIVE`, `ARCHIVED`, `ALL`.
  - `page` / `limit`: Pagination parameters.
- **Response `200 OK`**:
```json
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "id": "cust_001",
      "name": "Apex Engineering Works",
      "phone": "9876543210",
      "email": "procurement@apexeng.in",
      "gstin": "27AABCA1234A1Z5",
      "billingAddress": "Plot 42, MIDC Industrial Area",
      "city": "Pune",
      "state": "Maharashtra",
      "pincode": "411018",
      "openingBalance": 12500.00,
      "currentBalance": 45200.00,
      "creditLimit": 100000.00,
      "creditPeriodDays": 30,
      "status": "ACTIVE"
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

#### `POST /api/v1/customers`
Registers a new customer.
- **Request Body**:
```json
{
  "name": "Bright Solar Solutions",
  "phone": "9822334455",
  "email": "accounts@brightsolar.com",
  "gstin": "24AABCS5678B1Z2",
  "billingAddress": "12 Commercial Hub, Ring Road",
  "city": "Surat",
  "state": "Gujarat",
  "pincode": "395002",
  "openingBalance": 0.00,
  "creditLimit": 50000.00,
  "creditPeriodDays": 15
}
```
- **Response `201 Created`**

#### `GET /api/v1/customers/:id`
Retrieves customer details along with transaction summaries (recent invoices, payments).

#### `PUT /api/v1/customers/:id`
Updates customer details, tax identifiers, and credit terms.

#### `PATCH /api/v1/customers/:id/archive`
Toggles customer archive state (`ACTIVE` / `ARCHIVED`).

#### `DELETE /api/v1/customers/:id`
Deletes a customer record.
- **Integrity Protection**:
  - `400 Bad Request` if referenced by invoices, payments, or sales orders (`"Cannot delete customer with existing invoices, orders, or payments. Archive the customer instead."`).

---

## 6. Suppliers API (`/api/v1/suppliers`)

### Endpoints

#### `GET /api/v1/suppliers`
Retrieves paginated supplier directory with payable balances.
- **Query Parameters**:
  - `search` (optional): Filter by name, phone, email, or GSTIN.
  - `status` (optional): `ACTIVE`, `ARCHIVED`, `ALL`.
  - `page` / `limit`: Pagination parameters.
- **Response `200 OK`**:
```json
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "id": "supp_001",
      "name": "Tata Steel Distribution",
      "phone": "9811223344",
      "email": "orders@tatasteeldist.com",
      "gstin": "27AAACT2345C1Z8",
      "pan": "AAACT2345C",
      "address": "Godown 4, Kalamboli Iron Market",
      "city": "Navi Mumbai",
      "state": "Maharashtra",
      "pincode": "410218",
      "bankName": "State Bank of India",
      "accountNumber": "123456789012",
      "ifscCode": "SBIN0001234",
      "openingBalance": 45000.00,
      "currentBalance": 112000.00,
      "status": "ACTIVE"
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

#### `POST /api/v1/suppliers`
Registers a new supplier with contact, tax, and banking details.
- **Request Body**:
```json
{
  "name": "National Industrial Tools",
  "phone": "9898989898",
  "gstin": "07AAAAA0000A1Z5",
  "pan": "AAAAA0000A",
  "address": "Shop 14, Chawri Bazar",
  "city": "Delhi",
  "state": "Delhi",
  "pincode": "110006",
  "bankName": "HDFC Bank",
  "accountNumber": "50200012345678",
  "ifscCode": "HDFC0001234",
  "openingBalance": 10000.00
}
```
- **Response `201 Created`**

#### `GET /api/v1/suppliers/:id`
Retrieves supplier details with recent purchase orders and bill histories.

#### `PUT /api/v1/suppliers/:id`
Updates supplier contact, banking, or tax details.

#### `PATCH /api/v1/suppliers/:id/archive`
Toggles supplier archive state (`ACTIVE` / `ARCHIVED`).

#### `DELETE /api/v1/suppliers/:id`
Deletes a supplier record.
- **Integrity Protection**:
  - `400 Bad Request` if referenced by purchases or payment vouchers (`"Cannot delete supplier with existing purchase bills or payments. Archive the supplier instead."`).

