import { Injectable, Logger, Optional } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { CacheService } from '../common/cache/cache.service';
import { DashboardPeriod, QueryDashboardDto } from './dto/query-dashboard.dto';

export interface DashboardMetricsResult {
  period: {
    selectedPeriod: string;
    startDate: string;
    endDate: string;
    comparisonStartDate: string;
    comparisonEndDate: string;
  };
  sales: {
    totalSales: number;
    subtotal: number;
    taxAmount: number;
    invoiceCount: number;
    averageInvoiceValue: number;
    previousTotalSales: number;
    growthPercentage: number;
  };
  purchases: {
    totalPurchases: number;
    subtotal: number;
    taxAmount: number;
    purchaseCount: number;
    previousTotalPurchases: number;
    growthPercentage: number;
  };
  expenses: {
    totalExpenses: number;
    gstAmount: number;
    netExpenses: number;
    expenseCount: number;
    previousTotalExpenses: number;
  };
  cashFlow: {
    totalCollections: number;
    totalDisbursements: number;
    netCashFlow: number;
  };
  outstanding: {
    receivables: number;
    payables: number;
    overdueReceivables: number;
    overduePayables: number;
  };
  inventory: {
    totalValuation: number;
    totalProducts: number;
    inStockCount: number;
    lowStockCount: number;
    outOfStockCount: number;
  };
  profitability: {
    grossProfit: number;
    operatingExpenses: number;
    netProfit: number;
    netProfitMargin: number;
    calculationAssumptions: string;
  };
  recentActivity: {
    invoices: Array<{
      id: string;
      invoiceNumber: string;
      customerName: string;
      totalAmount: number;
      balanceAmount: number;
      status: string;
      date: string;
    }>;
    purchases: Array<{
      id: string;
      billNumber: string;
      supplierName: string;
      totalAmount: number;
      balanceAmount: number;
      status: string;
      date: string;
    }>;
    expenses: Array<{
      id: string;
      expenseNumber: string;
      categoryName: string;
      vendor: string | null;
      amount: number;
      date: string;
    }>;
  };
  alerts: Array<{
    id: string;
    type: 'LOW_STOCK' | 'OVERDUE_INVOICES' | 'PENDING_PAYABLES' | 'RECONCILIATION';
    severity: 'warning' | 'error' | 'info' | 'success';
    title: string;
    message: string;
    count?: number;
    amount?: number;
  }>;
}

@Injectable()
export class DashboardService {
  private readonly logger = new Logger(DashboardService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly cacheService?: CacheService,
  ) {}

  /**
   * Resolve start and end dates along with previous comparison period dates.
   */
  private resolveDateRanges(query: QueryDashboardDto): {
    startDate: Date;
    endDate: Date;
    compStartDate: Date;
    compEndDate: Date;
    periodName: string;
  } {
    const now = new Date();
    let startDate: Date;
    let endDate: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

    const period = query.period || DashboardPeriod.THIS_MONTH;

    if (query.startDate && query.endDate) {
      startDate = new Date(query.startDate);
      endDate = new Date(query.endDate);
      const durationMs = endDate.getTime() - startDate.getTime();
      const compEndDate = new Date(startDate.getTime() - 1);
      const compStartDate = new Date(compEndDate.getTime() - durationMs);
      return {
        startDate,
        endDate,
        compStartDate,
        compEndDate,
        periodName: 'Custom Range',
      };
    }

    switch (period) {
      case DashboardPeriod.TODAY: {
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
        const compStartDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 0, 0, 0, 0);
        const compEndDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 23, 59, 59, 999);
        return { startDate, endDate, compStartDate, compEndDate, periodName: 'Today' };
      }
      case DashboardPeriod.THIS_WEEK: {
        const dayOfWeek = now.getDay();
        const diffToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - diffToMonday, 0, 0, 0, 0);
        const compStartDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() - 7, 0, 0, 0, 0);
        const compEndDate = new Date(startDate.getTime() - 1);
        return { startDate, endDate, compStartDate, compEndDate, periodName: 'This Week' };
      }
      case DashboardPeriod.THIS_QUARTER: {
        const currentQuarter = Math.floor(now.getMonth() / 3);
        startDate = new Date(now.getFullYear(), currentQuarter * 3, 1, 0, 0, 0, 0);
        const compStartDate = new Date(now.getFullYear(), (currentQuarter - 1) * 3, 1, 0, 0, 0, 0);
        const compEndDate = new Date(startDate.getTime() - 1);
        return { startDate, endDate, compStartDate, compEndDate, periodName: 'This Quarter' };
      }
      case DashboardPeriod.THIS_YEAR: {
        startDate = new Date(now.getFullYear(), 0, 1, 0, 0, 0, 0);
        const compStartDate = new Date(now.getFullYear() - 1, 0, 1, 0, 0, 0, 0);
        const compEndDate = new Date(startDate.getTime() - 1);
        return { startDate, endDate, compStartDate, compEndDate, periodName: 'This Year' };
      }
      case DashboardPeriod.ALL: {
        startDate = new Date(2000, 0, 1);
        const compStartDate = new Date(1990, 0, 1);
        const compEndDate = new Date(1999, 11, 31);
        return { startDate, endDate, compStartDate, compEndDate, periodName: 'All Time' };
      }
      case DashboardPeriod.THIS_MONTH:
      default: {
        startDate = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
        const compStartDate = new Date(now.getFullYear(), now.getMonth() - 1, 1, 0, 0, 0, 0);
        const compEndDate = new Date(startDate.getTime() - 1);
        return { startDate, endDate, compStartDate, compEndDate, periodName: 'This Month' };
      }
    }
  }

  /**
   * Main dashboard aggregation endpoint.
   * Pulls strictly tenant-isolated data and computes authoritative metrics.
   */
  async getMetrics(businessId: string, query: QueryDashboardDto): Promise<DashboardMetricsResult> {
    const cacheKey = `dashboard:${businessId}:${query.period || 'THIS_MONTH'}:${query.startDate || ''}:${query.endDate || ''}`;
    if (this.cacheService) {
      const cached = await this.cacheService.getJson<DashboardMetricsResult>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    const { startDate, endDate, compStartDate, compEndDate, periodName } = this.resolveDateRanges(query);

    const [
      // 1. Current period sales
      currentSalesAgg,
      // 2. Previous period sales
      prevSalesAgg,
      // 3. Current period purchases
      currentPurchasesAgg,
      // 4. Previous period purchases
      prevPurchasesAgg,
      // 5. Current period expenses
      currentExpensesAgg,
      // 6. Previous period expenses
      prevExpensesAgg,
      // 7. Customer receipts
      collectionsAgg,
      // 8. Supplier disbursements
      disbursementsAgg,
      // 9. Outstanding customer receivables
      customerReceivables,
      // 10. Outstanding supplier payables
      supplierPayables,
      // 11. Overdue invoices
      overdueInvoicesAgg,
      // 12. Active products for inventory metrics
      products,
      // 13. Recent Invoices
      recentInvoices,
      // 14. Recent Purchases
      recentPurchases,
      // 15. Recent Expenses
      recentExpenses,
    ] = await Promise.all([
      // 1. Sales current
      this.prisma.invoice.aggregate({
        where: {
          businessId,
          invoiceDate: { gte: startDate, lte: endDate },
          status: { not: 'CANCELLED' },
        },
        _sum: {
          totalAmount: true,
          subtotal: true,
          cgstAmount: true,
          sgstAmount: true,
          igstAmount: true,
        },
        _count: { id: true },
      }),

      // 2. Sales previous
      this.prisma.invoice.aggregate({
        where: {
          businessId,
          invoiceDate: { gte: compStartDate, lte: compEndDate },
          status: { not: 'CANCELLED' },
        },
        _sum: { totalAmount: true },
      }),

      // 3. Purchases current
      this.prisma.purchase.aggregate({
        where: {
          businessId,
          billDate: { gte: startDate, lte: endDate },
          status: { not: 'CANCELLED' },
        },
        _sum: {
          totalAmount: true,
          subtotal: true,
          taxAmount: true,
        },
        _count: { id: true },
      }),

      // 4. Purchases previous
      this.prisma.purchase.aggregate({
        where: {
          businessId,
          billDate: { gte: compStartDate, lte: compEndDate },
          status: { not: 'CANCELLED' },
        },
        _sum: { totalAmount: true },
      }),

      // 5. Expenses current
      this.prisma.expense.aggregate({
        where: {
          businessId,
          date: { gte: startDate, lte: endDate },
        },
        _sum: {
          amount: true,
          gstAmount: true,
        },
        _count: { id: true },
      }),

      // 6. Expenses previous
      this.prisma.expense.aggregate({
        where: {
          businessId,
          date: { gte: compStartDate, lte: compEndDate },
        },
        _sum: { amount: true },
      }),

      // 7. Customer receipts
      this.prisma.payment.aggregate({
        where: {
          businessId,
          paymentType: 'CUSTOMER_RECEIPT',
          paymentDate: { gte: startDate, lte: endDate },
        },
        _sum: { amount: true },
      }),

      // 8. Supplier disbursements
      this.prisma.payment.aggregate({
        where: {
          businessId,
          paymentType: 'SUPPLIER_PAYMENT',
          paymentDate: { gte: startDate, lte: endDate },
        },
        _sum: { amount: true },
      }),

      // 9. Customers balance
      this.prisma.customer.aggregate({
        where: { businessId, status: 'ACTIVE' },
        _sum: { currentBalance: true },
      }),

      // 10. Suppliers balance
      this.prisma.supplier.aggregate({
        where: { businessId, status: 'ACTIVE' },
        _sum: { currentBalance: true },
      }),

      // 11. Overdue invoices (due date earlier than today and balance > 0)
      this.prisma.invoice.aggregate({
        where: {
          businessId,
          status: { in: ['ISSUED', 'PARTIALLY_PAID'] },
          dueDate: { lt: new Date() },
          balanceAmount: { gt: 0 },
        },
        _sum: { balanceAmount: true },
        _count: { id: true },
      }),

      // 12. Active products with stock movements
      this.prisma.product.findMany({
        where: { businessId, status: 'ACTIVE' },
        select: {
          id: true,
          minStockLevel: true,
          purchasePrice: true,
          trackStock: true,
          stockMovements: {
            select: {
              movementType: true,
              quantity: true,
              unitCost: true,
            },
          },
        },
      }),

      // 13. Recent Invoices
      this.prisma.invoice.findMany({
        where: { businessId },
        take: 5,
        orderBy: { invoiceDate: 'desc' },
        include: { customer: { select: { name: true } } },
      }),

      // 14. Recent Purchases
      this.prisma.purchase.findMany({
        where: { businessId },
        take: 5,
        orderBy: { billDate: 'desc' },
        include: { supplier: { select: { name: true } } },
      }),

      // 15. Recent Expenses
      this.prisma.expense.findMany({
        where: { businessId },
        take: 5,
        orderBy: { date: 'desc' },
        include: { category: { select: { name: true } } },
      }),
    ]);

    // Parse Sales Numbers
    const totalSalesDec = currentSalesAgg._sum.totalAmount || new Prisma.Decimal(0);
    const subtotalSalesDec = currentSalesAgg._sum.subtotal || new Prisma.Decimal(0);
    const totalTaxDec = (currentSalesAgg._sum.cgstAmount || new Prisma.Decimal(0))
      .plus(currentSalesAgg._sum.sgstAmount || new Prisma.Decimal(0))
      .plus(currentSalesAgg._sum.igstAmount || new Prisma.Decimal(0));
    const invoiceCount = currentSalesAgg._count.id;
    const avgInvoiceValue = invoiceCount > 0 ? totalSalesDec.dividedBy(invoiceCount).toNumber() : 0;
    const prevSalesDec = prevSalesAgg._sum.totalAmount || new Prisma.Decimal(0);
    const salesGrowth = prevSalesDec.isZero()
      ? (totalSalesDec.isZero() ? 0 : 100)
      : totalSalesDec.minus(prevSalesDec).dividedBy(prevSalesDec).times(100).toNumber();

    // Parse Purchases Numbers
    const totalPurchasesDec = currentPurchasesAgg._sum.totalAmount || new Prisma.Decimal(0);
    const subtotalPurchasesDec = currentPurchasesAgg._sum.subtotal || new Prisma.Decimal(0);
    const purchaseTaxDec = currentPurchasesAgg._sum.taxAmount || new Prisma.Decimal(0);
    const purchaseCount = currentPurchasesAgg._count.id;
    const prevPurchasesDec = prevPurchasesAgg._sum.totalAmount || new Prisma.Decimal(0);
    const purchaseGrowth = prevPurchasesDec.isZero()
      ? (totalPurchasesDec.isZero() ? 0 : 100)
      : totalPurchasesDec.minus(prevPurchasesDec).dividedBy(prevPurchasesDec).times(100).toNumber();

    // Parse Expenses Numbers
    const totalExpensesDec = currentExpensesAgg._sum.amount || new Prisma.Decimal(0);
    const expenseGstDec = currentExpensesAgg._sum.gstAmount || new Prisma.Decimal(0);
    const netExpensesDec = totalExpensesDec.minus(expenseGstDec);
    const expenseCount = currentExpensesAgg._count.id;
    const prevExpensesDec = prevExpensesAgg._sum.amount || new Prisma.Decimal(0);

    // Parse Cash Flow Numbers
    const collectionsDec = collectionsAgg._sum.amount || new Prisma.Decimal(0);
    const disbursementsDec = disbursementsAgg._sum.amount || new Prisma.Decimal(0);
    const netCashFlowDec = collectionsDec.minus(disbursementsDec);

    // Parse Outstanding Balances
    const receivablesDec = customerReceivables._sum.currentBalance || new Prisma.Decimal(0);
    const payablesDec = supplierPayables._sum.currentBalance || new Prisma.Decimal(0);
    const overdueReceivablesDec = overdueInvoicesAgg._sum.balanceAmount || new Prisma.Decimal(0);

    // Compute Inventory Metrics
    let totalStockQty = 0;
    let lowStockCount = 0;
    let outOfStockCount = 0;
    let totalValuationDec = new Prisma.Decimal(0);

    for (const p of products) {
      if (!p.trackStock) continue;
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

      totalStockQty += currentStock;
      if (currentStock <= 0) {
        outOfStockCount++;
      } else if (currentStock <= Number(p.minStockLevel)) {
        lowStockCount++;
      }

      const avgUnitCost = totalPurchaseQty.greaterThan(0)
        ? totalPurchaseCost.dividedBy(totalPurchaseQty)
        : p.purchasePrice;

      if (currentStock > 0) {
        totalValuationDec = totalValuationDec.plus(avgUnitCost.times(currentStock));
      }
    }

    // Profitability Indicators (Authoritative Accrual Definitions)
    // Revenue (Net Sales excluding GST) - COGS (Estimated from Purchases Subtotal or Products) = Gross Profit
    // Gross Profit - Operating Expenses (Net excluding GST) = Net Profit
    const revenueDec = subtotalSalesDec;
    const cogsDec = subtotalPurchasesDec;
    const grossProfitDec = revenueDec.minus(cogsDec);
    const operatingExpensesDec = netExpensesDec;
    const netProfitDec = grossProfitDec.minus(operatingExpensesDec);
    const netMargin = revenueDec.isZero()
      ? 0
      : netProfitDec.dividedBy(revenueDec).times(100).toNumber();

    // Formulate Alerts
    const alerts: DashboardMetricsResult['alerts'] = [];

    if (lowStockCount > 0) {
      alerts.push({
        id: 'alert-low-stock',
        type: 'LOW_STOCK',
        severity: 'warning',
        title: 'Low Stock Alert',
        message: `${lowStockCount} product${lowStockCount > 1 ? 's are' : ' is'} at or below minimum threshold. Reorder soon to prevent stockouts.`,
        count: lowStockCount,
      });
    }

    if (overdueInvoicesAgg._count.id > 0) {
      alerts.push({
        id: 'alert-overdue-invoices',
        type: 'OVERDUE_INVOICES',
        severity: 'error',
        title: 'Overdue Invoices Alert',
        message: `${overdueInvoicesAgg._count.id} invoice${overdueInvoicesAgg._count.id > 1 ? 's are' : ' is'} past due date. Total overdue amount: ₹${overdueReceivablesDec.toFixed(2)}.`,
        count: overdueInvoicesAgg._count.id,
        amount: overdueReceivablesDec.toNumber(),
      });
    }

    if (payablesDec.greaterThan(0)) {
      alerts.push({
        id: 'alert-pending-payables',
        type: 'PENDING_PAYABLES',
        severity: 'info',
        title: 'Outstanding Supplier Payables',
        message: `Total pending payables across suppliers stand at ₹${payablesDec.toFixed(2)}.`,
        amount: payablesDec.toNumber(),
      });
    }

    const result: DashboardMetricsResult = {
      period: {
        selectedPeriod: periodName,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        comparisonStartDate: compStartDate.toISOString(),
        comparisonEndDate: compEndDate.toISOString(),
      },
      sales: {
        totalSales: totalSalesDec.toNumber(),
        subtotal: subtotalSalesDec.toNumber(),
        taxAmount: totalTaxDec.toNumber(),
        invoiceCount,
        averageInvoiceValue: Number(avgInvoiceValue.toFixed(2)),
        previousTotalSales: prevSalesDec.toNumber(),
        growthPercentage: Number(salesGrowth.toFixed(1)),
      },
      purchases: {
        totalPurchases: totalPurchasesDec.toNumber(),
        subtotal: subtotalPurchasesDec.toNumber(),
        taxAmount: purchaseTaxDec.toNumber(),
        purchaseCount,
        previousTotalPurchases: prevPurchasesDec.toNumber(),
        growthPercentage: Number(purchaseGrowth.toFixed(1)),
      },
      expenses: {
        totalExpenses: totalExpensesDec.toNumber(),
        gstAmount: expenseGstDec.toNumber(),
        netExpenses: netExpensesDec.toNumber(),
        expenseCount,
        previousTotalExpenses: prevExpensesDec.toNumber(),
      },
      cashFlow: {
        totalCollections: collectionsDec.toNumber(),
        totalDisbursements: disbursementsDec.toNumber(),
        netCashFlow: netCashFlowDec.toNumber(),
      },
      outstanding: {
        receivables: receivablesDec.toNumber(),
        payables: payablesDec.toNumber(),
        overdueReceivables: overdueReceivablesDec.toNumber(),
        overduePayables: payablesDec.toNumber(),
      },
      inventory: {
        totalValuation: totalValuationDec.toNumber(),
        totalProducts: products.length,
        inStockCount: products.length - lowStockCount - outOfStockCount,
        lowStockCount,
        outOfStockCount,
      },
      profitability: {
        grossProfit: grossProfitDec.toNumber(),
        operatingExpenses: operatingExpensesDec.toNumber(),
        netProfit: netProfitDec.toNumber(),
        netProfitMargin: Number(netMargin.toFixed(1)),
        calculationAssumptions:
          'Accrual Basis: Gross Profit = Sales Subtotal - Purchases Subtotal. Net Profit = Gross Profit - Net Operating Expenses (excl. input GST). Excludes tax liabilities and cash collection timing.',
      },
      recentActivity: {
        invoices: recentInvoices.map((inv) => ({
          id: inv.id,
          invoiceNumber: inv.invoiceNumber,
          customerName: inv.customer?.name || 'Walk-in Customer',
          totalAmount: Number(inv.totalAmount),
          balanceAmount: Number(inv.balanceAmount),
          status: inv.status,
          date: inv.invoiceDate.toISOString(),
        })),
        purchases: recentPurchases.map((p) => ({
          id: p.id,
          billNumber: p.billNumber,
          supplierName: p.supplier?.name || 'Supplier',
          totalAmount: Number(p.totalAmount),
          balanceAmount: Number(p.balanceAmount),
          status: p.status,
          date: p.billDate.toISOString(),
        })),
        expenses: recentExpenses.map((e) => ({
          id: e.id,
          expenseNumber: e.expenseNumber,
          categoryName: e.category?.name || 'General Expense',
          vendor: e.vendor,
          amount: Number(e.amount),
          date: e.date.toISOString(),
        })),
      },
      alerts,
    };

    if (this.cacheService) {
      // 120-second cache TTL for dashboard aggregation
      await this.cacheService.setJson(cacheKey, result, 120);
    }

    return result;
  }

  async invalidateDashboardCache(businessId: string): Promise<void> {
    if (this.cacheService) {
      await this.cacheService.delByPrefix(`dashboard:${businessId}`);
    }
  }
}
