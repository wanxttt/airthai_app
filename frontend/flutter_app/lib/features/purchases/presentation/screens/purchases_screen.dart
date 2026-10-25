import 'package:flutter/material.dart';

import '../../../../core/services/purchase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/purchase_models.dart';
import 'create_purchase_screen.dart';
import 'purchase_detail_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<PurchaseModel> _purchases = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await PurchaseService.instance.getPurchases(
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      status: _statusFilter,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _purchases = res.data!;
        } else {
          _errorMessage = res.errorMessage ?? 'Failed to load purchase bills.';
        }
      });
    }
  }

  double get _totalPurchases => _purchases
      .where((p) => !p.isCancelled)
      .fold(0.0, (acc, p) => acc + p.totalAmount);

  double get _totalPayables => _purchases
      .where((p) => !p.isCancelled)
      .fold(0.0, (acc, p) => acc + p.balanceAmount);

  int get _receivedCount => _purchases.where((p) => p.isReceived).length;

  int get _pendingCount => _purchases.where((p) => p.isOrdered).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Summary & Metrics
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;
                    if (isNarrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Total Purchases',
                                  '₹${_totalPurchases.toStringAsFixed(2)}',
                                  Icons.receipt_rounded,
                                  AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Outstanding Payables',
                                  '₹${_totalPayables.toStringAsFixed(2)}',
                                  Icons.account_balance_wallet_rounded,
                                  AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Received Bills',
                                  '$_receivedCount',
                                  Icons.check_circle_outline_rounded,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Ordered / Pending',
                                  '$_pendingCount',
                                  Icons.pending_actions_rounded,
                                  Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Total Purchases',
                            '₹${_totalPurchases.toStringAsFixed(2)}',
                            Icons.receipt_rounded,
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'Outstanding Payables',
                            '₹${_totalPayables.toStringAsFixed(2)}',
                            Icons.account_balance_wallet_rounded,
                            AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'Received Bills',
                            '$_receivedCount',
                            Icons.check_circle_outline_rounded,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'Ordered / Pending',
                            '$_pendingCount',
                            Icons.pending_actions_rounded,
                            Colors.blue,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Actions & Filters Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by bill number or supplier name...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    setState(() => _searchQuery = '');
                                    _loadPurchases();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                          _loadPurchases();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'RECEIVED', child: Text('Received (In Stock)')),
                        DropdownMenuItem(value: 'ORDERED', child: Text('Ordered (Draft)')),
                        DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _statusFilter = val);
                          _loadPurchases();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreatePurchaseScreen(
                              onPurchaseCreated: _loadPurchases,
                            ),
                          ),
                        );
                        if (created == true) {
                          _loadPurchases();
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New Purchase Bill'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Purchases List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.red, size: 40),
                            const SizedBox(height: 12),
                            Text(_errorMessage!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadPurchases,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _purchases.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_cart_outlined,
                                    color: AppColors.textMuted, size: 48),
                                const SizedBox(height: 12),
                                const Text('No purchase bills found',
                                    style: AppTextStyles.title),
                                const SizedBox(height: 4),
                                const Text(
                                  'Record your inventory purchases from suppliers to update stock balances and accounts payable.',
                                  style: AppTextStyles.bodySecondary,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreatePurchaseScreen(
                                          onPurchaseCreated: _loadPurchases,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Record First Purchase Bill'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: _purchases.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final p = _purchases[index];
                              return _buildPurchaseCard(p);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.label,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(PurchaseModel p) {
    Color badgeBg;
    Color badgeFg;
    String badgeText;

    if (p.isReceived) {
      badgeBg = Colors.green.shade50;
      badgeFg = Colors.green.shade800;
      badgeText = 'RECEIVED';
    } else if (p.isOrdered) {
      badgeBg = Colors.blue.shade50;
      badgeFg = Colors.blue.shade800;
      badgeText = 'ORDERED';
    } else {
      badgeBg = Colors.red.shade50;
      badgeFg = Colors.red.shade800;
      badgeText = 'CANCELLED';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PurchaseDetailScreen(purchase: p),
            ),
          );
          _loadPurchases();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.isReceived
                      ? AppColors.primaryLight
                      : (p.isOrdered
                          ? Colors.blue.shade50
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: p.isReceived
                      ? AppColors.primary
                      : (p.isOrdered ? Colors.blue.shade700 : Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.billNumber,
                            style: AppTextStyles.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeFg,
                            ),
                          ),
                        ),
                        if (p.isUnpaid && !p.isCancelled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'UNPAID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.supplierName ?? 'Supplier',
                            style: AppTextStyles.bodySecondary,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text(' • ', style: AppTextStyles.bodySecondary),
                        Text(
                          '${p.billDate.day.toString().padLeft(2, '0')}/${p.billDate.month.toString().padLeft(2, '0')}/${p.billDate.year}',
                          style: AppTextStyles.bodySecondary,
                        ),
                        const Text(' • ', style: AppTextStyles.bodySecondary),
                        Text(
                          '${p.items.length} item${p.items.length == 1 ? '' : 's'}',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${p.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (p.balanceAmount > 0 && !p.isCancelled)
                    Text(
                      'Bal: ₹${p.balanceAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    )
                  else if (!p.isCancelled)
                    const Text(
                      'PAID',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
