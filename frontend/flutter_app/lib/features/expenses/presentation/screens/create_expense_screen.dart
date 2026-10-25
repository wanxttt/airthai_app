import 'package:flutter/material.dart';

import '../../../../core/services/expense_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/expense_models.dart';

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({super.key});

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  List<ExpenseCategoryModel> _categories = [];
  bool _isLoadingCategories = true;
  String? _selectedCategoryId;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _gstAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _expenseDate = DateTime.now();
  String _paymentMethod = 'CASH';
  bool _hasGst = false;
  bool _isTaxDeductible = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _vendorController.dispose();
    _gstinController.dispose();
    _gstAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final res = await ExpenseService.instance.getCategories();
    if (mounted) {
      setState(() {
        _isLoadingCategories = false;
        if (res.success && res.data != null && res.data!.isNotEmpty) {
          _categories = res.data!;
          _selectedCategoryId = _categories.first.id;
        }
      });
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Category', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category Name *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final res = await ExpenseService.instance.createCategory(name);
              if (ctx.mounted) {
                if (res.success && res.data != null) {
                  setState(() {
                    _categories.add(res.data!);
                    _selectedCategoryId = res.data!.id;
                  });
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res.errorMessage ?? 'Failed to create category')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (created == true) {
      setState(() {});
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(() => _errorMessage = 'Please select a category.');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Amount must be greater than zero.');
      return;
    }

    final gstAmount = _hasGst ? (double.tryParse(_gstAmountController.text) ?? 0.0) : 0.0;
    if (gstAmount > amount) {
      setState(() => _errorMessage = 'GST amount cannot exceed total expense amount.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final payload = {
      'categoryId': _selectedCategoryId,
      'amount': amount,
      'date': _expenseDate.toIso8601String(),
      'paymentMethod': _paymentMethod,
      if (_vendorController.text.isNotEmpty) 'vendor': _vendorController.text.trim(),
      if (_hasGst && _gstinController.text.isNotEmpty) 'gstin': _gstinController.text.trim(),
      if (_hasGst && gstAmount > 0) 'gstAmount': gstAmount,
      'isTaxDeductible': _isTaxDeductible,
      if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
    };

    final res = await ExpenseService.instance.createExpense(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense ${res.data?.expenseNumber ?? ""} recorded successfully.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = res.errorMessage ?? 'Failed to record expense.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Record New Expense'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expense Details', style: AppTextStyles.title),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedCategoryId,
                                    decoration: const InputDecoration(
                                      labelText: 'Category *',
                                      prefixIcon: Icon(Icons.category_rounded),
                                    ),
                                    items: _categories.map((c) {
                                      return DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedCategoryId = val);
                                    },
                                    validator: (val) => val == null ? 'Select category' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _showAddCategoryDialog,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('New'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Amount (₹) *',
                                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                                    ),
                                    validator: (val) {
                                      final num = double.tryParse(val ?? '');
                                      if (num == null || num <= 0) return 'Enter amount > 0';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _paymentMethod,
                                    decoration: const InputDecoration(
                                      labelText: 'Payment Method *',
                                      prefixIcon: Icon(Icons.payment_rounded),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                                      DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                                      DropdownMenuItem(value: 'CARD', child: Text('Card')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _paymentMethod = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _vendorController,
                              decoration: const InputDecoration(
                                labelText: 'Vendor / Payee / Merchant',
                                prefixIcon: Icon(Icons.store_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // GST Toggle & Inputs
                            CheckboxListTile(
                              title: const Text('Includes Input GST / Tax Invoice Available'),
                              subtitle: const Text('Capture GSTIN and tax portion for claiming Input Tax Credit (ITC).'),
                              value: _hasGst,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setState(() => _hasGst = val ?? false);
                              },
                            ),
                            if (_hasGst) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _gstinController,
                                      decoration: const InputDecoration(
                                        labelText: 'Vendor GSTIN',
                                        prefixIcon: Icon(Icons.pin_rounded),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _gstAmountController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'GST Amount (₹)',
                                        prefixIcon: Icon(Icons.receipt_long_rounded),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),

                            SwitchListTile(
                              title: const Text('Tax Deductible Business Expense'),
                              subtitle: const Text('Eligible as deductible expense in P&L reporting.'),
                              value: _isTaxDeductible,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setState(() => _isTaxDeductible = val);
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Notes / Purpose',
                                prefixIcon: Icon(Icons.note_alt_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSubmitting ? null : _submitExpense,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Save Expense Record', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
