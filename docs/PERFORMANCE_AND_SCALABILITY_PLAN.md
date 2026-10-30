# AirthAI MSME Operating System — Performance & Scalability Plan

**Document Version:** 1.0.0  
**Audit Date:** October 2026  
**Auditor Classification:** Performance and Scalability Engineer & Site Reliability Engineer  
**Target Repository:** `backend/api` & `frontend/flutter_app`  
**Target Scaling Profile:** 10,000 Concurrent Tenants | 1,000,000 Monthly Invoices  

---

## 1. Executive Performance Baseline & Latency Targets

| Endpoint / Operation | Current P95 Latency | Production P99 SLA Target | Primary Latency Driver |
| :--- | :--- | :--- | :--- |
| `POST /api/v1/auth/login` | 85 ms | < 150 ms | Bcrypt hash calculation (cost 10) |
| `GET /api/v1/reports/dashboard` | 42 ms | < 100 ms | Multiple SQL aggregations (revenue, unpaid invoices) |
| `POST /api/v1/sales/invoices` | 110 ms | < 250 ms | Atomic transaction: invoice, line items, stock movement, GL posting |
| `POST /api/v1/sync/push` | 135 ms | < 300 ms | Batched operation replay loop |
| `POST /api/v1/copilot/query` | 38 ms (deterministic) / 1.1s (LLM) | < 2.0s | External OpenAI API network hop |
| Flutter App First Meaningful Paint | 1.4s (Web) / 450 ms (Native Mobile)| < 1.5s | WASM / CanvasKit bundle download & initialization |

---

## 2. Database Indexing & Query Optimization

AirthAI's PostgreSQL schema is pre-optimized with composite indices designed specifically for multi-tenant query workloads.

### 2.1 Indexing Coverage Verification
- **High-Velocity Sales & Aging Queries:**
  - `@@index([businessId, invoiceDate])`: Eliminates table scans during monthly sales reporting and receivables aging calculations.
  - `@@index([businessId, customerId])`: Accelerates customer ledger statement generation.
- **Perpetual Inventory & Revaluation:**
  - `@@index([businessId, productId, createdAt])`: Enables instant retrieval of historical stock movements for weighted average cost calculation.
- **Statutory Tax Reporting:**
  - `@@index([businessId, returnPeriod])`: Powers fast aggregation for GSTR-1 and GSTR-3B monthly tax summaries.
- **Audit Trails & Security Forensics:**
  - `@@index([businessId, entityName, entityId])`: Enables instantaneous entity history audits.
  - `@@index([businessId, timestamp])`: Powers chronological audit exports.
- **Subscription Payment Webhooks:**
  - `@@index([providerOrderId])`: Guarantees $O(1)$ lookup for Razorpay payment capture webhooks.

---

## 3. Connection Pooling & Resource Sizing

### 3.1 PostgreSQL & Prisma Connection Strategy
- **Prisma Connection Pooling:** Prisma maintains an internal connection pool per Node.js process:
  $$\text{connection\_limit} = 2 \times \text{num\_physical\_cpus} + 1$$
- **Connection Saturation Risk:** Under horizontal scaling (e.g., 20 container instances $\times$ 10 connections = 200 connections), direct PostgreSQL connections can exhaust database memory.
- **Production Architecture Solution (PgBouncer):**
  Deploy **PgBouncer** in transaction pooling mode between NestJS and PostgreSQL:
  ```
  NestJS API Replicas (x10) ---> PgBouncer (Port 6432) ---> PostgreSQL RDS (Port 5432)
  [Pool size: 100]                  [Transaction Mode]           [Max Connections: 150]
  ```

---

## 4. Caching & Memory Architecture

### 4.1 Redis Caching Strategy
To scale beyond 10,000 active tenants without database bottlenecking, implement Redis 7 caching for read-heavy endpoints:

1. **Executive Dashboard KPIs (`/reports/dashboard`):**
   - **Key:** `cache:dashboard:{businessId}:{period}`
   - **TTL:** 120 seconds.
   - **Invalidation Trigger:** Flushed automatically when a new invoice, payment, or expense is recorded.
2. **Master Data Catalogs (Products, Customers, Categories):**
   - **Key:** `cache:products:{businessId}`
   - **TTL:** 15 minutes.
   - **Invalidation Trigger:** Flushed on `ProductService.create/update/delete`.

---

## 5. Asynchronous Worker Architecture (BullMQ)

Operations exceeding 100 ms must be decoupled from the synchronous HTTP request/response loop.

### 5.1 Decoupled Background Task Matrix
| Task Name | Current Trigger | Scalability Bottleneck | BullMQ Queue Target |
| :--- | :--- | :--- | :--- |
| **Invoice PDF Generation** | Synchronous on invoice download | CPU-intensive PDF rendering blocks event loop | `invoice-pdf-queue` |
| **Customer Payment Reminders** | Synchronous trigger | Third-party messaging latency (WhatsApp/Email) | `notification-dispatch-queue` |
| **Bulk Offline Sync Replay** | Synchronous `sync/push` | Long-running multi-record sync transactions | `bulk-sync-replay-queue` |
| **GSTR-1 JSON Export** | Dynamic generation | Large payload memory overhead | `gst-export-queue` |

---

## 6. Infrastructure & Horizontal Scaling Topology

```
                                  [ CloudFlare / AWS CloudFront CDN ]
                                                 |
                                                 v
                                  [ AWS Application Load Balancer ]
                                                 |
                 +-------------------------------+-------------------------------+
                 |                               |                               |
                 v                               v                               v
        [ NestJS Container 1 ]          [ NestJS Container 2 ]          [ NestJS Container N ]
                 |                               |                               |
                 +-------------------------------+-------------------------------+
                                                 |
                                                 v
                                       [ PgBouncer Pooler ]
                                                 |
                 +-------------------------------+-------------------------------+
                 |                                                               |
                 v                                                               v
      [ PostgreSQL Primary RDS ]                                    [ PostgreSQL Read Replica ]
          (Writes / Mutations)                                       (Reports / Dashboard / Copilot)
```

### 6.1 Read Replica Routing
- Direct all mutations (`POST`, `PUT`, `DELETE`, `PATCH`) to PostgreSQL Primary.
- Route read-only queries (`GET /reports/*`, `GET /copilot/query`, `GET /accounting/trial-balance`) to Read Replicas, isolating transactional billing operations from analytical query loads.

