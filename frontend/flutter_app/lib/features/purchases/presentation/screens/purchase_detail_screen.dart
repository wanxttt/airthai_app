import 'package:flutter/material.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/purchase_models.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final PurchaseModel purchase;
  final VoidCallback? onPurchaseUpdated;

  const PurchaseDetailScreen({
    super.key,
    required this.purchase,
    this.onPurchaseUpdated,
  });

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  late PurchaseModel _currentPurchase;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentPurchase = widget.purchase;
  }

  Future<void> _handleReceivePurchase() async {
    setState(() => _isProcessing = true);
    final res = await PurchaseService.instance.receivePurchase(_currentPurchase.id);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (res.success && res.data != null) {
      setState(() => _currentPurchase = res.data!);
      widget.onPurchaseUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Purchase received and inventory updated successfully!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(res.errorMessage ?? 'Failed to receive purchase.'),
        ),
      );
    }
  }

  Future<void> _handleCancelPurchase() async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Purchase Bill'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel purchase bill ${_currentPurchase.billNumber}?\n\nIf the goods were already received, this will reverse the stock movements and reduce the supplier payable balance.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason *',
                  hintText: 'e.g., Goods damaged, wrong bill entered',
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter a reason' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Bill'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final res = await PurchaseService.instance.cancelPurchase(
        _currentPurchase.id,
        reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (res.success && res.data != null) {
        setState(() => _currentPurchase = res.data!);
        widget.onPurchaseUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Purchase bill cancelled and stock reversed.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(res.errorMessage ?? 'Failed to cancel purchase.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _currentPurchase;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(p.billNumber),
        actions: [
          if (p.isOrdered)
            TextButton.icon(
              onPressed: _isProcessing ? null : _handleReceivePurchase,
              icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
              label: const Text('Receive Goods', style: TextStyle(color: Colors.green)),
            ),
          if (!p.isCancelled)
            IconButton(
              tooltip: 'Cancel Purchase',
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              onPressed: _isProcessing ? null : _handleCancelPurchase,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PURCHASE BILL',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                    letterSpacing: 1.2,
                                  )),
                              const SizedBox(height: 6),
                              Text(p.billNumber,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  )),
                              const SizedBox(height: 4),
                              Text(
                                'Date: ${p.billDate.day}/${p.billDate.month}/${p.billDate.year}',
                                style: AppTextStyles.bodySecondary,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: p.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: p.statusColor),
                          ),
                          child: Text(
                            p.status,
                            style: TextStyle(
                              color: p.statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 36),

                    // Supplier Information
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SUPPLIER', style: AppTextStyles.label),
                              const SizedBox(height: 6),
                              Text(
                                p.supplierName ?? 'Supplier',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              if (p.supplierGstin != null)
                                Text('GSTIN: ${p.supplierGstin}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('PAYMENT DETAILS', style: AppTextStyles.label),
                              const SizedBox(height: 6),
                              Text('Payment Status: ${p.paymentStatus}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Outstanding Balance: ₹${p.balanceAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: p.balanceAmount > 0 ? Colors.orange.shade800 : Colors.green,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Items Table
                    const Text('PURCHASED ITEMS', style: AppTextStyles.label),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Container(
                            color: Colors.grey.shade50,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                Expanded(child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                Expanded(child: Text('Unit Cost (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                Expanded(child: Text('Tax Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                Expanded(child: Text('Total (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ...p.items.map((it) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(it.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          if (it.hsnCode != null)
                                            Text('HSN: ${it.hsnCode}', style: AppTextStyles.label),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(it.quantity.toStringAsFixed(0), textAlign: TextAlign.center),
                                    ),
                                    Expanded(
                                      child: Text(it.unitCost.toStringAsFixed(2), textAlign: TextAlign.right),
                                    ),
                                    Expanded(
                                      child: Text('${it.taxRate.toStringAsFixed(0)}%', textAlign: TextAlign.right),
                                    ),
                                    Expanded(
                                      child: Text(it.totalAmount.toStringAsFixed(2),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Totals Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (p.notes != null) ...[
                                const Text('Notes', style: AppTextStyles.label),
                                const SizedBox(height: 4),
                                Text(p.notes!, style: AppTextStyles.bodySecondary),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                _buildSummaryLine('Subtotal', '₹${p.subtotal.toStringAsFixed(2)}'),
                                _buildSummaryLine('Tax Amount', '₹${p.taxAmount.toStringAsFixed(2)}'),
                                const Divider(height: 16),
                                _buildSummaryLine(
                                  'Grand Total',
                                  '₹${p.totalAmount.toStringAsFixed(2)}',
                                  isBold: true,
                                  fontSize: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 6),
                                _buildSummaryLine(
                                  'Payable Balance',
                                  '₹${p.balanceAmount.toStringAsFixed(2)}',
                                  isBold: true,
                                  color: p.balanceAmount > 0 ? Colors.orange.shade800 : Colors.green,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value,
      {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontSize: fontSize,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              fontSize: fontSize,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
