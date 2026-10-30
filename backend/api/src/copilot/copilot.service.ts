import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { AiProviderService } from './ai-provider.service';
import { QueryCopilotDto } from './dto/query-copilot.dto';
import {
  CopilotResponse,
  CopilotSuggestion,
} from './interfaces/copilot-response.interface';

@Injectable()
export class CopilotService {
  private readonly logger = new Logger(CopilotService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly aiProvider: AiProviderService,
  ) {}

  isAvailable(): boolean {
    return this.aiProvider.isConfigured();
  }

  getSuggestions(): CopilotSuggestion[] {
    return [
      {
        id: 'sug_sales',
        category: 'SALES',
        question: 'How much did my business sell during a selected period?',
      },
      {
        id: 'sug_receivables',
        category: 'RECEIVABLES',
        question: 'Which customers have outstanding payments?',
      },
      {
        id: 'sug_inventory',
        category: 'INVENTORY',
        question: 'Which products are low in stock?',
      },
      {
        id: 'sug_expenses',
        category: 'EXPENSES',
        question: 'What were the major recorded expenses?',
      },
      {
        id: 'sug_trends',
        category: 'TRENDS',
        question: "How do this month's sales compare with the previous month?",
      },
      {
        id: 'sug_review',
        category: 'REVIEW',
        question: 'What business issues should I review based on available records?',
      },
    ];
  }

  async query(businessId: string, queryDto: QueryCopilotDto): Promise<CopilotResponse> {
    const rawQuery = queryDto.query.trim();
    const now = new Date();
    const dataFreshness = now.toISOString();

    // 1. Safety Guard: Read-Only Mutation Interception
    const mutationCheck = this.checkMutationAttempt(rawQuery);
    if (mutationCheck.isMutation) {
      return {
        answer: mutationCheck.message,
        periodAnalyzed: 'N/A',
        dataUsed: [],
        calculationDefinition: 'Mutation Prevention Guard: All write operations are strictly blocked in the Read-Only Copilot.',
        caveats: ['Read-only safety policy strictly enforced. Financial records cannot be created, updated, or deleted via AI.'],
        recommendedNextStep: mutationCheck.nextStep,
        dataFreshness,
        isAvailable: this.aiProvider.isConfigured(),
      };
    }

    // 2. Safety Guard: Prompt Injection & Multi-Tenant Boundaries
    const injectionCheck = this.checkPromptInjection(rawQuery);
    if (injectionCheck.isInjection) {
      return {
        answer: 'I am the AirThai Read-Only Business Copilot. I can only assist with verified business questions grounded in your authorized company records. System instructions, raw database access, and data from other tenants are strictly isolated.',
        periodAnalyzed: 'N/A',
        dataUsed: [],
        calculationDefinition: 'Tenant Isolation and Prompt Boundary Guard.',
        caveats: ['Multi-tenant isolation strictly enforced at the query layer.'],
        recommendedNextStep: 'Ask a question regarding your business sales, receivables, inventory, or expenses.',
        dataFreshness,
        isAvailable: this.aiProvider.isConfigured(),
      };
    }

    // 3. Intent Classification & Deterministic Computation
    const intent = this.classifyIntent(rawQuery);
    const deterministicData = await this.computeDeterministicFigures(businessId, intent, queryDto.period, rawQuery);

    // 4. Grounded Response Generation
    // If AI provider is not configured: Return deterministic summary with clear unavailable status
    if (!this.aiProvider.isConfigured()) {
      return {
        answer: `AI Copilot provider is not configured on the server. Below is the authoritative financial summary computed deterministically from your records:\n\n${deterministicData.summary}`,
        periodAnalyzed: deterministicData.periodAnalyzed,
        dataUsed: deterministicData.dataUsed,
        calculationDefinition: deterministicData.calculationDefinition,
        caveats: [
          'AI provider credentials (OPENAI_API_KEY) are not configured on the server.',
          'Figures shown are authoritative deterministic calculations directly from database records.',
          ...deterministicData.caveats,
        ],
        recommendedNextStep: deterministicData.recommendedNextStep,
        dataFreshness,
        deterministicFigures: deterministicData.figures,
        isAvailable: false,
      };
    }

    // When AI provider IS configured: send strictly tenant-scoped deterministic figures
    try {
      const systemPrompt = `You are the Read-Only AI Business Copilot for AirThai MSME OS.
Your role is to explain business records clearly and accurately.
RULES:
1. Ground your answer ONLY in the authoritative deterministic numbers provided in the user prompt.
2. NEVER invent, hallucinate, or extrapolate financial figures.
3. Never state predictions or estimates as facts.
4. You cannot create, edit, or delete any records.
5. If the user makes an incorrect assumption (e.g. claims sales dropped when they grew), gently correct the premise using the provided data.
6. Return structured text answering the user's question, citing the period, data used, and recommended next steps.`;

      const userPrompt = `User Question: "${rawQuery}"
Period Analyzed: ${deterministicData.periodAnalyzed}
Deterministic Ground-Truth Data:
${JSON.stringify(deterministicData.figures, null, 2)}

Deterministic Calculation Context:
${deterministicData.summary}

Please provide an explainable, polite, and source-grounded response answering the question.`;

      const aiText = await this.aiProvider.generateCompletion({
        systemPrompt,
        userPrompt,
        temperature: 0.1,
      });

      return {
        answer: aiText.trim() || deterministicData.summary,
        periodAnalyzed: deterministicData.periodAnalyzed,
        dataUsed: deterministicData.dataUsed,
        calculationDefinition: deterministicData.calculationDefinition,
        caveats: deterministicData.caveats,
        recommendedNextStep: deterministicData.recommendedNextStep,
        dataFreshness,
        deterministicFigures: deterministicData.figures,
        isAvailable: true,
      };
    } catch (err: any) {
      this.logger.warn(`AI Provider completion failed: ${err.message}. Falling back to deterministic figures.`);
      return {
        answer: `AI Provider is currently unavailable (${err.message}). Authoritative records from your database:\n\n${deterministicData.summary}`,
        periodAnalyzed: deterministicData.periodAnalyzed,
        dataUsed: deterministicData.dataUsed,
        calculationDefinition: deterministicData.calculationDefinition,
        caveats: [
          `AI Provider error: ${err.message}`,
          'All numbers displayed are authoritative figures calculated directly by the AirThai backend.',
          ...deterministicData.caveats,
        ],
        recommendedNextStep: deterministicData.recommendedNextStep,
        dataFreshness,
        deterministicFigures: deterministicData.figures,
        isAvailable: false,
      };
    }
  }

  // --- Internal Safety and Deterministic Helpers ---

  private checkMutationAttempt(query: string): { isMutation: boolean; message: string; nextStep: string } {
    const q = query.toLowerCase();
    const actionWords = ['create', 'add', 'record', 'make', 'pay', 'update', 'delete', 'drop', 'insert', 'alter', 'remove', 'cancel', 'adjust'];
    const entityWords = ['invoice', 'bill', 'payment', 'expense', 'customer', 'supplier', 'product', 'stock', 'entry', 'account', 'table', 'database'];

    const hasAction = actionWords.some((w) => new RegExp(`\\b${w}\\b`).test(q));
    const hasEntity = entityWords.some((w) => new RegExp(`\\b${w}\\b`).test(q));

    if (hasAction && hasEntity && !q.includes('how to') && !q.includes('what were') && !q.includes('which') && !q.includes('how much')) {
      if (q.includes('invoice')) {
        return {
          isMutation: true,
          message: 'The AI Copilot is strictly read-only and cannot create or modify invoices. Please open the Sales screen and select "+ New Invoice" to create an invoice.',
          nextStep: 'Go to Sales -> Create Invoice.',
        };
      }
      if (q.includes('payment') || q.includes('pay')) {
        return {
          isMutation: true,
          message: 'The AI Copilot is strictly read-only and cannot process or record payments. Please use the Payments screen to record customer receipts or supplier disbursements.',
          nextStep: 'Go to Payments -> Record Receipt / Payment.',
        };
      }
      if (q.includes('stock') || q.includes('inventory')) {
        return {
          isMutation: true,
          message: 'The AI Copilot is strictly read-only and cannot adjust physical stock levels. Please use the Inventory screen to record authorized stock adjustments.',
          nextStep: 'Go to Inventory -> Adjust Stock.',
        };
      }
      return {
        isMutation: true,
        message: 'The AI Copilot is strictly read-only and cannot perform data creations, modifications, or deletions. All transactions must be entered through authorized application forms.',
        nextStep: 'Navigate to the relevant section to execute the required action.',
      };
    }

    return { isMutation: false, message: '', nextStep: '' };
  }

  private checkPromptInjection(query: string): { isInjection: boolean } {
    const q = query.toLowerCase();
    const injectionPatterns = [
      /\bignore\s+(all\s+)?(previous|prior|system)\s+instructions\b/,
      /\bsystem\s+prompt\b/,
      /\ball\s+tenants\b/,
      /\bother\s+businesses?\b/,
      /\bbypass\s+(security|auth|guard)\b/,
      /\bjailbreak\b/,
      /\badmin\s+mode\b/,
      /\bselect\s+\*\s+from\b/,
      /\bdrop\s+table\b/,
    ];

    const isInjection = injectionPatterns.some((pattern) => pattern.test(q));
    return { isInjection };
  }

  private classifyIntent(query: string): string {
    const q = query.toLowerCase();
    if (q.includes('compare') || q.includes('previous month') || q.includes('last month') || q.includes('growth') || q.includes('month over month')) {
      return 'MOM_COMPARISON';
    }
    if (q.includes('outstanding') || q.includes('unpaid') || q.includes('receivable') || q.includes('owe') || q.includes('pending payment')) {
      return 'OUTSTANDING_PAYMENTS';
    }
    if (q.includes('low') || q.includes('stock') || q.includes('inventory') || q.includes('reorder') || q.includes('deficit')) {
      return 'LOW_STOCK';
    }
    if (q.includes('expense') || q.includes('spend') || q.includes('spending') || q.includes('cost')) {
      return 'MAJOR_EXPENSES';
    }
    if (q.includes('issue') || q.includes('review') || q.includes('attention') || q.includes('health') || q.includes('problem') || q.includes('alert')) {
      return 'BUSINESS_ISSUES';
    }
    if (q.includes('sell') || q.includes('sale') || q.includes('revenue') || q.includes('invoice') || q.includes('turnover')) {
      return 'SALES_SUMMARY';
    }
    return 'GENERAL';
  }

  private async computeDeterministicFigures(
    businessId: string,
    intent: string,
    periodParam?: string,
    userQuery: string = '',
  ): Promise<{
    summary: string;
    periodAnalyzed: string;
    dataUsed: string[];
    calculationDefinition: string;
    caveats: string[];
    recommendedNextStep: string;
    figures: Record<string, any>;
  }> {
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth();

    // Default period: Current Month
    const startOfCurrentMonth = new Date(currentYear, currentMonth, 1);
    const endOfCurrentMonth = new Date(currentYear, currentMonth + 1, 0, 23, 59, 59, 999);

    switch (intent) {
      case 'SALES_SUMMARY': {
        const invoices = await this.prisma.invoice.findMany({
          where: {
            businessId,
            invoiceDate: { gte: startOfCurrentMonth, lte: endOfCurrentMonth },
            status: { not: 'CANCELLED' },
          },
          select: {
            id: true,
            invoiceNumber: true,
            totalAmount: true,
            subtotal: true,
            cgstAmount: true,
            sgstAmount: true,
            igstAmount: true,
            cessAmount: true,
            balanceAmount: true,
            status: true,
          },
        });

        const invoiceCount = invoices.length;
        const totalSales = invoices.reduce((sum, inv) => sum + Number(inv.totalAmount), 0);
        const subtotal = invoices.reduce((sum, inv) => sum + Number(inv.subtotal), 0);
        const taxAmount = invoices.reduce(
          (sum, inv) =>
            sum +
            Number(inv.cgstAmount ?? 0) +
            Number(inv.sgstAmount ?? 0) +
            Number(inv.igstAmount ?? 0) +
            Number(inv.cessAmount ?? 0),
          0,
        );
        const outstandingAmount = invoices.reduce((sum, inv) => sum + Number(inv.balanceAmount), 0);
        const averageValue = invoiceCount > 0 ? totalSales / invoiceCount : 0;

        const periodLabel = `${startOfCurrentMonth.toISOString().slice(0, 10)} to ${endOfCurrentMonth.toISOString().slice(0, 10)}`;

        if (invoiceCount === 0) {
          return {
            summary: `No sales invoices have been recorded for the period ${periodLabel}. Total recorded sales: ₹0.00 across 0 invoices.`,
            periodAnalyzed: periodLabel,
            dataUsed: ['Sales Invoices (0 records found)'],
            calculationDefinition: 'Total Sales = Sum of totalAmount for active non-cancelled invoices in the period.',
            caveats: ['No issued invoices found in the selected date range.', 'Draft and cancelled invoices are excluded.'],
            recommendedNextStep: 'Generate your first invoice in the Sales tab to start tracking revenue.',
            figures: { totalSales: 0, invoiceCount: 0, averageValue: 0, period: periodLabel },
          };
        }

        return {
          summary: `Total sales for ${periodLabel} reached ₹${totalSales.toFixed(2)} across ${invoiceCount} invoice(s), with an average invoice value of ₹${averageValue.toFixed(2)}. Tax collected: ₹${taxAmount.toFixed(2)}. Remaining uncollected balance: ₹${outstandingAmount.toFixed(2)}.`,
          periodAnalyzed: periodLabel,
          dataUsed: [`${invoiceCount} non-cancelled posted sales invoices`, 'Tax and subtotal breakdown from line items'],
          calculationDefinition: 'Total Sales = Sum(totalAmount) of all non-cancelled invoices issued in the period.',
          caveats: ['Excludes cancelled invoices.', 'Amounts reflect invoiced revenue regardless of whether payment has been collected.'],
          recommendedNextStep: outstandingAmount > 0 ? 'Follow up on uncollected invoice balances in the Payments section.' : 'Maintain customer engagement and track upcoming orders.',
          figures: { totalSales, subtotal, taxAmount, invoiceCount, averageValue, outstandingAmount, period: periodLabel },
        };
      }

      case 'OUTSTANDING_PAYMENTS': {
        const unpaidInvoices = await this.prisma.invoice.findMany({
          where: {
            businessId,
            balanceAmount: { gt: 0 },
            status: { in: ['ISSUED', 'PARTIALLY_PAID'] },
          },
          include: {
            customer: {
              select: { id: true, name: true, phone: true },
            },
          },
          orderBy: { balanceAmount: 'desc' },
        });

        const customerBalances: Record<string, { name: string; balance: number; count: number }> = {};
        let totalReceivables = 0;

        for (const inv of unpaidInvoices) {
          const custId = inv.customer?.id || 'unknown';
          const custName = inv.customer?.name || 'Unknown Customer';
          const bal = Number(inv.balanceAmount);
          totalReceivables += bal;

          if (!customerBalances[custId]) {
            customerBalances[custId] = { name: custName, balance: 0, count: 0 };
          }
          customerBalances[custId].balance += bal;
          customerBalances[custId].count += 1;
        }

        const customerList = Object.values(customerBalances).sort((a, b) => b.balance - a.balance);

        if (customerList.length === 0) {
          return {
            summary: 'All customer accounts are in good standing! There are currently zero outstanding invoice balances.',
            periodAnalyzed: 'All open transactions to date',
            dataUsed: ['Customer Accounts Receivable ledger', 'Active sales invoices with positive balanceAmount'],
            calculationDefinition: 'Outstanding Receivables = Sum of balanceAmount for ISSUED and PARTIALLY_PAID invoices.',
            caveats: ['Unapplied customer advances or credit notes may affect net customer position.'],
            recommendedNextStep: 'Continue issuing timely invoices to maintain healthy cash flow.',
            figures: { totalReceivables: 0, customerCount: 0, customers: [] },
          };
        }

        const topCustomers = customerList.slice(0, 5).map((c) => `${c.name}: ₹${c.balance.toFixed(2)} (${c.count} invoice(s))`).join('; ');
        return {
          summary: `There are ${customerList.length} customer(s) with outstanding balances totaling ₹${totalReceivables.toFixed(2)}. Highest outstanding: ${topCustomers}.`,
          periodAnalyzed: 'All open transactions to date',
          dataUsed: [`${unpaidInvoices.length} unpaid invoices across ${customerList.length} customers`],
          calculationDefinition: 'Customer Outstanding = Sum of remaining balanceAmount across all unpaid/partially paid invoices.',
          caveats: ['Only reflects recorded sales invoices; disputed or offline unrecorded payments are not factored.'],
          recommendedNextStep: 'Send payment reminders to customers with the highest overdue balances.',
          figures: { totalReceivables, customerCount: customerList.length, customers: customerList },
        };
      }

      case 'LOW_STOCK': {
        const trackedProducts = await this.prisma.product.findMany({
          where: {
            businessId,
            trackStock: true,
            status: 'ACTIVE',
          },
          select: {
            id: true,
            sku: true,
            name: true,
            currentStock: true,
            minStockLevel: true,
            salePrice: true,
          },
        });

        const lowStockItems = trackedProducts
          .filter((p) => {
            const threshold = Number(p.minStockLevel) > 0 ? Number(p.minStockLevel) : 10;
            return Number(p.currentStock) <= threshold;
          })
          .sort((a, b) => Number(a.currentStock) - Number(b.currentStock));

        if (lowStockItems.length === 0) {
          return {
            summary: `All ${trackedProducts.length} tracked products currently maintain healthy stock levels above their designated reorder thresholds.`,
            periodAnalyzed: 'Current real-time stock levels',
            dataUsed: [`${trackedProducts.length} active products with trackStock enabled`],
            calculationDefinition: 'Low Stock Condition = currentStock <= minStockLevel (default 10 units).',
            caveats: ['Products with trackStock disabled are excluded from inventory deficit monitoring.'],
            recommendedNextStep: 'Periodically perform physical stock audits to verify inventory accuracy.',
            figures: { totalTracked: trackedProducts.length, lowStockCount: 0, lowStockItems: [] },
          };
        }

        const itemList = lowStockItems.map((p) => {
          const threshold = Number(p.minStockLevel) > 0 ? Number(p.minStockLevel) : 10;
          return `${p.name} (Stock: ${p.currentStock}, Min: ${threshold})`;
        }).join('; ');

        return {
          summary: `${lowStockItems.length} product(s) are at or below their minimum reorder thresholds: ${itemList}.`,
          periodAnalyzed: 'Current real-time stock levels',
          dataUsed: [`${lowStockItems.length} low-stock products out of ${trackedProducts.length} tracked items`],
          calculationDefinition: 'Low Stock Deficit = minStockLevel - currentStock where currentStock <= minStockLevel.',
          caveats: ['Pending supplier purchase bills in draft status do not increment currentStock until confirmed.'],
          recommendedNextStep: 'Create purchase bills in the Purchases section to replenish these inventory items.',
          figures: { totalTracked: trackedProducts.length, lowStockCount: lowStockItems.length, lowStockItems },
        };
      }

      case 'MAJOR_EXPENSES': {
        const expenses = await this.prisma.expense.findMany({
          where: {
            businessId,
            date: { gte: startOfCurrentMonth, lte: endOfCurrentMonth },
          },
          include: {
            category: { select: { id: true, name: true } },
          },
          orderBy: { amount: 'desc' },
        });

        const totalExpenses = expenses.reduce((sum, e) => sum + Number(e.amount), 0);
        const categoryMap: Record<string, number> = {};

        for (const e of expenses) {
          const catName = e.category?.name || 'Uncategorized';
          categoryMap[catName] = (categoryMap[catName] || 0) + Number(e.amount);
        }

        const categoryList = Object.entries(categoryMap)
          .map(([name, amount]) => ({ name, amount, percentage: totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0 }))
          .sort((a, b) => b.amount - a.amount);

        const periodLabel = `${startOfCurrentMonth.toISOString().slice(0, 10)} to ${endOfCurrentMonth.toISOString().slice(0, 10)}`;

        if (expenses.length === 0) {
          return {
            summary: `No business expenses have been recorded for the period ${periodLabel}. Total recorded expenses: ₹0.00.`,
            periodAnalyzed: periodLabel,
            dataUsed: ['Operating expense vouchers (0 records found)'],
            calculationDefinition: 'Total Expenses = Sum of amount across recorded expense entries in the period.',
            caveats: ['Capital expenditures or purchases recorded under supplier bills are tracked under Purchases, not Expenses.'],
            recommendedNextStep: 'Log operating expenses such as rent, utilities, and office supplies in the Expenses tab.',
            figures: { totalExpenses: 0, expenseCount: 0, categories: [] },
          };
        }

        const topCats = categoryList.slice(0, 3).map((c) => `${c.name}: ₹${c.amount.toFixed(2)} (${c.percentage.toFixed(1)}%)`).join(', ');

        return {
          summary: `Total recorded expenses for ${periodLabel} amount to ₹${totalExpenses.toFixed(2)} across ${expenses.length} voucher(s). Top expense categories: ${topCats}.`,
          periodAnalyzed: periodLabel,
          dataUsed: [`${expenses.length} expense vouchers`, 'Expense category master records'],
          calculationDefinition: 'Category Share = (Category Total Expenses / Total Expenses) * 100',
          caveats: ['Cost of Goods Sold (inventory purchases) is tracked separately in the Purchases ledger.'],
          recommendedNextStep: 'Review the largest expense categories for potential cost efficiencies.',
          figures: { totalExpenses, expenseCount: expenses.length, categories: categoryList },
        };
      }

      case 'MOM_COMPARISON': {
        const startOfPrevMonth = new Date(currentYear, currentMonth - 1, 1);
        const endOfPrevMonth = new Date(currentYear, currentMonth, 0, 23, 59, 59, 999);

        const [currInvoices, prevInvoices] = await Promise.all([
          this.prisma.invoice.findMany({
            where: {
              businessId,
              invoiceDate: { gte: startOfCurrentMonth, lte: endOfCurrentMonth },
              status: { not: 'CANCELLED' },
            },
            select: { totalAmount: true },
          }),
          this.prisma.invoice.findMany({
            where: {
              businessId,
              invoiceDate: { gte: startOfPrevMonth, lte: endOfPrevMonth },
              status: { not: 'CANCELLED' },
            },
            select: { totalAmount: true },
          }),
        ]);

        const currSales = currInvoices.reduce((sum, inv) => sum + Number(inv.totalAmount), 0);
        const prevSales = prevInvoices.reduce((sum, inv) => sum + Number(inv.totalAmount), 0);
        const diff = currSales - prevSales;
        const growth = prevSales > 0 ? (diff / prevSales) * 100 : (currSales > 0 ? 100 : 0);

        // Address false premise / incorrect assumptions in user query
        let assumptionNote = '';
        const q = userQuery.toLowerCase();
        if (q.includes('drop') || q.includes('decrease') || q.includes('down')) {
          if (growth >= 0) {
            assumptionNote = `Note: Contrary to the assumption of a decline, sales actually grew by ${growth.toFixed(1)}% compared to last month. `;
          }
        } else if (q.includes('grow') || q.includes('increase') || q.includes('up')) {
          if (growth < 0) {
            assumptionNote = `Note: Sales declined by ${Math.abs(growth).toFixed(1)}% compared to last month. `;
          }
        }

        const summary = `${assumptionNote}Current month sales stand at ₹${currSales.toFixed(2)} (${currInvoices.length} invoice(s)) compared to ₹${prevSales.toFixed(2)} (${prevInvoices.length} invoice(s)) in the previous month. Absolute change: ${diff >= 0 ? '+' : '-'}₹${Math.abs(diff).toFixed(2)} (${growth >= 0 ? '+' : ''}${growth.toFixed(1)}%).`;

        return {
          summary,
          periodAnalyzed: `Current Month vs Previous Month (${startOfPrevMonth.toISOString().slice(0, 10)} to ${endOfCurrentMonth.toISOString().slice(0, 10)})`,
          dataUsed: [`${currInvoices.length} current month invoices`, `${prevInvoices.length} prior month invoices`],
          calculationDefinition: 'Growth % = ((Current Month Sales - Previous Month Sales) / Previous Month Sales) * 100',
          caveats: ['If the current month is still ongoing, figures compare partial month-to-date with a completed prior month.'],
          recommendedNextStep: growth < 0 ? 'Review outstanding quotes and engage existing customers to stimulate sales volume.' : 'Continue successful sales strategies and maintain inventory availability.',
          figures: { currentMonthSales: currSales, previousMonthSales: prevSales, absoluteDiff: diff, growthPercentage: growth },
        };
      }

      case 'BUSINESS_ISSUES':
      default: {
        const [trackedProducts, overdueInvoices, pendingPurchases] = await Promise.all([
          this.prisma.product.findMany({
            where: {
              businessId,
              trackStock: true,
              status: 'ACTIVE',
            },
            select: { id: true, name: true, currentStock: true, minStockLevel: true },
          }),
          this.prisma.invoice.findMany({
            where: {
              businessId,
              balanceAmount: { gt: 0 },
              dueDate: { lt: now },
              status: { in: ['ISSUED', 'PARTIALLY_PAID'] },
            },
            select: { id: true, invoiceNumber: true, balanceAmount: true, dueDate: true },
          }),
          this.prisma.purchase.findMany({
            where: {
              businessId,
              balanceAmount: { gt: 0 },
              status: { not: 'CANCELLED' },
            },
            select: { id: true, billNumber: true, balanceAmount: true },
          }),
        ]);

        const lowStockCount = trackedProducts.filter((p) => {
          const threshold = Number(p.minStockLevel) > 0 ? Number(p.minStockLevel) : 10;
          return Number(p.currentStock) <= threshold;
        }).length;
        const overdueCount = overdueInvoices.length;
        const overdueAmount = overdueInvoices.reduce((sum, inv) => sum + Number(inv.balanceAmount), 0);
        const payableCount = pendingPurchases.length;
        const payableAmount = pendingPurchases.reduce((sum, bill) => sum + Number(bill.balanceAmount), 0);

        const issues: string[] = [];
        if (lowStockCount > 0) issues.push(`${lowStockCount} product(s) are low in stock`);
        if (overdueCount > 0) issues.push(`${overdueCount} customer invoice(s) (₹${overdueAmount.toFixed(2)}) are overdue`);
        if (payableCount > 0) issues.push(`${payableCount} supplier bill(s) (₹${payableAmount.toFixed(2)}) have pending payments`);

        const summary = issues.length > 0
          ? `We identified ${issues.length} operational area(s) needing your review: ${issues.join('; ')}.`
          : 'Great news! No critical operational issues were detected. All products are in stock and all invoices are current.';

        return {
          summary,
          periodAnalyzed: 'Real-time operational records snapshot',
          dataUsed: ['Inventory stock thresholds', 'Customer receivables ageing & due dates', 'Supplier payables ledger'],
          calculationDefinition: 'Operational health scan evaluates low-stock deficits, overdue customer debts, and unpaid supplier obligations.',
          caveats: ['Based exclusively on recorded data in AirThai; unentered receipts or supplier invoices are not evaluated.'],
          recommendedNextStep: overdueCount > 0 ? 'Prioritize collecting overdue receivables to optimize working capital.' : 'Review inventory reorder schedules.',
          figures: { lowStockCount, overdueCount, overdueAmount, payableCount, payableAmount, issues },
        };
      }
    }
  }
}

