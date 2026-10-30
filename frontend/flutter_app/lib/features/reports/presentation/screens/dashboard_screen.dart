import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/services/dashboard_service.dart';
import '../../models/dashboard_model.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const DashboardScreen({
    super.key,
    this.onNavigateToTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  DashboardMetricsModel? _metrics;
  String _selectedPeriod = 'this_month';

  final List<Map<String, String>> _periodOptions = const [
    {'value': 'today', 'label': 'Today'},
    {'value': 'this_week', 'label': 'This Week'},
    {'value': 'this_month', 'label': 'This Month'},
    {'value': 'this_quarter', 'label': 'This Quarter'},
    {'value': 'this_year', 'label': 'This Year'},
    {'value': 'all', 'label': 'All Time'},
  ];

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await DashboardService.instance.getMetrics(period: _selectedPeriod);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess) {
          _metrics = res.data;
        } else {
          _errorMessage = res.error;
        }
      });
    }
  }

  void _showCalculationAssumptionsDialog(String assumptions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Profit Calculation Assumptions'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assumptions,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            const Text(
              'Key Financial Distinctions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('• Invoiced Sales Revenue ≠ Cash Collections'),
            const Text('• Purchase Cost ≠ Cash Disbursements'),
            const Text('• Net Profit excludes GST liabilities and timing differences.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;
    final userName = user?.fullName ?? 'Business Owner';
    final bizName = user?.businessId != null
        ? 'Business Workspace (${user!.businessId})'
        : 'AirthAI Workspace';

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome & Controls Header
            _buildWelcomeBanner(userName, bizName),
            const SizedBox(height: 20),

            // Period Selector Bar
            _buildPeriodSelectorBar(),
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              _buildErrorBanner()
            else if (_metrics != null)
              _buildDashboardContent(_metrics!),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(String userName, String bizName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $userName',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$bizName • Real-Time Business Intelligence',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadMetrics,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Metrics',
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelectorBar() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        const Text(
          'PERIOD FILTER: ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPeriod,
              items: _periodOptions
                  .map((opt) => DropdownMenuItem(
                        value: opt['value'],
                        child: Text(opt['label']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null && val != _selectedPeriod) {
                  setState(() {
                    _selectedPeriod = val;
                  });
                  _loadMetrics();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMessage ?? 'An error occurred loading dashboard')),
          ElevatedButton(
            onPressed: _loadMetrics,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(DashboardMetricsModel metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Business Alerts Section
        if (metrics.alerts.isNotEmpty) ...[
          _buildAlertsSection(metrics.alerts),
          const SizedBox(height: 24),
        ],

        // Core Financial & Operational KPI Cards
        const Text('KEY FINANCIAL & OPERATIONAL INDICATORS', style: AppTextStyles.label),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            final cardWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard(
                  title: 'Sales for Period',
                  value: '₹${metrics.sales.totalSales.toStringAsFixed(2)}',
                  subtitle: '${metrics.sales.invoiceCount} invoices (${metrics.sales.growthPercentage >= 0 ? '+' : ''}${metrics.sales.growthPercentage}% vs prev)',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  width: cardWidth,
                  onTap: () => widget.onNavigateToTab?.call(1),
                ),
                _buildKpiCard(
                  title: 'Purchases for Period',
                  value: '₹${metrics.purchases.totalPurchases.toStringAsFixed(2)}',
                  subtitle: '${metrics.purchases.purchaseCount} bills recorded',
                  icon: Icons.shopping_bag_outlined,
                  color: Colors.blue.shade700,
                  width: cardWidth,
                  onTap: () => widget.onNavigateToTab?.call(2),
                ),
                _buildKpiCard(
                  title: 'Customer Receivables',
                  value: '₹${metrics.outstanding.receivables.toStringAsFixed(2)}',
                  subtitle: metrics.outstanding.overdueReceivables > 0
                      ? '₹${metrics.outstanding.overdueReceivables.toStringAsFixed(2)} overdue'
                      : 'All accounts current',
                  icon: Icons.account_balance_wallet_rounded,
                  color: metrics.outstanding.overdueReceivables > 0 ? AppColors.warning : AppColors.success,
                  width: cardWidth,
                  onTap: () => widget.onNavigateToTab?.call(4),
                ),
                _buildKpiCard(
                  title: 'Supplier Payables',
                  value: '₹${metrics.outstanding.payables.toStringAsFixed(2)}',
                  subtitle: 'Pending settlement to vendors',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.error,
                  width: cardWidth,
                  onTap: () => widget.onNavigateToTab?.call(5),
                ),
                _buildKpiCard(
                  title: 'Net Cash Flow',
                  value: '₹${metrics.cashFlow.netCashFlow.toStringAsFixed(2)}',
                  subtitle: 'In: ₹${metrics.cashFlow.totalCollections.toStringAsFixed(0)} | Out: ₹${metrics.cashFlow.totalDisbursements.toStringAsFixed(0)}',
                  icon: Icons.payments_outlined,
                  color: metrics.cashFlow.netCashFlow >= 0 ? AppColors.success : AppColors.error,
                  width: cardWidth,
                  onTap: () => widget.onNavigateToTab?.call(6),
                ),
                _buildKpiCard(
                  title: 'Operating Expenses',
                  value: '₹${metrics.expenses.totalExpenses.toStringAsFixed(2)}',
                  subtitle: '${metrics.expenses.expenseCount} vouchers (GST: ₹${metrics.expenses.gstAmount.toStringAsFixed(0)})',
                  icon: Icons.receipt_outlined,
                  color: Colors.purple.shade600,
                  width: cardWidth,
                  onTap: () => widget.onNavigateToTab?.call(7),
                ),
                _buildKpiCard(
                  title: 'Inventory Health',
                  value: '₹${metrics.inventory.totalValuation.toStringAsFixed(2)}',
                  subtitle: '${metrics.inventory.totalProducts} items (${metrics.inventory.lowStockCount} low stock)',
                  icon: Icons.inventory_2_outlined,
                  color: metrics.inventory.lowStockCount > 0 ? AppColors.warning : AppColors.primary,
                  width: cardWidth,
                  onTap: () => widget.onNavigateToTab?.call(3),
                ),
                _buildKpiCard(
                  title: 'Net Profit Indicator',
                  value: '₹${metrics.profitability.netProfit.toStringAsFixed(2)}',
                  subtitle: 'Gross: ₹${metrics.profitability.grossProfit.toStringAsFixed(0)} • Margin: ${metrics.profitability.netProfitMargin}% ℹ️',
                  icon: Icons.insights_rounded,
                  color: metrics.profitability.netProfit >= 0 ? const Color(0xFF10B981) : AppColors.error,
                  width: cardWidth,
                  onTap: () => _showCalculationAssumptionsDialog(metrics.profitability.calculationAssumptions),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),

        // Recent Activity Section
        _buildRecentActivitySection(metrics.recentActivity),
        const SizedBox(height: 28),

        // Quick Actions Shortcuts
        const Text('QUICK ACTIONS', style: AppTextStyles.label),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildShortcutButton(Icons.receipt_rounded, 'Sales & Invoices', 1),
            _buildShortcutButton(Icons.shopping_bag_outlined, 'Purchase Bills', 2),
            _buildShortcutButton(Icons.inventory_2_outlined, 'Inventory & Stock', 3),
            _buildShortcutButton(Icons.payments_outlined, 'Customer Receipts', 6),
            _buildShortcutButton(Icons.account_balance_wallet_outlined, 'Track Expenses', 7),
            _buildShortcutButton(Icons.assessment_outlined, 'Reports & GST', 8),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertsSection(List<DashboardAlert> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BUSINESS NOTIFICATIONS & ALERTS', style: AppTextStyles.label),
        const SizedBox(height: 8),
        ...alerts.map((alert) {
          final isWarning = alert.severity == 'warning';
          final isError = alert.severity == 'error';
          final color = isError ? AppColors.error : (isWarning ? AppColors.warning : AppColors.primary);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(isError ? Icons.error_rounded : Icons.warning_rounded, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(alert.message, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentActivitySection(DashboardRecentActivity recent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Recent Commercial Transactions', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.invoices.isNotEmpty) ...[
            Text('Recent Invoices', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...recent.invoices.map((inv) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.receipt, color: AppColors.primary, size: 16),
                  ),
                  title: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(inv.customerName),
                  trailing: Text('₹${inv.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
          ],
          if (recent.purchases.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Recent Purchase Bills', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...recent.purchases.map((p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFF0FDF4),
                    child: Icon(Icons.shopping_bag, color: AppColors.success, size: 16),
                  ),
                  title: Text(p.billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(p.supplierName),
                  trailing: Text('₹${p.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutButton(IconData icon, String label, int tabIndex) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: AppColors.border),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => widget.onNavigateToTab?.call(tabIndex),
    );
  }
}
