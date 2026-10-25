import 'package:flutter/material.dart';

import '../../../../core/services/payment_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/payment_models.dart';

class PaymentDetailScreen extends StatefulWidget {
  final PaymentModel payment;

  const PaymentDetailScreen({super.key, required this.payment});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  late PaymentModel _payment;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
    _refreshPayment();
  }

  Future<void> _refreshPayment() async {
    final res = await PaymentService.instance.getPayment(_payment.id);
    if (mounted && res.success && res.data != null) {
      setState(() => _payment = res.data!);
    }
  }

  Future<void> _showVoidDialog() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _payment.isCustomerReceipt ? 'Void Customer Receipt' : 'Void Supplier Payment',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voiding this payment will reverse all allocations, restore the balances on linked documents, and adjust the party outstanding balance.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Voiding *',
                hintText: 'e.g. Cheque returned, entry error, customer requested refund',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for voiding.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Void', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final res = await PaymentService.instance.voidPayment(_payment.id, reasonController.text.trim());
      if (mounted) {
        setState(() => _isLoading = false);
        if (res.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment voucher voided and balances reversed successfully.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.errorMessage ?? 'Failed to void payment.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReceipt = _payment.isCustomerReceipt;
    final badgeColor = isReceipt ? const Color(0xFF10B981) : const Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Voucher: ${_payment.paymentNumber}'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Void / Reverse Payment',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: _isLoading ? null : _showVoidDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Voucher Header Banner
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isReceipt ? 'CUSTOMER RECEIPT' : 'SUPPLIER PAYMENT',
                                style: TextStyle(
                                  color: badgeColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              'Date: ${_payment.paymentDate.day.toString().padLeft(2, '0')}/${_payment.paymentDate.month.toString().padLeft(2, '0')}/${_payment.paymentDate.year}',
                              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isReceipt ? 'Received From:' : 'Paid To:',
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _payment.partyName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Amount', style: AppTextStyles.caption),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${_payment.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: isReceipt ? const Color(0xFF10B981) : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Metadata Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Method', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.payment_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(_payment.formattedMethod, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Reference / Txn #', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Text(
                                _payment.referenceNumber?.isNotEmpty == true
                                    ? _payment.referenceNumber!
                                    : 'None recorded',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_payment.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Notes / Remarks', style: AppTextStyles.caption),
                          const SizedBox(height: 4),
                          Text(_payment.notes!, style: AppTextStyles.bodyPrimary),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Allocation Breakdown Section
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
                          Text(
                            isReceipt ? 'Allocated Invoices' : 'Allocated Purchase Bills',
                            style: AppTextStyles.title,
                          ),
                          const SizedBox(height: 16),
                          if (_payment.allocations.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This transaction was recorded as an unallocated advance credit on account.',
                                      style: AppTextStyles.bodySecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _payment.allocations.length,
                              separatorBuilder: (_, __) => const Divider(height: 20),
                              itemBuilder: (context, index) {
                                final alloc = _payment.allocations[index];
                                final docNumber = isReceipt
                                    ? (alloc.invoiceNumber ?? 'Invoice')
                                    : (alloc.billNumber ?? 'Bill');

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            isReceipt ? Icons.receipt_rounded : Icons.shopping_bag_rounded,
                                            size: 18,
                                            color: badgeColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          docNumber,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '₹${alloc.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ],
                                );
                              },
                            ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Allocated Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                '₹${_payment.totalAllocated.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ],
                          ),
                          if (_payment.unallocatedAmount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Unallocated Credit', style: TextStyle(color: Colors.blueGrey)),
                                Text(
                                  '₹${_payment.unallocatedAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
