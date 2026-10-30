import 'package:flutter/material.dart';
import '../../../../core/services/master_data_service.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../master_data/models/master_data_models.dart';

import 'purchase_detail_screen.dart';

class CreatePurchaseScreen extends StatefulWidget {
  final VoidCallback? onPurchaseCreated;

  const CreatePurchaseScreen({super.key, this.onPurchaseCreated});

  @override
  State<CreatePurchaseScreen> createState() => _CreatePurchaseScreenState();
}

class _PurchaseLineItemDraft {
  String productId;
  String description;
  String? hsnCode;
  double quantity = 1.0;
  double unitCost;
  double taxRate;

  _PurchaseLineItemDraft({
    required this.productId,
    this.description = '',
    this.hsnCode,
    // quantity initialized below
    this.unitCost = 0.0,
    this.taxRate = 18.0,
  });

  double get gross => quantity * unitCost;
  double get tax => gross * (taxRate / 100.0);
  double get total => gross + tax;
}

class _CreatePurchaseScreenState extends State<CreatePurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  List<SupplierModel> _suppliers = [];
  List<ProductModel> _products = [];
  bool _isLoadingMeta = true;

  String? _selectedSupplierId;
  final _billNumberCtrl = TextEditingController();
  DateTime _billDate = DateTime.now();
  String _status = 'RECEIVED';
  final _notesCtrl = TextEditingController();

  final List<_PurchaseLineItemDraft> _items = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final suppRes = await MasterDataService.instance.getSuppliers();
    final prodRes = await MasterDataService.instance.getProducts();

    if (mounted) {
      setState(() {
        _suppliers = suppRes.data ?? [];
        _products = (prodRes.data ?? []).where((p) => !p.isArchived).toList();
        _isLoadingMeta = false;

        if (_products.isNotEmpty) {
          final first = _products.first;
          _items.add(
            _PurchaseLineItemDraft(
              productId: first.id,
              description: first.name,
              unitCost: first.purchasePrice,
              taxRate: first.gstRate,
              hsnCode: first.hsnCode,
            ),
          );
        }
      });
    }
  }

  double get _subtotal => _items.fold(0.0, (acc, it) => acc + it.gross);
  double get _totalTax => _items.fold(0.0, (acc, it) => acc + it.tax);
  double get _grandTotal => _subtotal + _totalTax;

  void _onProductSelected(int index, String? productId) {
    if (productId == null) return;
    final prod = _products.firstWhere((p) => p.id == productId, orElse: () => _products.first);
    setState(() {
      _items[index].productId = prod.id;
      _items[index].description = prod.name;
      _items[index].unitCost = prod.purchasePrice;
      _items[index].taxRate = prod.gstRate;
      _items[index].hsnCode = prod.hsnCode;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier.')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final selectedSupplier = _suppliers.where((s) => s.id == _selectedSupplierId).firstOrNull;

    final payload = {
      'supplierId': _selectedSupplierId,
      if (selectedSupplier != null) 'supplierName': selectedSupplier.name,
      if (selectedSupplier != null && selectedSupplier.gstin != null)
        'supplierGstin': selectedSupplier.gstin,
      'billNumber': _billNumberCtrl.text.trim(),
      'billDate': _billDate.toIso8601String(),
      'status': _status,
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
      'items': _items.map((it) => {
            'productId': it.productId,
            'description': it.description,
            if (it.hsnCode != null) 'hsnCode': it.hsnCode,
            'quantity': it.quantity,
            'unitCost': it.unitCost,
            'taxRate': it.taxRate,
          }).toList(),
    };

    final res = await PurchaseService.instance.createPurchase(payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.success && res.data != null) {
      widget.onPurchaseCreated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('Purchase bill ${res.data!.billNumber} saved successfully!'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PurchaseDetailScreen(purchase: res.data!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(res.errorMessage ?? 'Failed to create purchase bill.'),
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
        title: const Text('New Purchase Bill'),
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
                  // Bill Information
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
                          const Text('Supplier & Bill Details', style: AppTextStyles.title),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedSupplierId,
                                  decoration: const InputDecoration(
                                    labelText: 'Supplier *',
                                    prefixIcon: Icon(Icons.local_shipping_outlined),
                                  ),
                                  items: _suppliers
                                      .map((s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Text(
                                              '${s.name} (Payable: ₹${s.currentBalance.toStringAsFixed(0)})',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedSupplierId = val),
                                  validator: (v) => v == null ? 'Please select a supplier' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _billNumberCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Supplier Bill / Invoice # *',
                                    hintText: 'e.g. INV-9902',
                                    prefixIcon: Icon(Icons.tag_rounded),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Bill number is required'
                                      : null,
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
                                  title: const Text('Bill Date', style: AppTextStyles.label),
                                  subtitle: Text(
                                    '${_billDate.day}/${_billDate.month}/${_billDate.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _billDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (d != null) setState(() => _billDate = d);
                                  },
                                ),
                              ),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _status,
                                  decoration: const InputDecoration(
                                    labelText: 'Purchase State',
                                    prefixIcon: Icon(Icons.inventory_rounded),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'RECEIVED',
                                      child: Text(
                                        'Confirm & Receive into Stock (Instant)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'ORDERED',
                                      child: Text(
                                        'Save as Purchase Order (Draft)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _status = v);
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

                  // Line Items
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
                              const Text('Purchased Items', style: AppTextStyles.title),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (_products.isNotEmpty) {
                                    final first = _products.first;
                                    setState(() {
                                      _items.add(
                                        _PurchaseLineItemDraft(
                                          productId: first.id,
                                          description: first.name,
                                          unitCost: first.purchasePrice,
                                          taxRate: first.gstRate,
                                        ),
                                      );
                                    });
                                  }
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
                                            labelText: 'Product *',
                                            isDense: true,
                                          ),
                                          items: _products
                                              .map((p) => DropdownMenuItem(
                                                    value: p.id,
                                                    child: Text(
                                                      '${p.name} (Cur: ${p.currentStock.toStringAsFixed(0)})',
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ))
                                              .toList(),
                                          onChanged: (val) => _onProductSelected(idx, val),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          initialValue: item.description,
                                          decoration: const InputDecoration(
                                            labelText: 'Description',
                                            isDense: true,
                                          ),
                                          onChanged: (v) => item.description = v,
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
                                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
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
                                          initialValue: item.unitCost.toStringAsFixed(2),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(labelText: 'Unit Cost (₹)', isDense: true),
                                          onChanged: (v) {
                                            setState(() {
                                              item.unitCost = double.tryParse(v) ?? 0.0;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<double>(
                                          initialValue: item.taxRate,
                                          decoration: const InputDecoration(labelText: 'Tax Rate', isDense: true),
                                          items: const [
                                            DropdownMenuItem(value: 0.0, child: Text('0% (Exempt)')),
                                            DropdownMenuItem(value: 5.0, child: Text('5%')),
                                            DropdownMenuItem(value: 12.0, child: Text('12%')),
                                            DropdownMenuItem(value: 18.0, child: Text('18%')),
                                            DropdownMenuItem(value: 28.0, child: Text('28%')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) setState(() => item.taxRate = v);
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

                  // Notes & Summary
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
                                const Text('Notes', style: AppTextStyles.title),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notesCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Additional Notes / Tracking Reference',
                                    hintText: 'e.g., Lorry receipt #, delivery challan #',
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
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Purchase Bill Summary', style: AppTextStyles.title),
                                ),
                                const SizedBox(height: 12),
                                _buildSummaryLine('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
                                _buildSummaryLine('Tax Amount', '₹${_totalTax.toStringAsFixed(2)}'),
                                const Divider(height: 20),
                                _buildSummaryLine(
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
                                        : Text(_status == 'RECEIVED'
                                            ? 'Confirm & Receive into Stock'
                                            : 'Save Purchase Order'),
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
