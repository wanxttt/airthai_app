import 'package:flutter/material.dart';

import '../../../../core/services/master_data_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../master_data/models/master_data_models.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<SupplierModel> _suppliers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _statusFilter = 'ACTIVE';

  double _totalPayables = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await MasterDataService.instance.getSuppliers(
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      status: _statusFilter,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _suppliers = res.data!;
        _totalPayables = _suppliers.fold(0.0, (sum, s) => sum + s.currentBalance);
      } else {
        _errorMessage = res.errorMessage ?? 'Failed to load suppliers.';
      }
    });
  }

  void _showSupplierFormDialog({SupplierModel? supplier}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final gstinCtrl = TextEditingController(text: supplier?.gstin ?? '');
    final panCtrl = TextEditingController(text: supplier?.pan ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final cityCtrl = TextEditingController(text: supplier?.city ?? '');
    final stateCtrl = TextEditingController(text: supplier?.state ?? '');
    final bankNameCtrl = TextEditingController(text: supplier?.bankName ?? '');
    final accountCtrl = TextEditingController(text: supplier?.accountNumber ?? '');
    final ifscCtrl = TextEditingController(text: supplier?.ifscCode ?? '');
    final openingBalCtrl = TextEditingController(
      text: supplier != null ? supplier.openingBalance.toString() : '0',
    );

    bool isSaving = false;
    String? formError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            supplier == null ? 'Add New Supplier' : 'Edit Supplier',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (formError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          formError!,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                        ),
                      ),
                    ],
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Name *',
                        hintText: 'e.g. National Distributors',
                        prefixIcon: Icon(Icons.local_shipping_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Supplier name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              hintText: '10-digit mobile',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'orders@supplier.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: gstinCtrl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 15,
                            decoration: const InputDecoration(
                              labelText: 'GSTIN',
                              hintText: '15-character GSTIN',
                              counterText: '',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: panCtrl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: 'PAN',
                              hintText: '10-character PAN',
                              counterText: '',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              hintText: 'e.g. Mumbai',
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: stateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              hintText: 'e.g. Maharashtra',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Address',
                        hintText: 'Warehouse / Building / Area',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Bank details
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: bankNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Bank Name',
                              hintText: 'e.g. HDFC Bank',
                              prefixIcon: Icon(Icons.account_balance_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: ifscCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'IFSC Code',
                              hintText: 'e.g. HDFC0000123',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: accountCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Bank Account Number',
                              hintText: 'e.g. 5010022334455',
                              prefixIcon: Icon(Icons.credit_card_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: openingBalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Opening Balance (₹)',
                              hintText: '0.00',
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
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSaving = true;
                        formError = null;
                      });

                      final payload = <String, dynamic>{
                        'name': nameCtrl.text.trim(),
                        if (phoneCtrl.text.trim().isNotEmpty) 'phone': phoneCtrl.text.trim(),
                        if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
                        if (gstinCtrl.text.trim().isNotEmpty)
                          'gstin': gstinCtrl.text.trim().toUpperCase(),
                        if (panCtrl.text.trim().isNotEmpty)
                          'pan': panCtrl.text.trim().toUpperCase(),
                        if (addressCtrl.text.trim().isNotEmpty)
                          'address': addressCtrl.text.trim(),
                        if (cityCtrl.text.trim().isNotEmpty) 'city': cityCtrl.text.trim(),
                        if (stateCtrl.text.trim().isNotEmpty) 'state': stateCtrl.text.trim(),
                        if (bankNameCtrl.text.trim().isNotEmpty)
                          'bankName': bankNameCtrl.text.trim(),
                        if (accountCtrl.text.trim().isNotEmpty)
                          'accountNumber': accountCtrl.text.trim(),
                        if (ifscCtrl.text.trim().isNotEmpty)
                          'ifscCode': ifscCtrl.text.trim().toUpperCase(),
                        'openingBalance': double.tryParse(openingBalCtrl.text.trim()) ?? 0.0,
                      };

                      final res = supplier == null
                          ? await MasterDataService.instance.createSupplier(payload)
                          : await MasterDataService.instance.updateSupplier(supplier.id, payload);

                      if (res.success) {
                        Navigator.pop(ctx);
                        _loadSuppliers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.primary,
                            content: Text(
                              supplier == null
                                  ? 'Supplier created successfully!'
                                  : 'Supplier updated successfully!',
                            ),
                          ),
                        );
                      } else {
                        setDialogState(() {
                          isSaving = false;
                          formError = res.errorMessage;
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(supplier == null ? 'Create Supplier' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupplierDetailsModal(SupplierModel s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: AppTextStyles.title),
                      if (s.phone != null)
                        Text(s.phone!, style: AppTextStyles.bodySecondary),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                _buildInfoColumn(
                  'Payable Balance',
                  '₹${s.currentBalance.toStringAsFixed(2)}',
                  color: s.currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                ),
                _buildInfoColumn('City / State', '${s.city ?? ''} ${s.state ?? ''}'),
                _buildInfoColumn('Status', s.status),
              ],
            ),
            const SizedBox(height: 20),
            if (s.gstin != null || s.pan != null) ...[
              Text(
                'Tax Identification: ${s.gstin != null ? 'GSTIN: ${s.gstin}  ' : ''}${s.pan != null ? 'PAN: ${s.pan}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
            if (s.bankName != null || s.accountNumber != null) ...[
              Text(
                'Bank Details: ${s.bankName ?? ''} • A/C: ${s.accountNumber ?? ''} • IFSC: ${s.ifscCode ?? ''}',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 20),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showSupplierFormDialog(supplier: s);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Supplier'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await MasterDataService.instance.toggleArchiveSupplier(s.id);
                    _loadSuppliers();
                  },
                  icon: Icon(s.isArchived ? Icons.unarchive_rounded : Icons.archive_outlined,
                      size: 16),
                  label: Text(s.isArchived ? 'Restore' : 'Archive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteSupplier(SupplierModel s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Supplier Deletion'),
        content: Text(
          'Are you sure you want to delete supplier "${s.name}"?\n\nIf this supplier has existing purchase bills or payment records, deletion will be blocked to preserve purchase history.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final res = await MasterDataService.instance.deleteSupplier(s.id);
      if (res.success) {
        _loadSuppliers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier deleted successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(res.errorMessage ?? 'Cannot delete supplier.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Top Summary Card
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.local_shipping_rounded,
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Suppliers', style: AppTextStyles.label),
                              Text('${_suppliers.length}', style: AppTextStyles.headingMedium),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Payables', style: AppTextStyles.label),
                              Text(
                                '₹${_totalPayables.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showSupplierFormDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Supplier'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search & Filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search suppliers by name, phone, PAN, or GSTIN...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _loadSuppliers();
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _loadSuppliers();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                    DropdownMenuItem(value: 'ARCHIVED', child: Text('Archived Only')),
                    DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _statusFilter = val);
                      _loadSuppliers();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Supplier List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Colors.red, size: 36),
                              const SizedBox(height: 8),
                              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                  onPressed: _loadSuppliers, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _suppliers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_shipping_outlined,
                                      color: AppColors.textMuted, size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No suppliers found', style: AppTextStyles.title),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Add suppliers to record purchase orders, bills and track payables.',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _showSupplierFormDialog(),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Add First Supplier'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _suppliers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final s = _suppliers[idx];
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
                                      radius: 20,
                                      backgroundColor: s.isArchived
                                          ? Colors.grey.shade200
                                          : AppColors.primaryLight,
                                      child: Text(
                                        s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: s.isArchived
                                              ? Colors.grey
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            s.name,
                                            style: AppTextStyles.title,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (s.gstin != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('GSTIN: ${s.gstin}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue.shade900)),
                                          ),
                                        ],
                                        if (s.isArchived) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('ARCHIVED',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.grey)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          if (s.phone != null) ...[
                                            Text(s.phone!, style: AppTextStyles.bodySecondary),
                                            const Text(' • ', style: AppTextStyles.bodySecondary),
                                          ],
                                          if (s.city != null)
                                            Text(s.city!, style: AppTextStyles.bodySecondary),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${s.currentBalance.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: s.currentBalance > 0
                                                    ? Colors.red.shade700
                                                    : Colors.green.shade700,
                                              ),
                                            ),
                                            const Text('Payable', style: AppTextStyles.label),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          onSelected: (val) {
                                            if (val == 'view') {
                                              _showSupplierDetailsModal(s);
                                            } else if (val == 'edit') {
                                              _showSupplierFormDialog(supplier: s);
                                            } else if (val == 'archive') {
                                              MasterDataService.instance
                                                  .toggleArchiveSupplier(s.id)
                                                  .then((_) => _loadSuppliers());
                                            } else if (val == 'delete') {
                                              _handleDeleteSupplier(s);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                                value: 'view', child: Text('View Details')),
                                            const PopupMenuItem(
                                                value: 'edit', child: Text('Edit Supplier')),
                                            PopupMenuItem(
                                              value: 'archive',
                                              child: Text(s.isArchived
                                                  ? 'Restore Supplier'
                                                  : 'Archive Supplier'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete',
                                                  style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showSupplierDetailsModal(s),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
