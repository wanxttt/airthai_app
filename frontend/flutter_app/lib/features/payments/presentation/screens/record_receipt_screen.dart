import 'package:flutter/material.dart';

import '../../../../core/services/master_data_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../master_data/models/master_data_models.dart';
import '../../models/payment_models.dart';

class RecordReceiptScreen extends StatefulWidget {
  final String? initialCustomerId;

  const RecordReceiptScreen({super.key, this.initialCustomerId});

  @override
  State<RecordReceiptScreen> createState() => _RecordReceiptScreenState();
}

class _RecordReceiptScreenState extends State<RecordReceiptScreen> {
  final _formKey = GlobalKey<FormState>();

  List<CustomerModel> _customers = [];
  bool _isLoadingCustomers = true;
  String? _selectedCustomerId;

  List<OutstandingInvoiceModel> _outstandingInvoices = [];
  bool _isLoadingInvoices = false;
  final Map<String, TextEditingController> _allocationControllers = {};

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'UPI';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    for (final c in _allocationControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    final res = await MasterDataService.instance.getCustomers();
    if (mounted) {
      setState(() {
        _isLoadingCustomers = false;
        if (res.success && res.data != null) {
          _customers = res.data!;
          if (widget.initialCustomerId != null) {
            _onCustomerSelected(widget.initialCustomerId!);
          }
        }
      });
    }
  }

  Future<void> _onCustomerSelected(String customerId) async {
    setState(() {
      _selectedCustomerId = customerId;
      _isLoadingInvoices = true;
      _outstandingInvoices = [];
      for (final c in _allocationControllers.values) {
        c.dispose();
      }
      _allocationControllers.clear();
    });

    final res = await PaymentService.instance.getCustomerOutstanding(customerId);
    if (mounted) {
      setState(() {
        _isLoadingInvoices = false;
        if (res.success && res.data != null) {
          _outstandingInvoices = res.data!;
          for (final inv in _outstandingInvoices) {
            final ctrl = TextEditingController(text: '0.00');
            ctrl.addListener(() => setState(() {}));
            _allocationControllers[inv.id] = ctrl;
          }
        }
      });
    }
  }

  double get _totalReceiptAmount => double.tryParse(_amountController.text) ?? 0.0;

  double get _totalAllocatedAmount {
    double sum = 0.0;
    for (final ctrl in _allocationControllers.values) {
      sum += double.tryParse(ctrl.text) ?? 0.0;
    }
    return sum;
  }

  double get _unallocatedAmount => _totalReceiptAmount - _totalAllocatedAmount;

  void _autoAllocateFifo() {
    double remaining = _totalReceiptAmount;
    if (remaining <= 0) return;

    for (final inv in _outstandingInvoices) {
      final ctrl = _allocationControllers[inv.id];
      if (ctrl == null) continue;

      if (remaining <= 0) {
        ctrl.text = '0.00';
      } else if (remaining >= inv.balanceAmount) {
        ctrl.text = inv.balanceAmount.toStringAsFixed(2);
        remaining -= inv.balanceAmount;
      } else {
        ctrl.text = remaining.toStringAsFixed(2);
        remaining = 0;
      }
    }
    setState(() {});
  }

  Future<void> _submitReceipt() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      setState(() => _errorMessage = 'Please select a customer.');
      return;
    }
    if (_totalReceiptAmount <= 0) {
      setState(() => _errorMessage = 'Receipt amount must be greater than zero.');
      return;
    }
    if (_totalAllocatedAmount > _totalReceiptAmount) {
      setState(() => _errorMessage = 'Allocated amount exceeds total receipt amount.');
      return;
    }

    // Verify individual invoice limits
    for (final inv in _outstandingInvoices) {
      final alloc = double.tryParse(_allocationControllers[inv.id]?.text ?? '0') ?? 0.0;
      if (alloc > inv.balanceAmount + 0.01) {
        setState(() => _errorMessage =
            'Allocation for invoice ${inv.invoiceNumber} (₹${alloc.toStringAsFixed(2)}) exceeds balance (₹${inv.balanceAmount.toStringAsFixed(2)}).');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final selectedCustomer = _customers.firstWhere((c) => c.id == _selectedCustomerId);
    final allocations = <Map<String, dynamic>>[];
    for (final inv in _outstandingInvoices) {
      final val = double.tryParse(_allocationControllers[inv.id]?.text ?? '0') ?? 0.0;
      if (val > 0) {
        allocations.add({
          'invoiceId': inv.id,
          'invoiceNumber': inv.invoiceNumber,
          'amount': val,
        });
      }
    }

    final payload = {
      'paymentType': 'CUSTOMER_RECEIPT',
      'customerId': _selectedCustomerId,
      'customerName': selectedCustomer.name,
      'amount': _totalReceiptAmount,
      'paymentDate': _paymentDate.toIso8601String(),
      'paymentMethod': _paymentMethod,
      if (_referenceController.text.isNotEmpty) 'referenceNumber': _referenceController.text.trim(),
      if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
      'allocations': allocations,
    };

    final res = await PaymentService.instance.recordCustomerReceipt(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt ${res.data?.paymentNumber ?? ""} recorded successfully.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = res.errorMessage ?? 'Failed to record receipt.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCustomer = _customers.where((c) => c.id == _selectedCustomerId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Record Customer Receipt'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoadingCustomers
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

                    // Party & Receipt Info Card
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
                            const Text('Receipt Details', style: AppTextStyles.title),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedCustomerId,
                              decoration: const InputDecoration(
                                labelText: 'Select Customer *',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              items: _customers.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    '${c.name} — Outstanding Bal: ₹${c.currentBalance.toStringAsFixed(2)}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) _onCustomerSelected(val);
                              },
                              validator: (val) => val == null ? 'Please select customer' : null,
                            ),
                            if (selectedCustomer != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet_outlined,
                                        size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Current Total Receivable: ₹${selectedCustomer.currentBalance.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Receipt Amount (₹) *',
                                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                                    ),
                                    validator: (val) {
                                      final num = double.tryParse(val ?? '');
                                      if (num == null || num <= 0) {
                                        return 'Enter valid amount > 0';
                                      }
                                      return null;
                                    },
                                    onChanged: (_) => setState(() {}),
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
                                      DropdownMenuItem(value: 'UPI', child: Text('UPI (GPay, PhonePe, Paytm)')),
                                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS/IMPS)')),
                                      DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                                      DropdownMenuItem(value: 'CARD', child: Text('Debit / Credit Card')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _paymentMethod = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _referenceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Reference # (UTR / Cheque / Txn ID)',
                                      prefixIcon: Icon(Icons.numbers_rounded),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _notesController,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes / Remarks',
                                      prefixIcon: Icon(Icons.note_alt_outlined),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Invoices Allocation Section
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Allocate to Invoices', style: AppTextStyles.title),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Distribute payment across eligible invoices or keep as unallocated advance.',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                                if (_outstandingInvoices.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: _autoAllocateFifo,
                                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                                    label: const Text('Auto-Allocate (FIFO)'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_isLoadingInvoices)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_selectedCustomerId == null)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'Select a customer above to view their outstanding invoices.',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ),
                              )
                            else if (_outstandingInvoices.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.check_circle_outline_rounded,
                                          color: Color(0xFF10B981), size: 36),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'No open invoices pending payment for this customer.',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Payment will be saved as an unallocated customer advance credit.',
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _outstandingInvoices.length,
                                separatorBuilder: (_, __) => const Divider(height: 24),
                                itemBuilder: (context, index) {
                                  final inv = _outstandingInvoices[index];
                                  final ctrl = _allocationControllers[inv.id];

                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inv.invoiceNumber,
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Date: ${inv.invoiceDate.day}/${inv.invoiceDate.month}/${inv.invoiceDate.year} • Total: ₹${inv.totalAmount.toStringAsFixed(2)}',
                                              style: AppTextStyles.caption,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('Balance Due', style: AppTextStyles.caption),
                                            Text(
                                              '₹${inv.balanceAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 140,
                                        child: TextFormField(
                                          controller: ctrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.end,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            labelText: 'Allocate (₹)',
                                            contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 10),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Allocation Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Receipt Amount', style: TextStyle(fontSize: 15)),
                              Text(
                                '₹${_totalReceiptAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Allocated Amount', style: TextStyle(fontSize: 15)),
                              Text(
                                '₹${_totalAllocatedAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: _totalAllocatedAmount > _totalReceiptAmount
                                      ? Colors.red
                                      : const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _unallocatedAmount >= 0 ? 'Unallocated Advance Credit' : 'Over-Allocated Error',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _unallocatedAmount < 0 ? Colors.red : AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '₹${_unallocatedAmount.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: _unallocatedAmount < 0 ? Colors.red : Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Action
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSubmitting ? null : _submitReceipt,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Record Customer Receipt', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
