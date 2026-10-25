import 'package:flutter/material.dart';

import '../../../../core/services/payment_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/payment_models.dart';
import 'record_receipt_screen.dart';
import 'record_supplier_payment_screen.dart';
import 'payment_detail_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PaymentModel> _payments = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _methodFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await PaymentService.instance.getPayments(
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      paymentMethod: _methodFilter != 'ALL' ? _methodFilter : null,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _payments = res.data!;
        } else {
          _errorMessage = res.errorMessage ?? 'Failed to load payments.';
        }
      });
    }
  }

  double get _totalReceipts => _payments
      .where((p) => p.isCustomerReceipt)
      .fold(0.0, (acc, p) => acc + p.amount);

  double get _totalSupplierPayments => _payments
      .where((p) => p.isSupplierPayment)
      .fold(0.0, (acc, p) => acc + p.amount);

  double get _netCashFlow => _totalReceipts - _totalSupplierPayments;

  List<PaymentModel> get _displayedPayments {
    if (_tabController.index == 1) {
      return _payments.where((p) => p.isCustomerReceipt).toList();
    } else if (_tabController.index == 2) {
      return _payments.where((p) => p.isSupplierPayment).toList();
    }
    return _payments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Metrics
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
                                  'Total Receipts',
                                  '₹${_totalReceipts.toStringAsFixed(2)}',
                                  Icons.arrow_downward_rounded,
                                  const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Supplier Payments',
                                  '₹${_totalSupplierPayments.toStringAsFixed(2)}',
                                  Icons.arrow_upward_rounded,
                                  const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Net Cash Flow',
                                  '₹${_netCashFlow.toStringAsFixed(2)}',
                                  Icons.account_balance_rounded,
                                  _netCashFlow >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Vouchers Count',
                                  '${_payments.length}',
                                  Icons.receipt_long_rounded,
                                  AppColors.primary,
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
                            'Total Receipts',
                            '₹${_totalReceipts.toStringAsFixed(2)}',
                            Icons.arrow_downward_rounded,
                            const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'Supplier Payments',
                            '₹${_totalSupplierPayments.toStringAsFixed(2)}',
                            Icons.arrow_upward_rounded,
                            const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'Net Cash Flow',
                            '₹${_netCashFlow.toStringAsFixed(2)}',
                            Icons.account_balance_rounded,
                            _netCashFlow >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'Vouchers Count',
                            '${_payments.length}',
                            Icons.receipt_long_rounded,
                            AppColors.primary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        tabs: [
                          Tab(text: 'All Payments (${_payments.length})'),
                          Tab(text: 'Customer Receipts (${_payments.where((p) => p.isCustomerReceipt).length})'),
                          Tab(text: 'Supplier Payments (${_payments.where((p) => p.isSupplierPayment).length})'),
                        ],
                        onTap: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const RecordReceiptScreen()),
                        );
                        if (created == true) _loadPayments();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Record Receipt'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const RecordSupplierPaymentScreen()),
                        );
                        if (created == true) _loadPayments();
                      },
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: const Text('Supplier Payment'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by voucher #, customer, supplier, reference...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _loadPayments();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _methodFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Methods')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                    DropdownMenuItem(value: 'CARD', child: Text('Card')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _methodFilter = val);
                      _loadPayments();
                    }
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadPayments,
                ),
              ],
            ),
          ),

          // Payment List Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadPayments, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _displayedPayments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text('No payment vouchers found', style: AppTextStyles.title),
                                const SizedBox(height: 8),
                                const Text(
                                  'Record customer receipts or supplier payments to begin tracking transactions.',
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: _displayedPayments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _displayedPayments[index];
                              return _buildPaymentCard(item);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    final isReceipt = payment.isCustomerReceipt;
    final badgeColor = isReceipt ? const Color(0xFF10B981) : const Color(0xFF3B82F6);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final refreshed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentDetailScreen(payment: payment),
            ),
          );
          if (refreshed == true) _loadPayments();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isReceipt ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: badgeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          payment.paymentNumber,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isReceipt ? 'CUSTOMER RECEIPT' : 'SUPPLIER PAYMENT',
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.partyName,
                      style: AppTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              '${payment.paymentDate.day.toString().padLeft(2, '0')}/${payment.paymentDate.month.toString().padLeft(2, '0')}/${payment.paymentDate.year}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.credit_card_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(payment.formattedMethod, style: AppTextStyles.caption),
                          ],
                        ),
                        if (payment.referenceNumber != null)
                          Text('Ref: ${payment.referenceNumber}', style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${payment.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isReceipt ? const Color(0xFF10B981) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    payment.allocations.isNotEmpty
                        ? 'Allocated: ${payment.allocations.length} doc(s)'
                        : 'Unallocated Advance',
                    style: TextStyle(
                      fontSize: 12,
                      color: payment.allocations.isNotEmpty
                          ? AppColors.textSecondary
                          : Colors.amber.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
