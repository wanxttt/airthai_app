import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/reports_service.dart';
import '../../models/report_models.dart';
import '../../../accounting/presentation/screens/accounting_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selected sub-report index (0 to 10)
  int _selectedReportIndex = 0;

  bool _isLoading = false;
  String? _errorMessage;

  // Report Data States
  SalesReportModel? _salesReport;
  PurchaseReportModel? _purchasesReport;
  ExpenseReportModel? _expensesReport;
  PaymentsReportModel? _paymentsReport;
  ReceivablesAgeingReportModel? _receivablesAgeing;
  PayablesAgeingReportModel? _payablesAgeing;
  StockSummaryReportModel? _stockSummary;
  StockMovementReportModel? _stockMovements;
  List<ProductPerformanceItem> _productPerformance = [];
  GstSummaryReportModel? _gstSummary;

  final List<String> _reportTitles = const [
    'Sales Report',
    'Purchase Report',
    'Expense Report',
    'Payments & Cash Flow',
    'Receivables Ageing',
    'Payables Ageing',
    'Stock Valuation',
    'Stock Movements',
    'Product Performance',
    'Tax & GST Summary',
    'General Ledger & Accounts',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _reportTitles.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _selectedReportIndex != _tabController.index) {
        setState(() {
          _selectedReportIndex = _tabController.index;
        });
        _loadCurrentReport();
      }
    });
    _loadCurrentReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (_selectedReportIndex) {
        case 0:
          final res = await ReportsService.instance.getSalesReport();
          if (res.isSuccess) _salesReport = res.data;
          break;
        case 1:
          final res = await ReportsService.instance.getPurchasesReport();
          if (res.isSuccess) _purchasesReport = res.data;
          break;
        case 2:
          final res = await ReportsService.instance.getExpensesReport();
          if (res.isSuccess) _expensesReport = res.data;
          break;
        case 3:
          final res = await ReportsService.instance.getPaymentsReport();
          if (res.isSuccess) _paymentsReport = res.data;
          break;
        case 4:
          final res = await ReportsService.instance.getReceivablesAgeing();
          if (res.isSuccess) _receivablesAgeing = res.data;
          break;
        case 5:
          final res = await ReportsService.instance.getPayablesAgeing();
          if (res.isSuccess) _payablesAgeing = res.data;
          break;
        case 6:
          final res = await ReportsService.instance.getStockSummary();
          if (res.isSuccess) _stockSummary = res.data;
          break;
        case 7:
          final res = await ReportsService.instance.getStockMovements();
          if (res.isSuccess) _stockMovements = res.data;
          break;
        case 8:
          final res = await ReportsService.instance.getProductPerformance();
          if (res.isSuccess) _productPerformance = res.data ?? [];
          break;
        case 9:
          final res = await ReportsService.instance.getGstSummary();
          if (res.isSuccess) _gstSummary = res.data;
          break;
        case 10:
          // Embedded accounting view
          break;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header & Report Category Tabs
          _buildHeader(),
          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _buildSelectedReportView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Reports & Intelligence',
                      style: AppTextStyles.headingLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Authoritative metrics reconciled directly against financial and inventory ledgers.',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadCurrentReport,
                tooltip: 'Refresh Report',
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
            tabs: _reportTitles.map((title) => Tab(text: title)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text('Failed to load report data', style: AppTextStyles.title),
          const SizedBox(height: 4),
          Text(_errorMessage ?? 'Unknown error', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadCurrentReport,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedReportView() {
    switch (_selectedReportIndex) {
      case 0:
        return _buildSalesReportView();
      case 1:
        return _buildPurchasesReportView();
      case 2:
        return _buildExpensesReportView();
      case 3:
        return _buildPaymentsReportView();
      case 4:
        return _buildReceivablesAgeingView();
      case 5:
        return _buildPayablesAgeingView();
      case 6:
        return _buildStockSummaryView();
      case 7:
        return _buildStockMovementsView();
      case 8:
        return _buildProductPerformanceView();
      case 9:
        return _buildGstSummaryView();
      case 10:
        return const AccountingScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  // =========================================================================
  // 1. SALES REPORT VIEW
  // =========================================================================
  Widget _buildSalesReportView() {
    final report = _salesReport;
    if (report == null) return const Center(child: Text('No sales data available'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid([
            _MetricCardData('Total Invoiced', '₹${report.summary.totalInvoiced.toStringAsFixed(2)}', Icons.receipt_long, AppColors.primary),
            _MetricCardData('Total Collections', '₹${report.summary.totalReceived.toStringAsFixed(2)}', Icons.check_circle_outline, AppColors.success),
            _MetricCardData('Outstanding Receivables', '₹${report.summary.totalOutstanding.toStringAsFixed(2)}', Icons.pending_actions, AppColors.warning),
            _MetricCardData('Total GST Collected', '₹${report.summary.totalTax.toStringAsFixed(2)}', Icons.account_balance, AppColors.primary),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Invoiced Commercial Transactions (${report.items.length})'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Invoice #', 'Date', 'Customer', 'Subtotal', 'Tax', 'Total', 'Paid', 'Status'],
            rows: report.items.map((i) => [
              Text(i.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(i.invoiceDate.split('T').first),
              Text(i.customerName),
              Text('₹${i.subtotal.toStringAsFixed(2)}'),
              Text('₹${i.taxAmount.toStringAsFixed(2)}'),
              Text('₹${i.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${i.receivedAmount.toStringAsFixed(2)}', style: TextStyle(color: i.balanceAmount == 0 ? AppColors.success : AppColors.textPrimary)),
              _buildStatusBadge(i.status),
            ]).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. PURCHASES REPORT VIEW
  // =========================================================================
  Widget _buildPurchasesReportView() {
    final report = _purchasesReport;
    if (report == null) return const Center(child: Text('No purchase data available'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid([
            _MetricCardData('Total Purchases', '₹${report.summary.totalPurchased.toStringAsFixed(2)}', Icons.shopping_bag_outlined, AppColors.primary),
            _MetricCardData('Total Paid', '₹${report.summary.totalPaid.toStringAsFixed(2)}', Icons.payments_outlined, AppColors.success),
            _MetricCardData('Outstanding Payables', '₹${report.summary.totalOutstanding.toStringAsFixed(2)}', Icons.timer_outlined, AppColors.error),
            _MetricCardData('Input GST Paid', '₹${report.summary.totalTax.toStringAsFixed(2)}', Icons.receipt_outlined, AppColors.primary),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Purchase Bills & Vendor Inward (${report.items.length})'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Bill #', 'Date', 'Supplier', 'Subtotal', 'Tax', 'Total', 'Balance', 'Status'],
            rows: report.items.map((p) => [
              Text(p.billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(p.billDate.split('T').first),
              Text(p.supplierName),
              Text('₹${p.subtotal.toStringAsFixed(2)}'),
              Text('₹${p.taxAmount.toStringAsFixed(2)}'),
              Text('₹${p.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${p.balanceAmount.toStringAsFixed(2)}'),
              _buildStatusBadge(p.paymentStatus),
            ]).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. EXPENSES REPORT VIEW
  // =========================================================================
  Widget _buildExpensesReportView() {
    final report = _expensesReport;
    if (report == null) return const Center(child: Text('No expenses recorded'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid([
            _MetricCardData('Gross Expenses', '₹${report.summary.totalExpenses.toStringAsFixed(2)}', Icons.account_balance_wallet, AppColors.primary),
            _MetricCardData('Input GST Amount', '₹${report.summary.gstAmount.toStringAsFixed(2)}', Icons.percent, AppColors.primary),
            _MetricCardData('Net Operating Expense', '₹${report.summary.netExpenses.toStringAsFixed(2)}', Icons.trending_down, AppColors.error),
            _MetricCardData('Expense Vouchers', '${report.summary.expenseCount}', Icons.tag, AppColors.textPrimary),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Category Breakdown'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: report.categoryBreakdown.map((cat) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat.categoryName, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('₹${cat.amount.toStringAsFixed(2)} (${cat.percentage}%)', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Expense Items (${report.items.length})'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Voucher #', 'Date', 'Category', 'Vendor', 'Amount', 'GST', 'Method'],
            rows: report.items.map((e) => [
              Text(e.expenseNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(e.date.split('T').first),
              Text(e.categoryName),
              Text(e.vendor ?? '-'),
              Text('₹${e.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${e.gstAmount.toStringAsFixed(2)}'),
              Text(e.paymentMethod),
            ]).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. PAYMENTS & CASH FLOW VIEW
  // =========================================================================
  Widget _buildPaymentsReportView() {
    final report = _paymentsReport;
    if (report == null) return const Center(child: Text('No payment transactions recorded'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid([
            _MetricCardData('Customer Collections', '₹${report.summary.totalReceipts.toStringAsFixed(2)}', Icons.arrow_downward, AppColors.success),
            _MetricCardData('Supplier Disbursements', '₹${report.summary.totalDisbursements.toStringAsFixed(2)}', Icons.arrow_upward, AppColors.error),
            _MetricCardData('Net Cash Flow', '₹${report.summary.netCashFlow.toStringAsFixed(2)}', Icons.account_balance, report.summary.netCashFlow >= 0 ? AppColors.success : AppColors.error),
            _MetricCardData('Settled Transactions', '${report.summary.receiptsCount + report.summary.disbursementsCount}', Icons.swap_horiz, AppColors.primary),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Recent Cash & Bank Settlements (${report.items.length})'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Payment #', 'Date', 'Type', 'Party', 'Method', 'Amount'],
            rows: report.items.map((p) => [
              Text(p.paymentNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(p.paymentDate.split('T').first),
              Text(p.paymentType == 'CUSTOMER_RECEIPT' ? 'Customer Receipt' : 'Supplier Payment'),
              Text(p.partyName),
              Text(p.paymentMethod),
              Text('₹${p.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: p.paymentType == 'CUSTOMER_RECEIPT' ? AppColors.success : AppColors.error)),
            ]).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. RECEIVABLES AGEING VIEW
  // =========================================================================
  Widget _buildReceivablesAgeingView() {
    final report = _receivablesAgeing;
    if (report == null) return const Center(child: Text('No receivables recorded'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid([
            _MetricCardData('Current (0-30 Days)', '₹${report.summary.bucket0to30.toStringAsFixed(2)}', Icons.schedule, AppColors.success),
            _MetricCardData('31 - 60 Days', '₹${report.summary.bucket31to60.toStringAsFixed(2)}', Icons.update, AppColors.warning),
            _MetricCardData('61 - 90 Days', '₹${report.summary.bucket61to90.toStringAsFixed(2)}', Icons.warning_amber, Colors.orange),
            _MetricCardData('90+ Days (Severe)', '₹${report.summary.bucket90Plus.toStringAsFixed(2)}', Icons.error, AppColors.error),
          ]),
          const SizedBox(height: 16),
          // Reconciliation Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: report.summary.isReconciled ? AppColors.success.withValues(alpha: 0.08) : AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: report.summary.isReconciled ? AppColors.success : AppColors.error),
            ),
            child: Row(
              children: [
                Icon(report.summary.isReconciled ? Icons.verified_user : Icons.warning_rounded, color: report.summary.isReconciled ? AppColors.success : AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    report.summary.isReconciled
                        ? 'Reconciled: Customer Ledger Total (₹${report.summary.totalCustomerLedgerBalances.toStringAsFixed(2)}) perfectly reconciles with General Ledger Control (1100: ₹${report.summary.glControlAccountBalance.toStringAsFixed(2)}).'
                        : 'Reconciliation Warning: Discrepancy of ₹${report.summary.discrepancy.toStringAsFixed(2)} detected between sub-ledger and control account.',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Customer Ageing Analysis (${report.customers.length})'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Customer', 'Total Balance', '0-30 Days', '31-60 Days', '61-90 Days', '90+ Days', 'Unpaid Invoices'],
            rows: report.customers.map((c) => [
              Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${c.ledgerBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${c.bucket0to30.toStringAsFixed(2)}'),
              Text('₹${c.bucket31to60.toStringAsFixed(2)}'),
              Text('₹${c.bucket61to90.toStringAsFixed(2)}'),
              Text('₹${c.bucket90Plus.toStringAsFixed(2)}', style: TextStyle(color: c.bucket90Plus > 0 ? AppColors.error : AppColors.textPrimary)),
              Text('${c.unpaidInvoicesCount}'),
            ]).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. PAYABLES AGEING VIEW
  // =========================================================================
  Widget _buildPayablesAgeingView() {
    final report = _payablesAgeing;
    if (report == null) return const Center(child: Text('No payables recorded'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid([
            _MetricCardData('Current (0-30 Days)', '₹${report.summary.bucket0to30.toStringAsFixed(2)}', Icons.schedule, AppColors.success),
            _MetricCardData('31 - 60 Days', '₹${report.summary.bucket31to60.toStringAsFixed(2)}', Icons.update, AppColors.warning),
            _MetricCardData('61 - 90 Days', '₹${report.summary.bucket61to90.toStringAsFixed(2)}', Icons.warning_amber, Colors.orange),
            _MetricCardData('90+ Days', '₹${report.summary.bucket90Plus.toStringAsFixed(2)}', Icons.error, AppColors.error),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Supplier Payables Ageing (${report.suppliers.length})'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Supplier', 'Total Balance', '0-30 Days', '31-60 Days', '61-90 Days', '90+ Days', 'Unpaid Bills'],
            rows: report.suppliers.map((s) => [
              Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${s.ledgerBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${s.bucket0to30.toStringAsFixed(2)}'),
              Text('₹${s.bucket31to60.toStringAsFixed(2)}'),
              Text('₹${s.bucket61to90.toStringAsFixed(2)}'),
              Text('₹${s.bucket90Plus.toStringAsFixed(2)}', style: TextStyle(color: s.bucket90Plus > 0 ? AppColors.error : AppColors.textPrimary)),
              Text('${s.unpaidBillsCount}'),
            ]).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 7. STOCK SUMMARY VIEW
  // =========================================================================
  Widget _buildStockSummaryView() {
    final report = _stockSummary;
    if (report == null) return const Center(child: Text('No stock data available'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid([
            _MetricCardData('Inventory Valuation', '₹${report.summary.totalValuation.toStringAsFixed(2)}', Icons.inventory, AppColors.primary),
            _MetricCardData('Total Stock Units', '${report.summary.totalStockUnits}', Icons.warehouse, AppColors.primary),
            _MetricCardData('Low Stock Items', '${report.summary.lowStockCount}', Icons.warning_amber_rounded, AppColors.warning),
            _MetricCardData('Out of Stock', '${report.summary.outOfStockCount}', Icons.remove_circle_outline, AppColors.error),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Inventory Valuation & Stock Status (${report.items.length})'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Product', 'SKU', 'Category', 'Stock Qty', 'Unit Cost', 'Valuation', 'Status'],
            rows: report.items.map((p) => [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(p.sku ?? '-'),
              Text(p.categoryName),
              Text('${p.currentStock.toStringAsFixed(1)} ${p.unitSymbol}'),
              Text('₹${p.unitCost.toStringAsFixed(2)}'),
              Text('₹${p.valuation.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              _buildStatusBadge(p.stockStatus),
            ]).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 8. STOCK MOVEMENTS VIEW
  // =========================================================================
  Widget _buildStockMovementsView() {
    final report = _stockMovements;
    if (report == null) return const Center(child: Text('No stock movements recorded'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Stock Audit Trail & Movements (${report.items.length})'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Date', 'Product', 'SKU', 'Movement Type', 'Quantity', 'Unit Cost', 'Total Cost', 'Warehouse'],
            rows: report.items.map((m) => [
              Text(m.createdAt.split('T').first),
              Text(m.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(m.sku ?? '-'),
              _buildStatusBadge(m.movementType),
              Text('${m.quantity.toStringAsFixed(1)} ${m.unitSymbol}'),
              Text('₹${m.unitCost.toStringAsFixed(2)}'),
              Text('₹${m.totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(m.warehouseName),
            ]).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 9. PRODUCT PERFORMANCE VIEW
  // =========================================================================
  Widget _buildProductPerformanceView() {
    final items = _productPerformance;
    if (items.isEmpty) return const Center(child: Text('No product performance data available'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Top Selling Products by Revenue'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Product', 'Units Sold', 'Total Revenue', 'Est. Cost', 'Gross Profit', 'Margin %'],
            rows: items.map((p) => [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${p.unitsSold.toStringAsFixed(1)}'),
              Text('₹${p.totalRevenue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${p.estimatedCost.toStringAsFixed(2)}'),
              Text('₹${p.estimatedGrossProfit.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
              Text('${p.grossMarginPercentage}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 10. GST SUMMARY VIEW
  // =========================================================================
  Widget _buildGstSummaryView() {
    final report = _gstSummary;
    if (report == null) return const Center(child: Text('No GST summary available'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid([
            _MetricCardData('Outward Tax Liability', '₹${report.outwardSupplies.totalOutwardTaxLiability.toStringAsFixed(2)}', Icons.arrow_upward, AppColors.error),
            _MetricCardData('Eligible Input Tax Credit', '₹${report.inwardSupplies.totalEligibleItc.toStringAsFixed(2)}', Icons.arrow_downward, AppColors.success),
            _MetricCardData('Net Tax Payable', '₹${report.netGstPayable.toStringAsFixed(2)}', Icons.account_balance, AppColors.primary),
            _MetricCardData('ITC Carry Forward', '₹${report.itcCarryForward.toStringAsFixed(2)}', Icons.savings, AppColors.primary),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Statutory Outward Tax Breakdown'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Component', 'CGST', 'SGST', 'IGST', 'Cess', 'Total Outward Tax'],
            rows: [
              [
                const Text('Sales Invoices', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${report.outwardSupplies.cgstAmount.toStringAsFixed(2)}'),
                Text('₹${report.outwardSupplies.sgstAmount.toStringAsFixed(2)}'),
                Text('₹${report.outwardSupplies.igstAmount.toStringAsFixed(2)}'),
                Text('₹${report.outwardSupplies.cessAmount.toStringAsFixed(2)}'),
                Text('₹${report.outwardSupplies.totalOutwardTaxLiability.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Statutory Inward ITC Breakdown'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Source', 'Taxable Amount', 'ITC Eligible'],
            rows: [
              [
                const Text('Purchase Bills', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${report.inwardSupplies.purchasesTaxable.toStringAsFixed(2)}'),
                Text('₹${report.inwardSupplies.purchasesItc.toStringAsFixed(2)}'),
              ],
              [
                const Text('Business Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('-'),
                Text('₹${report.inwardSupplies.expensesItc.toStringAsFixed(2)}'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // REUSABLE UI HELPERS
  // =========================================================================
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildMetricsGrid(List<_MetricCardData> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: constraints.maxWidth > 900 ? 2.3 : 2.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, idx) {
            final item = items[idx];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.title,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.value,
                          style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDataTable({required List<String> columns, required List<List<Widget>> rows}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.background),
          columns: columns
              .map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold))))
              .toList(),
          rows: rows.map((r) => DataRow(cells: r.map((cell) => DataCell(cell)).toList())).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = AppColors.primary.withValues(alpha: 0.1);
    Color fg = AppColors.primary;

    if (['PAID', 'RECEIVED', 'IN_STOCK', 'PURCHASE'].contains(status)) {
      bg = AppColors.success.withValues(alpha: 0.12);
      fg = AppColors.success;
    } else if (['LOW_STOCK', 'PARTIALLY_PAID', 'SALE'].contains(status)) {
      bg = AppColors.warning.withValues(alpha: 0.12);
      fg = AppColors.warning;
    } else if (['OUT_OF_STOCK', 'UNPAID', 'CANCELLED', 'DAMAGE'].contains(status)) {
      bg = AppColors.error.withValues(alpha: 0.12);
      fg = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _MetricCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _MetricCardData(this.title, this.value, this.icon, this.color);
}
