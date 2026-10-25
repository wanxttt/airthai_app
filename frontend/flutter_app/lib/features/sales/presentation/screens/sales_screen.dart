import 'package:flutter/material.dart';
import '../../../../core/services/sales_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/sales_models.dart';
import 'create_invoice_screen.dart';
import 'invoice_detail_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<InvoiceModel> _invoices = [];
  bool _isLoadingInvoices = true;
  String? _invoicesError;
  String _invoiceSearch = '';
  String _statusFilter = 'ALL';

  List<QuotationModel> _quotations = [];
  bool _isLoadingQuotations = true;
  String? _quotationsError;
  String _quotationSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInvoices();
    _loadQuotations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoadingInvoices = true;
      _invoicesError = null;
    });

    final res = await SalesService.instance.getInvoices(
      search: _invoiceSearch,
      status: _statusFilter,
    );

    if (mounted) {
      setState(() {
        _isLoadingInvoices = false;
        if (res.success) {
          _invoices = res.data ?? [];
        } else {
          _invoicesError = res.errorMessage;
        }
      });
    }
  }

  Future<void> _loadQuotations() async {
    setState(() {
      _isLoadingQuotations = true;
      _quotationsError = null;
    });

    final res = await SalesService.instance.getQuotations(
      search: _quotationSearch,
    );

    if (mounted) {
      setState(() {
        _isLoadingQuotations = false;
        if (res.success) {
          _quotations = res.data ?? [];
        } else {
          _quotationsError = res.errorMessage;
        }
      });
    }
  }

  double get _totalSales => _invoices
      .where((i) => !i.isCancelled)
      .fold(0.0, (acc, i) => acc + i.totalAmount);

  double get _totalReceivables => _invoices
      .where((i) => !i.isCancelled)
      .fold(0.0, (acc, i) => acc + i.balanceAmount);

  int get _unpaidCount => _invoices
      .where((i) => !i.isCancelled && i.balanceAmount > 0)
      .length;

  Future<void> _handleConvertQuotation(QuotationModel q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert Quotation to Invoice'),
        content: Text(
          'Convert quotation "${q.quotationNumber}" into an official tax invoice?\n\nThis will issue an invoice, record customer receivable, and reserve inventory stock.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert & Issue Invoice'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final res = await SalesService.instance.convertQuotationToInvoice(q.id);
      if (!mounted) return;

      if (res.success && res.data != null) {
        _loadInvoices();
        _loadQuotations();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Issued invoice ${res.data!.invoiceNumber} from quotation!'),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoice: res.data!)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(res.errorMessage ?? 'Failed to convert quotation.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Summary Row
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Total Invoiced Sales',
                        '₹${_totalSales.toStringAsFixed(2)}',
                        Icons.receipt_long_rounded,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Total Outstanding Balance',
                        '₹${_totalReceivables.toStringAsFixed(2)}',
                        Icons.account_balance_wallet_rounded,
                        AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Pending Invoices',
                        '$_unpaidCount',
                        Icons.pending_actions_rounded,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tabs & Action
                Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(text: 'Invoices (${_invoices.length})'),
                          Tab(text: 'Quotations (${_quotations.length})'),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateInvoiceScreen(
                              onInvoiceCreated: _loadInvoices,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New Tax Invoice'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvoicesTab(),
                _buildQuotationsTab(),
              ],
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.label, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
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

  Widget _buildInvoicesTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Filter Bar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by invoice number or customer name...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _invoiceSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setState(() => _invoiceSearch = '');
                              _loadInvoices();
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() => _invoiceSearch = val);
                    _loadInvoices();
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'ISSUED', child: Text('Issued')),
                  DropdownMenuItem(value: 'PAID', child: Text('Paid')),
                  DropdownMenuItem(value: 'PARTIALLY_PAID', child: Text('Partially Paid')),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _statusFilter = val);
                    _loadInvoices();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Invoice List
          Expanded(
            child: _isLoadingInvoices
                ? const Center(child: CircularProgressIndicator())
                : _invoicesError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
                            const SizedBox(height: 12),
                            Text(_invoicesError!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadInvoices, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _invoices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.receipt_long_outlined,
                                    color: AppColors.textMuted, size: 48),
                                const SizedBox(height: 12),
                                const Text('No invoices recorded yet', style: AppTextStyles.title),
                                const SizedBox(height: 4),
                                const Text(
                                  'Issue tax invoices to record sales, track GST, and collect payments.',
                                  style: AppTextStyles.bodySecondary,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreateInvoiceScreen(
                                          onInvoiceCreated: _loadInvoices,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Create First Invoice'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _invoices.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final inv = _invoices[index];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: inv.statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.receipt_rounded,
                                      color: inv.statusColor,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          inv.invoiceNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: inv.statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          inv.status,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: inv.statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            inv.customerName ?? 'Walk-in Customer',
                                            style: AppTextStyles.bodySecondary,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Text(' • ', style: AppTextStyles.bodySecondary),
                                        Text(
                                          '${inv.invoiceDate.day}/${inv.invoiceDate.month}/${inv.invoiceDate.year}',
                                          style: AppTextStyles.bodySecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${inv.totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (inv.balanceAmount > 0 && !inv.isCancelled)
                                        Text(
                                          'Due: ₹${inv.balanceAmount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InvoiceDetailScreen(
                                          invoice: inv,
                                          onInvoiceUpdated: _loadInvoices,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search quotations by number or customer...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _quotationSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setState(() => _quotationSearch = '');
                              _loadQuotations();
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() => _quotationSearch = val);
                    _loadQuotations();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quotation List
          Expanded(
            child: _isLoadingQuotations
                ? const Center(child: CircularProgressIndicator())
                : _quotationsError != null
                    ? Center(
                        child: Text(_quotationsError!, style: const TextStyle(color: Colors.red)),
                      )
                    : _quotations.isEmpty
                        ? const Center(child: Text('No quotations found.'))
                        : ListView.separated(
                            itemCount: _quotations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final q = _quotations[index];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: q.statusColor.withValues(alpha: 0.12),
                                    child: Icon(Icons.request_quote_rounded, color: q.statusColor),
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          q.quotationNumber,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: q.statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          q.status,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: q.statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${q.customerName ?? 'Prospect'} • Total: ₹${q.totalAmount.toStringAsFixed(2)}',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                  trailing: q.isConverted
                                      ? const Chip(label: Text('Converted', style: TextStyle(fontSize: 11)))
                                      : ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          onPressed: () => _handleConvertQuotation(q),
                                          icon: const Icon(Icons.transform_rounded, size: 14),
                                          label: const Text('Convert to Invoice', style: TextStyle(fontSize: 12)),
                                        ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
