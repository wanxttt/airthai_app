import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import {
  QueryAgeingReportDto,
  QueryExpensesReportDto,
  QueryPaymentsReportDto,
  QueryProductPerformanceDto,
  QueryPurchasesReportDto,
  QuerySalesReportDto,
  QueryStockMovementReportDto,
  QueryStockReportDto,
} from './dto/query-reports.dto';

@Injectable()
export class ReportsService {
  private readonly logger = new Logger(ReportsService.name);

  constructor(private readonly prisma: PrismaService) {}

  // =========================================================================
  // 1. SALES REPORT
  // =========================================================================
  async getSalesReport(businessId: string, query: QuerySalesReportDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const skip = (page - 1) * limit;

    const where: Prisma.InvoiceWhereInput = {
      businessId,
      status: query.status ? (query.status as any) : { not: 'CANCELLED' },
    };

    if (query.customerId) {
      where.customerId = query.customerId;
    }

    if (query.startDate || query.endDate) {
      where.invoiceDate = {};
      if (query.startDate) where.invoiceDate.gte = new Date(query.startDate);
      if (query.endDate) where.invoiceDate.lte = new Date(query.endDate);
    }

    if (query.search) {
      where.OR = [
        { invoiceNumber: { contains: query.search, mode: 'insensitive' } },
        { customer: { name: { contains: query.search, mode: 'insensitive' } } },
      ];
    }

    const [aggregations, totalCount, invoices] = await Promise.all([
      this.prisma.invoice.aggregate({
        where,
        _sum: {
          subtotal: true,
          discountAmount: true,
          taxableAmount: true,
          cgstAmount: true,
          sgstAmount: true,
          igstAmount: true,
          roundOff: true,
          totalAmount: true,
          receivedAmount: true,
          balanceAmount: true,
        },
        _count: { id: true },
      }),
      this.prisma.invoice.count({ where }),
      this.prisma.invoice.findMany({
        where,
        skip,
        take: limit,
        orderBy: { invoiceDate: 'desc' },
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          _count: { select: { items: true } },
        },
      }),
    ]);

    const totalSales = aggregations._sum.totalAmount || new Prisma.Decimal(0);
    const totalTax = (aggregations._sum.cgstAmount || new Prisma.Decimal(0))
      .plus(aggregations._sum.sgstAmount || new Prisma.Decimal(0))
      .plus(aggregations._sum.igstAmount || new Prisma.Decimal(0));
    const totalReceived = aggregations._sum.receivedAmount || new Prisma.Decimal(0);
    const totalBalance = aggregations._sum.balanceAmount || new Prisma.Decimal(0);
    const invoiceCount = aggregations._count.id;
    const avgInvoiceValue = invoiceCount > 0 ? totalSales.dividedBy(invoiceCount).toNumber() : 0;

    return {
      statusCode: 200,
      message: 'Sales report generated successfully',
      summary: {
        totalInvoiced: totalSales.toNumber(),
        subtotal: (aggregations._sum.subtotal || new Prisma.Decimal(0)).toNumber(),
        totalTax: totalTax.toNumber(),
        totalDiscount: (aggregations._sum.discountAmount || new Prisma.Decimal(0)).toNumber(),
        totalReceived: totalReceived.toNumber(),
        totalOutstanding: totalBalance.toNumber(),
        invoiceCount,
        averageInvoiceValue: Number(avgInvoiceValue.toFixed(2)),
      },
      meta: {
        page,
        limit,
        total: totalCount,
        totalPages: Math.ceil(totalCount / limit),
      },
      data: invoices.map((inv) => ({
        id: inv.id,
        invoiceNumber: inv.invoiceNumber,
        invoiceDate: inv.invoiceDate.toISOString(),
        dueDate: inv.dueDate ? inv.dueDate.toISOString() : null,
        customerId: inv.customerId,
        customerName: inv.customer?.name || 'Walk-in Customer',
        itemCount: inv._count.items,
        subtotal: Number(inv.subtotal),
        discountAmount: Number(inv.discountAmount),
        taxableAmount: Number(inv.taxableAmount),
        taxAmount: Number(inv.cgstAmount.plus(inv.sgstAmount).plus(inv.igstAmount)),
        totalAmount: Number(inv.totalAmount),
        receivedAmount: Number(inv.receivedAmount),
        balanceAmount: Number(inv.balanceAmount),
        status: inv.status,
      })),
    };
  }

  // =========================================================================
  // 2. PURCHASE REPORT
  // =========================================================================
  async getPurchasesReport(businessId: string, query: QueryPurchasesReportDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const skip = (page - 1) * limit;

    const where: Prisma.PurchaseWhereInput = {
      businessId,
      status: query.status ? (query.status as any) : { not: 'CANCELLED' },
    };

    if (query.supplierId) {
      where.supplierId = query.supplierId;
    }

    if (query.startDate || query.endDate) {
      where.billDate = {};
      if (query.startDate) where.billDate.gte = new Date(query.startDate);
      if (query.endDate) where.billDate.lte = new Date(query.endDate);
    }

    if (query.search) {
      where.OR = [
        { billNumber: { contains: query.search, mode: 'insensitive' } },
        { supplier: { name: { contains: query.search, mode: 'insensitive' } } },
      ];
    }

    const [aggregations, totalCount, purchases] = await Promise.all([
      this.prisma.purchase.aggregate({
        where,
        _sum: {
          subtotal: true,
          taxAmount: true,
          totalAmount: true,
          paidAmount: true,
          balanceAmount: true,
        },
        _count: { id: true },
      }),
      this.prisma.purchase.count({ where }),
      this.prisma.purchase.findMany({
        where,
        skip,
        take: limit,
        orderBy: { billDate: 'desc' },
        include: {
          supplier: { select: { id: true, name: true, phone: true } },
          _count: { select: { items: true } },
        },
      }),
    ]);

    const totalPurchased = aggregations._sum.totalAmount || new Prisma.Decimal(0);
    const totalPaid = aggregations._sum.paidAmount || new Prisma.Decimal(0);
    const totalBalance = aggregations._sum.balanceAmount || new Prisma.Decimal(0);
    const totalTax = aggregations._sum.taxAmount || new Prisma.Decimal(0);
    const billCount = aggregations._count.id;

    return {
      statusCode: 200,
      message: 'Purchase report generated successfully',
      summary: {
        totalPurchased: totalPurchased.toNumber(),
        subtotal: (aggregations._sum.subtotal || new Prisma.Decimal(0)).toNumber(),
        totalTax: totalTax.toNumber(),
        totalPaid: totalPaid.toNumber(),
        totalOutstanding: totalBalance.toNumber(),
        billCount,
      },
      meta: {
        page,
        limit,
        total: totalCount,
        totalPages: Math.ceil(totalCount / limit),
      },
      data: purchases.map((p) => ({
        id: p.id,
        billNumber: p.billNumber,
        billDate: p.billDate.toISOString(),
        supplierId: p.supplierId,
        supplierName: p.supplier?.name || 'Supplier',
        itemCount: p._count.items,
        subtotal: Number(p.subtotal),
        taxAmount: Number(p.taxAmount),
        totalAmount: Number(p.totalAmount),
        paidAmount: Number(p.paidAmount),
        balanceAmount: Number(p.balanceAmount),
        status: p.status,
        paymentStatus: p.paymentStatus,
      })),
    };
  }

  // =========================================================================
  // 3. EXPENSE REPORT
  // =========================================================================
  async getExpensesReport(businessId: string, query: QueryExpensesReportDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const skip = (page - 1) * limit;

    const where: Prisma.ExpenseWhereInput = { businessId };

    if (query.categoryId) where.categoryId = query.categoryId;
    if (query.paymentMethod) where.paymentMethod = query.paymentMethod as any;

    if (query.startDate || query.endDate) {
      where.date = {};
      if (query.startDate) where.date.gte = new Date(query.startDate);
      if (query.endDate) where.date.lte = new Date(query.endDate);
    }

    if (query.search) {
      where.OR = [
        { expenseNumber: { contains: query.search, mode: 'insensitive' } },
        { vendor: { contains: query.search, mode: 'insensitive' } },
        { category: { name: { contains: query.search, mode: 'insensitive' } } },
      ];
    }

    const [aggregations, totalCount, expenses, categoryBreakdownRaw] = await Promise.all([
      this.prisma.expense.aggregate({
        where,
        _sum: {
          amount: true,
          gstAmount: true,
        },
        _count: { id: true },
      }),
      this.prisma.expense.count({ where }),
      this.prisma.expense.findMany({
        where,
        skip,
        take: limit,
        orderBy: { date: 'desc' },
        include: { category: true },
      }),
      this.prisma.expense.groupBy({
        by: ['categoryId'],
        where,
        _sum: { amount: true, gstAmount: true },
        _count: { id: true },
      }),
    ]);

    const totalExpense = aggregations._sum.amount || new Prisma.Decimal(0);
    const totalGst = aggregations._sum.gstAmount || new Prisma.Decimal(0);
    const netExpense = totalExpense.minus(totalGst);

    // Fetch category names for breakdown
    const categoryIds = categoryBreakdownRaw.map((c) => c.categoryId);
    const categories = await this.prisma.expenseCategory.findMany({
      where: { businessId, id: { in: categoryIds } },
    });
    const categoryMap = new Map(categories.map((c) => [c.id, c.name]));

    const categoryBreakdown = categoryBreakdownRaw.map((item) => {
      const amount = (item._sum.amount || new Prisma.Decimal(0)).toNumber();
      const pct = totalExpense.greaterThan(0)
        ? (item._sum.amount || new Prisma.Decimal(0)).dividedBy(totalExpense).times(100).toNumber()
        : 0;
      return {
        categoryId: item.categoryId,
        categoryName: categoryMap.get(item.categoryId) || 'General',
        count: item._count.id,
        amount,
        percentage: Number(pct.toFixed(1)),
      };
    });

    return {
      statusCode: 200,
      message: 'Expense report generated successfully',
      summary: {
        totalExpenses: totalExpense.toNumber(),
        gstAmount: totalGst.toNumber(),
        netExpenses: netExpense.toNumber(),
        expenseCount: aggregations._count.id,
      },
      categoryBreakdown,
      meta: {
        page,
        limit,
        total: totalCount,
        totalPages: Math.ceil(totalCount / limit),
      },
      data: expenses.map((e) => ({
        id: e.id,
        expenseNumber: e.expenseNumber,
        date: e.date.toISOString(),
        categoryId: e.categoryId,
        categoryName: e.category.name,
        vendor: e.vendor,
        amount: Number(e.amount),
        gstAmount: Number(e.gstAmount),
        netAmount: Number(e.amount.minus(e.gstAmount)),
        paymentMethod: e.paymentMethod,
        isTaxDeductible: e.isTaxDeductible,
        notes: e.notes,
      })),
    };
  }

  // =========================================================================
  // 4. PAYMENTS & COLLECTIONS REPORT
  // =========================================================================
  async getPaymentsReport(businessId: string, query: QueryPaymentsReportDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const skip = (page - 1) * limit;

    const where: Prisma.PaymentWhereInput = { businessId };

    if (query.paymentType) where.paymentType = query.paymentType;
    if (query.paymentMethod) where.paymentMethod = query.paymentMethod as any;

    if (query.startDate || query.endDate) {
      where.paymentDate = {};
      if (query.startDate) where.paymentDate.gte = new Date(query.startDate);
      if (query.endDate) where.paymentDate.lte = new Date(query.endDate);
    }

    if (query.search) {
      where.OR = [
        { paymentNumber: { contains: query.search, mode: 'insensitive' } },
        { referenceNumber: { contains: query.search, mode: 'insensitive' } },
        { customer: { name: { contains: query.search, mode: 'insensitive' } } },
        { supplier: { name: { contains: query.search, mode: 'insensitive' } } },
      ];
    }

    const [aggregationsReceipts, aggregationsDisbursements, totalCount, payments, methodBreakdownRaw] =
      await Promise.all([
        this.prisma.payment.aggregate({
          where: { ...where, paymentType: 'CUSTOMER_RECEIPT' },
          _sum: { amount: true },
          _count: { id: true },
        }),
        this.prisma.payment.aggregate({
          where: { ...where, paymentType: 'SUPPLIER_PAYMENT' },
          _sum: { amount: true },
          _count: { id: true },
        }),
        this.prisma.payment.count({ where }),
        this.prisma.payment.findMany({
          where,
          skip,
          take: limit,
          orderBy: { paymentDate: 'desc' },
          include: {
            customer: { select: { id: true, name: true } },
            supplier: { select: { id: true, name: true } },
            allocations: true,
          },
        }),
        this.prisma.payment.groupBy({
          by: ['paymentMethod', 'paymentType'],
          where,
          _sum: { amount: true },
          _count: { id: true },
        }),
      ]);

    const totalReceipts = aggregationsReceipts._sum.amount || new Prisma.Decimal(0);
    const totalDisbursements = aggregationsDisbursements._sum.amount || new Prisma.Decimal(0);
    const netCashFlow = totalReceipts.minus(totalDisbursements);

    const methodBreakdown = methodBreakdownRaw.map((m) => ({
      method: m.paymentMethod,
      type: m.paymentType,
      count: m._count.id,
      amount: (m._sum.amount || new Prisma.Decimal(0)).toNumber(),
    }));

    return {
      statusCode: 200,
      message: 'Payments & Collections report generated successfully',
      summary: {
        totalReceipts: totalReceipts.toNumber(),
        receiptsCount: aggregationsReceipts._count.id,
        totalDisbursements: totalDisbursements.toNumber(),
        disbursementsCount: aggregationsDisbursements._count.id,
        netCashFlow: netCashFlow.toNumber(),
      },
      methodBreakdown,
      meta: {
        page,
        limit,
        total: totalCount,
        totalPages: Math.ceil(totalCount / limit),
      },
      data: payments.map((p) => ({
        id: p.id,
        paymentNumber: p.paymentNumber,
        paymentType: p.paymentType,
        paymentDate: p.paymentDate.toISOString(),
        paymentMethod: p.paymentMethod,
        referenceNumber: p.referenceNumber,
        partyId: p.customerId || p.supplierId,
        partyName: p.customer?.name || p.supplier?.name || 'Walk-in Party',
        amount: Number(p.amount),
        allocationCount: p.allocations.length,
        notes: p.notes,
      })),
    };
  }

  // =========================================================================
  // 5. RECEIVABLES & AGEING REPORT
  // =========================================================================
  async getReceivablesAgeingReport(businessId: string, query: QueryAgeingReportDto) {
    const asOfDate = query.asOfDate ? new Date(query.asOfDate) : new Date();

    const [customers, unpaidInvoices, arAccount] = await Promise.all([
      this.prisma.customer.findMany({
        where: { businessId, status: 'ACTIVE' },
        select: { id: true, name: true, phone: true, currentBalance: true },
        orderBy: { name: 'asc' },
      }),
      this.prisma.invoice.findMany({
        where: {
          businessId,
          status: { in: ['ISSUED', 'PARTIALLY_PAID'] },
          balanceAmount: { gt: 0 },
        },
        select: {
          id: true,
          invoiceNumber: true,
          customerId: true,
          invoiceDate: true,
          dueDate: true,
          balanceAmount: true,
          totalAmount: true,
        },
      }),
      this.prisma.account.findFirst({
        where: { businessId, code: '1100' },
      }),
    ]);

    // Ageing Buckets per Customer
    const customerMap = new Map<
      string,
      {
        id: string;
        name: string;
        phone: string | null;
        ledgerBalance: number;
        unpaidInvoicesCount: number;
        bucket0to30: Prisma.Decimal;
        bucket31to60: Prisma.Decimal;
        bucket61to90: Prisma.Decimal;
        bucket90Plus: Prisma.Decimal;
        totalAgeingBalance: Prisma.Decimal;
        oldestInvoiceDate: Date | null;
      }
    >();

    for (const c of customers) {
      customerMap.set(c.id, {
        id: c.id,
        name: c.name,
        phone: c.phone,
        ledgerBalance: Number(c.currentBalance),
        unpaidInvoicesCount: 0,
        bucket0to30: new Prisma.Decimal(0),
        bucket31to60: new Prisma.Decimal(0),
        bucket61to90: new Prisma.Decimal(0),
        bucket90Plus: new Prisma.Decimal(0),
        totalAgeingBalance: new Prisma.Decimal(0),
        oldestInvoiceDate: null,
      });
    }

    let globalBucket0to30 = new Prisma.Decimal(0);
    let globalBucket31to60 = new Prisma.Decimal(0);
    let globalBucket61to90 = new Prisma.Decimal(0);
    let globalBucket90Plus = new Prisma.Decimal(0);
    let globalTotalReceivables = new Prisma.Decimal(0);

    for (const inv of unpaidInvoices) {
      if (!inv.customerId || !customerMap.has(inv.customerId)) continue;
      const cEntry = customerMap.get(inv.customerId)!;
      cEntry.unpaidInvoicesCount++;

      const daysDiff = Math.max(
        0,
        Math.floor((asOfDate.getTime() - inv.invoiceDate.getTime()) / (1000 * 60 * 60 * 24)),
      );

      if (!cEntry.oldestInvoiceDate || inv.invoiceDate < cEntry.oldestInvoiceDate) {
        cEntry.oldestInvoiceDate = inv.invoiceDate;
      }

      if (daysDiff <= 30) {
        cEntry.bucket0to30 = cEntry.bucket0to30.plus(inv.balanceAmount);
        globalBucket0to30 = globalBucket0to30.plus(inv.balanceAmount);
      } else if (daysDiff <= 60) {
        cEntry.bucket31to60 = cEntry.bucket31to60.plus(inv.balanceAmount);
        globalBucket31to60 = globalBucket31to60.plus(inv.balanceAmount);
      } else if (daysDiff <= 90) {
        cEntry.bucket61to90 = cEntry.bucket61to90.plus(inv.balanceAmount);
        globalBucket61to90 = globalBucket61to90.plus(inv.balanceAmount);
      } else {
        cEntry.bucket90Plus = cEntry.bucket90Plus.plus(inv.balanceAmount);
        globalBucket90Plus = globalBucket90Plus.plus(inv.balanceAmount);
      }

      cEntry.totalAgeingBalance = cEntry.totalAgeingBalance.plus(inv.balanceAmount);
      globalTotalReceivables = globalTotalReceivables.plus(inv.balanceAmount);
    }

    // Filter to customers that have non-zero balance or unpaid invoices
    const customerList = Array.from(customerMap.values())
      .filter((c) => c.ledgerBalance > 0 || c.totalAgeingBalance.greaterThan(0))
      .map((c) => ({
        id: c.id,
        name: c.name,
        phone: c.phone,
        ledgerBalance: c.ledgerBalance,
        unpaidInvoicesCount: c.unpaidInvoicesCount,
        bucket0to30: c.bucket0to30.toNumber(),
        bucket31to60: c.bucket31to60.toNumber(),
        bucket61to90: c.bucket61to90.toNumber(),
        bucket90Plus: c.bucket90Plus.toNumber(),
        totalAgeingBalance: c.totalAgeingBalance.toNumber(),
        oldestInvoiceDate: c.oldestInvoiceDate ? c.oldestInvoiceDate.toISOString() : null,
      }));

    const glControlBalance = arAccount ? Number(arAccount.balance) : 0;
    const totalCustomerBalance = customers.reduce((sum, c) => sum + Number(c.currentBalance), 0);
    const discrepancy = Math.abs(totalCustomerBalance - glControlBalance);

    return {
      statusCode: 200,
      message: 'Receivables ageing report generated successfully',
      summary: {
        asOfDate: asOfDate.toISOString(),
        totalReceivables: globalTotalReceivables.toNumber(),
        totalCustomerLedgerBalances: totalCustomerBalance,
        glControlAccountBalance: glControlBalance,
        isReconciled: discrepancy < 0.01,
        discrepancy,
        bucket0to30: globalBucket0to30.toNumber(),
        bucket31to60: globalBucket31to60.toNumber(),
        bucket61to90: globalBucket61to90.toNumber(),
        bucket90Plus: globalBucket90Plus.toNumber(),
      },
      customers: customerList,
    };
  }

  // =========================================================================
  // 6. PAYABLES & AGEING REPORT
  // =========================================================================
  async getPayablesAgeingReport(businessId: string, query: QueryAgeingReportDto) {
    const asOfDate = query.asOfDate ? new Date(query.asOfDate) : new Date();

    const [suppliers, unpaidPurchases, apAccount] = await Promise.all([
      this.prisma.supplier.findMany({
        where: { businessId, status: 'ACTIVE' },
        select: { id: true, name: true, phone: true, currentBalance: true },
        orderBy: { name: 'asc' },
      }),
      this.prisma.purchase.findMany({
        where: {
          businessId,
          status: { not: 'CANCELLED' },
          paymentStatus: { in: ['UNPAID', 'PARTIALLY_PAID'] },
          balanceAmount: { gt: 0 },
        },
        select: {
          id: true,
          billNumber: true,
          supplierId: true,
          billDate: true,
          balanceAmount: true,
          totalAmount: true,
        },
      }),
      this.prisma.account.findFirst({
        where: { businessId, code: '2000' },
      }),
    ]);

    const supplierMap = new Map<
      string,
      {
        id: string;
        name: string;
        phone: string | null;
        ledgerBalance: number;
        unpaidBillsCount: number;
        bucket0to30: Prisma.Decimal;
        bucket31to60: Prisma.Decimal;
        bucket61to90: Prisma.Decimal;
        bucket90Plus: Prisma.Decimal;
        totalAgeingBalance: Prisma.Decimal;
        oldestBillDate: Date | null;
      }
    >();

    for (const s of suppliers) {
      supplierMap.set(s.id, {
        id: s.id,
        name: s.name,
        phone: s.phone,
        ledgerBalance: Number(s.currentBalance),
        unpaidBillsCount: 0,
        bucket0to30: new Prisma.Decimal(0),
        bucket31to60: new Prisma.Decimal(0),
        bucket61to90: new Prisma.Decimal(0),
        bucket90Plus: new Prisma.Decimal(0),
        totalAgeingBalance: new Prisma.Decimal(0),
        oldestBillDate: null,
      });
    }

    let globalBucket0to30 = new Prisma.Decimal(0);
    let globalBucket31to60 = new Prisma.Decimal(0);
    let globalBucket61to90 = new Prisma.Decimal(0);
    let globalBucket90Plus = new Prisma.Decimal(0);
    let globalTotalPayables = new Prisma.Decimal(0);

    for (const p of unpaidPurchases) {
      if (!p.supplierId || !supplierMap.has(p.supplierId)) continue;
      const sEntry = supplierMap.get(p.supplierId)!;
      sEntry.unpaidBillsCount++;

      const daysDiff = Math.max(
        0,
        Math.floor((asOfDate.getTime() - p.billDate.getTime()) / (1000 * 60 * 60 * 24)),
      );

      if (!sEntry.oldestBillDate || p.billDate < sEntry.oldestBillDate) {
        sEntry.oldestBillDate = p.billDate;
      }

      if (daysDiff <= 30) {
        sEntry.bucket0to30 = sEntry.bucket0to30.plus(p.balanceAmount);
        globalBucket0to30 = globalBucket0to30.plus(p.balanceAmount);
      } else if (daysDiff <= 60) {
        sEntry.bucket31to60 = sEntry.bucket31to60.plus(p.balanceAmount);
        globalBucket31to60 = globalBucket31to60.plus(p.balanceAmount);
      } else if (daysDiff <= 90) {
        sEntry.bucket61to90 = sEntry.bucket61to90.plus(p.balanceAmount);
        globalBucket61to90 = globalBucket61to90.plus(p.balanceAmount);
      } else {
        sEntry.bucket90Plus = sEntry.bucket90Plus.plus(p.balanceAmount);
        globalBucket90Plus = globalBucket90Plus.plus(p.balanceAmount);
      }

      sEntry.totalAgeingBalance = sEntry.totalAgeingBalance.plus(p.balanceAmount);
      globalTotalPayables = globalTotalPayables.plus(p.balanceAmount);
    }

    const supplierList = Array.from(supplierMap.values())
      .filter((s) => s.ledgerBalance > 0 || s.totalAgeingBalance.greaterThan(0))
      .map((s) => ({
        id: s.id,
        name: s.name,
        phone: s.phone,
        ledgerBalance: s.ledgerBalance,
        unpaidBillsCount: s.unpaidBillsCount,
        bucket0to30: s.bucket0to30.toNumber(),
        bucket31to60: s.bucket31to60.toNumber(),
        bucket61to90: s.bucket61to90.toNumber(),
        bucket90Plus: s.bucket90Plus.toNumber(),
        totalAgeingBalance: s.totalAgeingBalance.toNumber(),
        oldestBillDate: s.oldestBillDate ? s.oldestBillDate.toISOString() : null,
      }));

    const glControlBalance = apAccount ? Number(apAccount.balance) : 0;
    const totalSupplierBalance = suppliers.reduce((sum, s) => sum + Number(s.currentBalance), 0);
    const discrepancy = Math.abs(totalSupplierBalance - glControlBalance);

    return {
      statusCode: 200,
      message: 'Payables ageing report generated successfully',
      summary: {
        asOfDate: asOfDate.toISOString(),
        totalPayables: globalTotalPayables.toNumber(),
        totalSupplierLedgerBalances: totalSupplierBalance,
        glControlAccountBalance: glControlBalance,
        isReconciled: discrepancy < 0.01,
        discrepancy,
        bucket0to30: globalBucket0to30.toNumber(),
        bucket31to60: globalBucket31to60.toNumber(),
        bucket61to90: globalBucket61to90.toNumber(),
        bucket90Plus: globalBucket90Plus.toNumber(),
      },
      suppliers: supplierList,
    };
  }

  // =========================================================================
  // 7. STOCK SUMMARY REPORT
  // =========================================================================
  async getStockSummaryReport(businessId: string, query: QueryStockReportDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const skip = (page - 1) * limit;

    const where: Prisma.ProductWhereInput = {
      businessId,
      status: 'ACTIVE',
    };

    if (query.categoryId) where.categoryId = query.categoryId;
    if (query.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { sku: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    const allProducts = await this.prisma.product.findMany({
      where,
      orderBy: { name: 'asc' },
      include: {
        category: { select: { id: true, name: true } },
        unit: { select: { id: true, symbol: true } },
        stockMovements: {
          select: {
            movementType: true,
            quantity: true,
            unitCost: true,
          },
        },
      },
    });

    let totalValuation = new Prisma.Decimal(0);
    let totalStockUnits = 0;
    let lowStockCount = 0;
    let outOfStockCount = 0;

    const computedItems: Array<{
      id: string;
      name: string;
      sku: string | null;
      categoryName: string;
      unitSymbol: string;
      trackStock: boolean;
      minStockLevel: number;
      currentStock: number;
      unitCost: number;
      salePrice: number;
      valuation: number;
      stockStatus: 'IN_STOCK' | 'LOW_STOCK' | 'OUT_OF_STOCK';
    }> = [];

    for (const p of allProducts) {
      let currentStock = 0;
      let totalPurchaseCost = new Prisma.Decimal(0);
      let totalPurchaseQty = new Prisma.Decimal(0);

      for (const m of p.stockMovements) {
        const qty = Number(m.quantity);
        if (['PURCHASE', 'SALE_RETURN', 'ADJUSTMENT_ADD'].includes(m.movementType)) {
          currentStock += qty;
        } else {
          currentStock -= qty;
        }

        if (m.movementType === 'PURCHASE') {
          totalPurchaseCost = totalPurchaseCost.plus(m.quantity.times(m.unitCost));
          totalPurchaseQty = totalPurchaseQty.plus(m.quantity);
        }
      }

      let stockStatus: 'IN_STOCK' | 'LOW_STOCK' | 'OUT_OF_STOCK' = 'IN_STOCK';
      if (p.trackStock) {
        totalStockUnits += currentStock;
        if (currentStock <= 0) {
          stockStatus = 'OUT_OF_STOCK';
          outOfStockCount++;
        } else if (currentStock <= Number(p.minStockLevel)) {
          stockStatus = 'LOW_STOCK';
          lowStockCount++;
        }
      }

      const avgUnitCost = totalPurchaseQty.greaterThan(0)
        ? totalPurchaseCost.dividedBy(totalPurchaseQty)
        : p.purchasePrice;

      const itemValuation = currentStock > 0 ? avgUnitCost.times(currentStock) : new Prisma.Decimal(0);
      totalValuation = totalValuation.plus(itemValuation);

      if (query.status && query.status !== 'ALL') {
        if (query.status !== stockStatus) continue;
      }

      computedItems.push({
        id: p.id,
        name: p.name,
        sku: p.sku,
        categoryName: p.category?.name || 'General',
        unitSymbol: p.unit?.symbol || 'pcs',
        trackStock: p.trackStock,
        minStockLevel: Number(p.minStockLevel),
        currentStock,
        unitCost: Number(avgUnitCost.toFixed(2)),
        salePrice: Number(p.salePrice),
        valuation: Number(itemValuation.toFixed(2)),
        stockStatus,
      });
    }

    const paginatedItems = computedItems.slice(skip, skip + limit);

    return {
      statusCode: 200,
      message: 'Stock summary report generated successfully',
      summary: {
        totalProducts: allProducts.length,
        totalValuation: totalValuation.toNumber(),
        totalStockUnits,
        inStockCount: allProducts.length - lowStockCount - outOfStockCount,
        lowStockCount,
        outOfStockCount,
      },
      meta: {
        page,
        limit,
        total: computedItems.length,
        totalPages: Math.ceil(computedItems.length / limit),
      },
      data: paginatedItems,
    };
  }

  // =========================================================================
  // 8. STOCK MOVEMENT REPORT
  // =========================================================================
  async getStockMovementReport(businessId: string, query: QueryStockMovementReportDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const skip = (page - 1) * limit;

    const where: Prisma.StockMovementWhereInput = { businessId };

    if (query.productId) where.productId = query.productId;
    if (query.movementType) where.movementType = query.movementType as any;

    if (query.startDate || query.endDate) {
      where.createdAt = {};
      if (query.startDate) where.createdAt.gte = new Date(query.startDate);
      if (query.endDate) where.createdAt.lte = new Date(query.endDate);
    }

    const [totalCount, movements] = await Promise.all([
      this.prisma.stockMovement.count({ where }),
      this.prisma.stockMovement.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          product: { select: { id: true, name: true, sku: true, unit: { select: { symbol: true } } } },
          warehouse: { select: { id: true, name: true } },
        },
      }),
    ]);

    return {
      statusCode: 200,
      message: 'Stock movement report generated successfully',
      meta: {
        page,
        limit,
        total: totalCount,
        totalPages: Math.ceil(totalCount / limit),
      },
      data: movements.map((m) => ({
        id: m.id,
        createdAt: m.createdAt.toISOString(),
        productId: m.productId,
        productName: m.product.name,
        sku: m.product.sku,
        unitSymbol: m.product.unit?.symbol || 'pcs',
        warehouseName: m.warehouse.name,
        movementType: m.movementType,
        quantity: Number(m.quantity),
        unitCost: Number(m.unitCost),
        totalCost: Number(m.quantity.times(m.unitCost)),
        referenceType: m.referenceType,
        referenceId: m.referenceId,
        notes: m.notes,
      })),
    };
  }

  // =========================================================================
  // 9. PRODUCT PERFORMANCE REPORT
  // =========================================================================
  async getProductPerformanceReport(businessId: string, query: QueryProductPerformanceDto) {
    const limit = query.limit || 10;
    const dateFilter: Prisma.DateTimeFilter | undefined =
      query.startDate || query.endDate
        ? {
            ...(query.startDate ? { gte: new Date(query.startDate) } : {}),
            ...(query.endDate ? { lte: new Date(query.endDate) } : {}),
          }
        : undefined;

    const invoiceItems = await this.prisma.invoiceItem.findMany({
      where: {
        businessId,
        invoice: {
          status: { not: 'CANCELLED' },
          ...(dateFilter ? { invoiceDate: dateFilter } : {}),
        },
      },
      include: {
        product: { select: { id: true, name: true, sku: true, purchasePrice: true } },
      },
    });

    const perfMap = new Map<
      string,
      {
        productId: string;
        name: string;
        sku: string | null;
        unitsSold: Prisma.Decimal;
        totalRevenue: Prisma.Decimal;
        totalCost: Prisma.Decimal;
      }
    >();

    for (const item of invoiceItems) {
      const pid = item.productId || 'custom_item';
      const name = item.product?.name || item.description;
      const sku = item.product?.sku || null;
      const costPerUnit = item.product?.purchasePrice || new Prisma.Decimal(0);

      const entry = perfMap.get(pid) || {
        productId: pid,
        name,
        sku,
        unitsSold: new Prisma.Decimal(0),
        totalRevenue: new Prisma.Decimal(0),
        totalCost: new Prisma.Decimal(0),
      };

      entry.unitsSold = entry.unitsSold.plus(item.quantity);
      entry.totalRevenue = entry.totalRevenue.plus(item.totalAmount);
      entry.totalCost = entry.totalCost.plus(item.quantity.times(costPerUnit));

      perfMap.set(pid, entry);
    }

    const sorted = Array.from(perfMap.values())
      .sort((a, b) => b.totalRevenue.minus(a.totalRevenue).toNumber())
      .slice(0, limit)
      .map((item) => {
        const grossProfit = item.totalRevenue.minus(item.totalCost);
        const marginPct = item.totalRevenue.greaterThan(0)
          ? grossProfit.dividedBy(item.totalRevenue).times(100).toNumber()
          : 0;

        return {
          productId: item.productId,
          name: item.name,
          sku: item.sku,
          unitsSold: Number(item.unitsSold),
          totalRevenue: Number(item.totalRevenue),
          estimatedCost: Number(item.totalCost),
          estimatedGrossProfit: Number(grossProfit),
          grossMarginPercentage: Number(marginPct.toFixed(1)),
        };
      });

    return {
      statusCode: 200,
      message: 'Product performance report generated successfully',
      data: sorted,
    };
  }

  // =========================================================================
  // 10. TAX & GST SUMMARY REPORT
  // =========================================================================
  async getGstSummaryReport(businessId: string, startDate?: string, endDate?: string) {
    const dateFilter: Prisma.DateTimeFilter | undefined =
      startDate || endDate
        ? {
            ...(startDate ? { gte: new Date(startDate) } : {}),
            ...(endDate ? { lte: new Date(endDate) } : {}),
          }
        : undefined;

    // Outward Tax from Invoices
    const outwardAgg = await this.prisma.invoice.aggregate({
      where: {
        businessId,
        status: { not: 'CANCELLED' },
        ...(dateFilter ? { invoiceDate: dateFilter } : {}),
      },
      _sum: {
        taxableAmount: true,
        cgstAmount: true,
        sgstAmount: true,
        igstAmount: true,
        cessAmount: true,
      },
    });

    // Inward Tax from Purchases (Input Tax Credit)
    const inwardPurchasesAgg = await this.prisma.purchase.aggregate({
      where: {
        businessId,
        status: { not: 'CANCELLED' },
        ...(dateFilter ? { billDate: dateFilter } : {}),
      },
      _sum: {
        subtotal: true,
        taxAmount: true,
      },
    });

    // Inward Tax from Expenses (Eligible GST)
    const inwardExpensesAgg = await this.prisma.expense.aggregate({
      where: {
        businessId,
        isTaxDeductible: true,
        ...(dateFilter ? { date: dateFilter } : {}),
      },
      _sum: {
        gstAmount: true,
      },
    });

    const outwardCgst = outwardAgg._sum.cgstAmount || new Prisma.Decimal(0);
    const outwardSgst = outwardAgg._sum.sgstAmount || new Prisma.Decimal(0);
    const outwardIgst = outwardAgg._sum.igstAmount || new Prisma.Decimal(0);
    const outwardCess = outwardAgg._sum.cessAmount || new Prisma.Decimal(0);
    const totalOutwardTax = outwardCgst.plus(outwardSgst).plus(outwardIgst).plus(outwardCess);

    // Split purchase tax equally into CGST & SGST (standard intra-state assumption for MVP)
    const purchaseTax = inwardPurchasesAgg._sum.taxAmount || new Prisma.Decimal(0);
    const expenseGst = inwardExpensesAgg._sum.gstAmount || new Prisma.Decimal(0);
    const totalInwardItc = purchaseTax.plus(expenseGst);

    const netTaxPayable = totalOutwardTax.minus(totalInwardItc);

    return {
      statusCode: 200,
      message: 'GST statutory preparation summary generated successfully',
      data: {
        startDate: startDate || null,
        endDate: endDate || null,
        outwardSupplies: {
          taxableValue: (outwardAgg._sum.taxableAmount || new Prisma.Decimal(0)).toNumber(),
          cgstAmount: outwardCgst.toNumber(),
          sgstAmount: outwardSgst.toNumber(),
          igstAmount: outwardIgst.toNumber(),
          cessAmount: outwardCess.toNumber(),
          totalOutwardTaxLiability: totalOutwardTax.toNumber(),
        },
        inwardSupplies: {
          purchasesTaxable: (inwardPurchasesAgg._sum.subtotal || new Prisma.Decimal(0)).toNumber(),
          purchasesItc: purchaseTax.toNumber(),
          expensesItc: expenseGst.toNumber(),
          totalEligibleItc: totalInwardItc.toNumber(),
        },
        netGstPayable: netTaxPayable.greaterThan(0) ? netTaxPayable.toNumber() : 0,
        itcCarryForward: netTaxPayable.lessThan(0) ? netTaxPayable.abs().toNumber() : 0,
        disclaimer:
          'This report is a statutory preparation summary generated from AirthAI financial ledgers. All returns must be reviewed and filed by an authorized tax practitioner.',
      },
    };
  }
}
