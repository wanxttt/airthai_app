import 'package:flutter/material.dart';
import '../../../../core/services/master_data_service.dart';
import '../../../../core/services/sales_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../master_data/models/master_data_models.dart';

import 'invoice_detail_screen.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final VoidCallback? onInvoiceCreated;

  const CreateInvoiceScreen({super.key, this.onInvoiceCreated});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _LineItemDraft {
  String? productId;
  String description;
  String? hsnCode;
  double quantity;
  double unitPrice;
  double discountAmount = 0.0;
  double gstRate;

  _LineItemDraft({

    this.description = '',

    this.quantity = 1.0,
    this.unitPrice = 0.0,

    this.gstRate = 18.0,
  });

  double get gross => quantity * unitPrice;
  double get taxable => (gross - discountAmount).clamp(0.0, double.infinity);
  double get tax => taxable * (gstRate / 100.0);
  double get total => taxable + tax;
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();

  List<CustomerModel> _customers = [];
  List<ProductModel> _products = [];
  bool _isLoadingMeta = true;

  String? _selectedCustomerId;
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  String _placeOfSupply = '27'; // Default Maharashtra
  double _invoiceDiscount = 0.0;
  final _notesCtrl = TextEditingController();
  final _termsCtrl = TextEditingController(text: 'Payment due on receipt or per agreed terms.');

  final List<_LineItemDraft> _items = [
    _LineItemDraft(description: '', quantity: 1, unitPrice: 0.0, gstRate: 18.0),
  ];

  bool _isSubmitting = false;

  final Map<String, String> _indianStates = const {
    '27': '27 - Maharashtra',
    '24': '24 - Gujarat',
    '07': '07 - Delhi',
    '29': '29 - Karnataka',
    '33': '33 - Tamil Nadu',
    '09': '09 - Uttar Pradesh',
    '19': '19 - West Bengal',
    '36': '36 - Telangana',
    '06': '06 - Haryana',
    '08': '08 - Rajasthan',
  };

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final custRes = await MasterDataService.instance.getCustomers();
    final prodRes = await MasterDataService.instance.getProducts();

    if (mounted) {
      setState(() {
        _customers = custRes.data ?? [];
        _products = (prodRes.data ?? []).where((p) => !p.isArchived).toList();
        _isLoadingMeta = false;
      });
    }
  }

  // Live Totals
  double get _subtotal => _items.fold(0.0, (acc, it) => acc + it.gross);
  double get _lineDiscounts => _items.fold(0.0, (acc, it) => acc + it.discountAmount);
  double get _totalDiscount => _lineDiscounts + _invoiceDiscount;
  double get _taxableAmount => (_items.fold(0.0, (acc, it) => acc + it.taxable) - _invoiceDiscount).clamp(0.0, double.infinity);

  bool get _isInterState => _placeOfSupply != '27';

  double get _cgst => _isInterState ? 0.0 : _items.fold(0.0, (acc, it) => acc + (it.taxable * (it.gstRate / 200.0)));
  double get _sgst => _isInterState ? 0.0 : _items.fold(0.0, (acc, it) => acc + (it.taxable * (it.gstRate / 200.0)));
  double get _igst => _isInterState ? _items.fold(0.0, (acc, it) => acc + (it.taxable * (it.gstRate / 100.0))) : 0.0;
  double get _rawTotal => _taxableAmount + _cgst + _sgst + _igst;
  double get _roundOff => _rawTotal.roundToDouble() - _rawTotal;
  double get _grandTotal => _rawTotal.roundToDouble();

  void _onProductSelected(int index, String? productId) {
    if (productId == null) return;
    final prod = _products.firstWhere((p) => p.id == productId, orElse: () => _products.first);
    setState(() {
      _items[index].productId = prod.id;
      _items[index].description = prod.name;
      _items[index].unitPrice = prod.salePrice;
      _items[index].gstRate = prod.gstRate;
      _items[index].hsnCode = prod.hsnCode;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item.')),
      );
      return;
    }

    for (int i = 0; i < _items.length; i++) {
      if (_items[i].description.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a description for item #${i + 1}.')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final selectedCustomer = _customers.where((c) => c.id == _selectedCustomerId).firstOrNull;

    final payload = {
      if (_selectedCustomerId != null) 'customerId': _selectedCustomerId,
      if (selectedCustomer != null) 'customerName': selectedCustomer.name,
      if (selectedCustomer != null && selectedCustomer.phone != null)
        'customerPhone': selectedCustomer.phone,
      'invoiceDate': _invoiceDate.toIso8601String(),
      if (_dueDate != null) 'dueDate': _dueDate!.toIso8601String(),
      'placeOfSupply': _placeOfSupply,
      'discountAmount': _invoiceDiscount,
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
      if (_termsCtrl.text.isNotEmpty) 'terms': _termsCtrl.text.trim(),
      'items': _items.map((it) => it.toJson()).toList(),
    };

    final result = await SalesService.instance.createInvoice(payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success && result.data != null) {
      widget.onInvoiceCreated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('Invoice ${result.data!.invoiceNumber} issued successfully!'),
        ),
      );

      // Navigate to Detail
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoice: result.data!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(result.errorMessage ?? 'Failed to issue invoice.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMeta) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Tax Invoice'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Invoice Details Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Customer & Invoice Details', style: AppTextStyles.title),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedCustomerId,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer',
                                    prefixIcon: Icon(Icons.person_outline_rounded),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        'Walk-in Customer (Cash Sale)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ..._customers.map((c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(
                                            '${c.name} (Bal: ₹${c.currentBalance.toStringAsFixed(0)})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedCustomerId = val;
                                      if (val != null) {
                                        final cust = _customers.firstWhere((c) => c.id == val);
                                        if (cust.state != null && _indianStates.containsKey(cust.state)) {
                                          _placeOfSupply = cust.state!;
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _placeOfSupply,
                                  decoration: const InputDecoration(
                                    labelText: 'Place of Supply',
                                    prefixIcon: Icon(Icons.location_on_outlined),
                                  ),
                                  items: _indianStates.entries
                                      .map((e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(e.value, overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _placeOfSupply = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Invoice Date', style: AppTextStyles.label),
                                  subtitle: Text(
                                    '${_invoiceDate.day}/${_invoiceDate.month}/${_invoiceDate.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _invoiceDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (d != null) setState(() => _invoiceDate = d);
                                  },
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Payment Due Date', style: AppTextStyles.label),
                                  subtitle: Text(
                                    _dueDate != null
                                        ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                        : 'Immediate / None',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  leading: const Icon(Icons.event_available_rounded, color: AppColors.primary),
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _dueDate ?? _invoiceDate.add(const Duration(days: 30)),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (d != null) setState(() => _dueDate = d);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Items Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Line Items', style: AppTextStyles.title),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _items.add(_LineItemDraft(
                                      description: '',
                                      quantity: 1,
                                      unitPrice: 0.0,
                                      gstRate: 18.0,
                                    ));
                                  });
                                },
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Item'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          ..._items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          initialValue: item.productId,
                                          decoration: const InputDecoration(
                                            labelText: 'Select Product',
                                            isDense: true,
                                          ),
                                          items: [
                                            const DropdownMenuItem(
                                              value: null,
                                              child: Text('Custom Item (Non-Inventory)'),
                                            ),
                                            ..._products.map((p) => DropdownMenuItem(
                                                  value: p.id,
                                                  child: Text(
                                                    '${p.name} (Stock: ${p.currentStock.toStringAsFixed(0)})',
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                )),
                                          ],
                                          onChanged: (val) => _onProductSelected(idx, val),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          initialValue: item.description,
                                          decoration: const InputDecoration(
                                            labelText: 'Item Description *',
                                            isDense: true,
                                          ),
                                          onChanged: (v) => item.description = v,
                                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                        ),
                                      ),
                                      if (_items.length > 1) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                          onPressed: () => setState(() => _items.removeAt(idx)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.quantity.toStringAsFixed(0),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Qty',
                                            isDense: true,
                                          ),
                                          onChanged: (v) {
                                            setState(() {
                                              item.quantity = double.tryParse(v) ?? 1.0;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.unitPrice.toStringAsFixed(2),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Rate (₹)',
                                            isDense: true,
                                          ),
                                          onChanged: (v) {
                                            setState(() {
                                              item.unitPrice = double.tryParse(v) ?? 0.0;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.discountAmount.toStringAsFixed(2),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Discount (₹)',
                                            isDense: true,
                                          ),
                                          onChanged: (v) {
                                            setState(() {
                                              item.discountAmount = double.tryParse(v) ?? 0.0;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<double>(
                                          isExpanded: true,
                                          initialValue: item.gstRate,
                                          decoration: const InputDecoration(
                                            labelText: 'GST Rate',
                                            isDense: true,
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 0.0, child: Text('0% (Exempt)')),
                                            DropdownMenuItem(value: 5.0, child: Text('5%')),
                                            DropdownMenuItem(value: 12.0, child: Text('12%')),
                                            DropdownMenuItem(value: 18.0, child: Text('18%')),
                                            DropdownMenuItem(value: 28.0, child: Text('28%')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) setState(() => item.gstRate = v);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('Line Total', style: AppTextStyles.label),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₹${item.total.toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Notes & Live Preview
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Additional Details', style: AppTextStyles.title),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notesCtrl,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer Notes',
                                    hintText: 'e.g. Thanks for your business!',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _termsCtrl,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Terms & Conditions',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Authoritative Calculation', style: AppTextStyles.title),
                                const SizedBox(height: 12),
                                _buildPreviewRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
                                if (_totalDiscount > 0)
                                  _buildPreviewRow('Discounts', '-₹${_totalDiscount.toStringAsFixed(2)}', color: Colors.green),
                                _buildPreviewRow('Taxable Amount', '₹${_taxableAmount.toStringAsFixed(2)}'),
                                if (!_isInterState) ...[
                                  _buildPreviewRow('CGST (9%)', '₹${_cgst.toStringAsFixed(2)}'),
                                  _buildPreviewRow('SGST (9%)', '₹${_sgst.toStringAsFixed(2)}'),
                                ] else ...[
                                  _buildPreviewRow('IGST (18%)', '₹${_igst.toStringAsFixed(2)}'),
                                ],
                                if (_roundOff != 0)
                                  _buildPreviewRow('Round Off', '${_roundOff > 0 ? '+' : ''}₹${_roundOff.toStringAsFixed(2)}'),
                                const Divider(height: 20),
                                _buildPreviewRow(
                                  'Grand Total',
                                  '₹${_grandTotal.toStringAsFixed(2)}',
                                  isBold: true,
                                  fontSize: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _handleSubmit,
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text('Generate & Issue Invoice'),
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  Widget _buildPreviewRow(String label, String value,
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

extension _LineItemDraftExt on _LineItemDraft {
  Map<String, dynamic> toJson() => {
        if (productId != null) 'productId': productId,
        'description': description,
        if (hsnCode != null) 'hsnCode': hsnCode,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountAmount': discountAmount,
        'gstRate': gstRate,
      };
}

