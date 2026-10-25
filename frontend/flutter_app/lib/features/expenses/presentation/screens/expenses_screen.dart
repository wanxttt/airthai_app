import 'package:flutter/material.dart';

import '../../../../core/services/expense_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/expense_models.dart';
import 'create_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<ExpenseModel> _expenses = [];
  List<ExpenseCategoryModel> _categories = [];
  ExpenseSummaryModel? _summary;
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String? _selectedCategoryId;
  String _paymentMethodFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final catFuture = ExpenseService.instance.getCategories();
    final summaryFuture = ExpenseService.instance.getSummary();
    final expFuture = ExpenseService.instance.getExpenses(
      categoryId: _selectedCategoryId,
      paymentMethod: _paymentMethodFilter != 'ALL' ? _paymentMethodFilter : null,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
    );

    final results = await Future.wait([catFuture, summaryFuture, expFuture]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        final catRes = results[0] as dynamic;
        final sumRes = results[1] as dynamic;
        final expRes = results[2] as dynamic;

        if (catRes.success && catRes.data != null) {
          _categories = catRes.data;
        }
        if (sumRes.success && sumRes.data != null) {
          _summary = sumRes.data;
        }
        if (expRes.success && expRes.data != null) {
          _expenses = expRes.data;
        } else {
          _errorMessage = expRes.errorMessage ?? 'Failed to load expenses.';
        }
      });
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Expense Category', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name *',
            hintText: 'e.g. Equipment Rental, IT Subscriptions',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final res = await ExpenseService.instance.createCategory(name);
              if (ctx.mounted) {
                if (res.success) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res.errorMessage ?? 'Failed to create category')),
                  );
                }
              }
            },
            child: const Text('Save Category'),
          ),
        ],
      ),
    );

    if (created == true) {
      _loadData();
    }
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense Record', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete expense ${expense.expenseNumber} (₹${expense.amount.toStringAsFixed(2)})? This action is audited.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ExpenseService.instance.deleteExpense(expense.id);
      if (mounted) {
        if (res.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.errorMessage ?? 'Failed to delete expense')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _summary?.totalExpenses ?? 0.0;
    final deductible = _summary?.totalTaxDeductible ?? 0.0;
    final gst = _summary?.totalGstAmount ?? 0.0;
    final count = _summary?.count ?? _expenses.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics Header
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
                                  'Total Expenses',
                                  '₹${total.toStringAsFixed(2)}',
                                  Icons.money_off_rounded,
                                  const Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Tax Deductible',
                                  '₹${deductible.toStringAsFixed(2)}',
                                  Icons.verified_rounded,
                                  const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Input GST Claimable',
                                  '₹${gst.toStringAsFixed(2)}',
                                  Icons.receipt_rounded,
                                  AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Total Entries',
                                  '$count',
                                  Icons.format_list_numbered_rounded,
                                  Colors.purple,
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
                            'Total Expenses',
                            '₹${total.toStringAsFixed(2)}',
                            Icons.money_off_rounded,
                            const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'Tax Deductible',
                            '₹${deductible.toStringAsFixed(2)}',
                            Icons.verified_rounded,
                            const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'Input GST Claimable',
                            '₹${gst.toStringAsFixed(2)}',
                            Icons.receipt_rounded,
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'Total Entries',
                            '$count',
                            Icons.format_list_numbered_rounded,
                            Colors.purple,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expense Log & Categories', style: AppTextStyles.title),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showAddCategoryDialog,
                          icon: const Icon(Icons.category_rounded, size: 16),
                          label: const Text('Add Category'),
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
                              MaterialPageRoute(builder: (_) => const CreateExpenseScreen()),
                            );
                            if (created == true) _loadData();
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New Expense'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Category Chips Bar
          if (_categories.isNotEmpty)
            Container(
              height: 48,
              color: AppColors.surface,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  ChoiceChip(
                    label: const Text('All Categories'),
                    selected: _selectedCategoryId == null,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _selectedCategoryId = null);
                        _loadData();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._categories.map((c) {
                    final isSel = _selectedCategoryId == c.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.name),
                        selected: isSel,
                        onSelected: (sel) {
                          setState(() => _selectedCategoryId = sel ? c.id : null);
                          _loadData();
                        },
                      ),
                    );
                  }),
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
                      hintText: 'Search by expense #, vendor, notes, category...',
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
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _paymentMethodFilter,
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
                      setState(() => _paymentMethodFilter = val);
                      _loadData();
                    }
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),

          // List Body
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
                            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _expenses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text('No expenses recorded', style: AppTextStyles.title),
                                const SizedBox(height: 8),
                                const Text(
                                  'Record day-to-day operating expenses, rent, utilities, and vendor payouts.',
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: _expenses.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _expenses[index];
                              return _buildExpenseCard(item);
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

  Widget _buildExpenseCard(ExpenseModel expense) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.outbox_rounded, color: Colors.red.shade600, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        expense.expenseNumber,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          expense.categoryName.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (expense.isTaxDeductible)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'TAX DEDUCTIBLE',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expense.vendor?.isNotEmpty == true ? expense.vendor! : 'Direct Payee',
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
                            '${expense.date.day.toString().padLeft(2, '0')}/${expense.date.month.toString().padLeft(2, '0')}/${expense.date.year}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.credit_card_rounded, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(expense.formattedMethod, style: AppTextStyles.caption),
                        ],
                      ),
                      if (expense.gstAmount > 0)
                        Text(
                          'GST: ₹${expense.gstAmount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 4),
                IconButton(
                  tooltip: 'Delete expense',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  onPressed: () => _deleteExpense(expense),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
