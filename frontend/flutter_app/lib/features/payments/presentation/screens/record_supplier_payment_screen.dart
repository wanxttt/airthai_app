import 'package:flutter/material.dart';

import '../../../../core/services/master_data_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../master_data/models/master_data_models.dart';
import '../../models/payment_models.dart';

class RecordSupplierPaymentScreen extends StatefulWidget {
  final String? initialSupplierId;

  const RecordSupplierPaymentScreen({super.key, this.initialSupplierId});

  @override
  State<RecordSupplierPaymentScreen> createState() => _RecordSupplierPaymentScreenState();
}

class _RecordSupplierPaymentScreenState extends State<RecordSupplierPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  List<SupplierModel> _suppliers = [];
  bool _isLoadingSuppliers = true;
  String? _selectedSupplierId;

  List<OutstandingBillModel> _outstandingBills = [];
  bool _isLoadingBills = false;
  final Map<String, TextEditingController> _allocationControllers = {};

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'BANK_TRANSFER';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
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

  Future<void> _loadSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    final res = await MasterDataService.instance.getSuppliers();
    if (mounted) {
      setState(() {
        _isLoadingSuppliers = false;
        if (res.success && res.data != null) {
          _suppliers = res.data!;
          if (widget.initialSupplierId != null) {
            _onSupplierSelected(widget.initialSupplierId!);
          }
        }
      });
    }
  }

  Future<void> _onSupplierSelected(String supplierId) async {
    setState(() {
      _selectedSupplierId = supplierId;
      _isLoadingBills = true;
      _outstandingBills = [];
      for (final c in _allocationControllers.values) {
        c.dispose();
      }
      _allocationControllers.clear();
    });

    final res = await PaymentService.instance.getSupplierOutstanding(supplierId);
    if (mounted) {
      setState(() {
        _isLoadingBills = false;
        if (res.success && res.data != null) {
          _outstandingBills = res.data!;
          for (final bill in _outstandingBills) {
            final ctrl = TextEditingController(text: '0.00');
            ctrl.addListener(() => setState(() {}));
            _allocationControllers[bill.id] = ctrl;
          }
        }
      });
    }
  }

  double get _totalPaymentAmount => double.tryParse(_amountController.text) ?? 0.0;

  double get _totalAllocatedAmount {
    double sum = 0.0;
    for (final ctrl in _allocationControllers.values) {
      sum += double.tryParse(ctrl.text) ?? 0.0;
    }
    return sum;
  }

  double get _unallocatedAmount => _totalPaymentAmount - _totalAllocatedAmount;

  void _autoAllocateFifo() {
    double remaining = _totalPaymentAmount;
    if (remaining <= 0) return;

    for (final bill in _outstandingBills) {
      final ctrl = _allocationControllers[bill.id];
      if (ctrl == null) continue;

      if (remaining <= 0) {
        ctrl.text = '0.00';
      } else if (remaining >= bill.balanceAmount) {
        ctrl.text = bill.balanceAmount.toStringAsFixed(2);
        remaining -= bill.balanceAmount;
      } else {
        ctrl.text = remaining.toStringAsFixed(2);
        remaining = 0;
      }
    }
    setState(() {});
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      setState(() => _errorMessage = 'Please select a supplier.');
      return;
    }
    if (_totalPaymentAmount <= 0) {
      setState(() => _errorMessage = 'Payment amount must be greater than zero.');
      return;
    }
    if (_totalAllocatedAmount > _totalPaymentAmount) {
      setState(() => _errorMessage = 'Allocated amount exceeds total payment amount.');
      return;
    }

    // Verify individual bill limits
    for (final bill in _outstandingBills) {
      final alloc = double.tryParse(_allocationControllers[bill.id]?.text ?? '0') ?? 0.0;
      if (alloc > bill.balanceAmount + 0.01) {
        setState(() => _errorMessage =
            'Allocation for bill ${bill.billNumber} (₹${alloc.toStringAsFixed(2)}) exceeds balance (₹${bill.balanceAmount.toStringAsFixed(2)}).');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final selectedSupplier = _suppliers.firstWhere((s) => s.id == _selectedSupplierId);
    final allocations = <Map<String, dynamic>>[];
    for (final bill in _outstandingBills) {
      final val = double.tryParse(_allocationControllers[bill.id]?.text ?? '0') ?? 0.0;
      if (val > 0) {
        allocations.add({
          'purchaseId': bill.id,
          'billNumber': bill.billNumber,
          'amount': val,
        });
      }
    }

    final payload = {
      'paymentType': 'SUPPLIER_PAYMENT',
      'supplierId': _selectedSupplierId,
      'supplierName': selectedSupplier.name,
      'amount': _totalPaymentAmount,
      'paymentDate': _paymentDate.toIso8601String(),
      'paymentMethod': _paymentMethod,
      if (_referenceController.text.isNotEmpty) 'referenceNumber': _referenceController.text.trim(),
      if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
      'allocations': allocations,
    };

    final res = await PaymentService.instance.recordSupplierPayment(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier Payment ${res.data?.paymentNumber ?? ""} recorded successfully.'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = res.errorMessage ?? 'Failed to record supplier payment.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSupplier = _suppliers.where((s) => s.id == _selectedSupplierId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Record Supplier Payment'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoadingSuppliers
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

                    // Supplier & Payment Details Card
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
                            const Text('Payment Details', style: AppTextStyles.title),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedSupplierId,
                              decoration: const InputDecoration(
                                labelText: 'Select Supplier *',
                                prefixIcon: Icon(Icons.local_shipping_rounded),
                              ),
                              items: _suppliers.map((s) {
                                return DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    '${s.name} — Outstanding Payables: ₹${s.currentBalance.toStringAsFixed(2)}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) _onSupplierSelected(val);
                              },
                              validator: (val) => val == null ? 'Please select supplier' : null,
                            ),
                            if (selectedSupplier != null) ...[
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
                                      'Current Total Payables: ₹${selectedSupplier.currentBalance.toStringAsFixed(2)}',
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
                                      labelText: 'Payment Amount (₹) *',
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
                                    initialValue: _paymentMethod,
                                    decoration: const InputDecoration(
                                      labelText: 'Payment Method *',
                                      prefixIcon: Icon(Icons.payment_rounded),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS/IMPS)')),
                                      DropdownMenuItem(value: 'UPI', child: Text('UPI (Corporate/Vendor ID)')),
                                      DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                                      DropdownMenuItem(value: 'CARD', child: Text('Corporate Card')),
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
                                      labelText: 'Reference # (UTR / Cheque #)',
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

                    // Purchase Bills Allocation Section
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
                                    const Text('Allocate to Purchase Bills', style: AppTextStyles.title),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Distribute payment across supplier bills or keep as unallocated advance.',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                                if (_outstandingBills.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: _autoAllocateFifo,
                                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                                    label: const Text('Auto-Allocate (FIFO)'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_isLoadingBills)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_selectedSupplierId == null)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'Select a supplier above to view their pending purchase bills.',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ),
                              )
                            else if (_outstandingBills.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.check_circle_outline_rounded,
                                          color: Color(0xFF10B981), size: 36),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'No open purchase bills pending payment for this supplier.',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Payment will be recorded as an advance payment on account.',
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
                                itemCount: _outstandingBills.length,
                                separatorBuilder: (_, __) => const Divider(height: 24),
                                itemBuilder: (context, index) {
                                  final bill = _outstandingBills[index];
                                  final ctrl = _allocationControllers[bill.id];

                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bill.billNumber,
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Date: ${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year} • Total: ₹${bill.totalAmount.toStringAsFixed(2)}',
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
                                              '₹${bill.balanceAmount.toStringAsFixed(2)}',
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
                              const Text('Total Payment Amount', style: TextStyle(fontSize: 15)),
                              Text(
                                '₹${_totalPaymentAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Allocated to Bills', style: TextStyle(fontSize: 15)),
                              Text(
                                '₹${_totalAllocatedAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: _totalAllocatedAmount > _totalPaymentAmount
                                      ? Colors.red
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _unallocatedAmount >= 0 ? 'Unallocated Advance to Supplier' : 'Over-Allocated Error',
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSubmitting ? null : _submitPayment,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Record Supplier Payment', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
