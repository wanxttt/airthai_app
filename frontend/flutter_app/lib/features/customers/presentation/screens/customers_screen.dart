import 'package:flutter/material.dart';

import '../../../../core/services/master_data_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../master_data/models/master_data_models.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _statusFilter = 'ACTIVE';

  double _totalReceivables = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await MasterDataService.instance.getCustomers(
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      status: _statusFilter,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _customers = res.data!;
        _totalReceivables = _customers.fold(0.0, (sum, c) => sum + c.currentBalance);
      } else {
        _errorMessage = res.errorMessage ?? 'Failed to load customers.';
      }
    });
  }

  void _showCustomerFormDialog({CustomerModel? customer}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final gstinCtrl = TextEditingController(text: customer?.gstin ?? '');
    final addressCtrl = TextEditingController(text: customer?.billingAddress ?? '');
    final cityCtrl = TextEditingController(text: customer?.city ?? '');
    final stateCtrl = TextEditingController(text: customer?.state ?? '');
    final openingBalCtrl = TextEditingController(
      text: customer != null ? customer.openingBalance.toString() : '0',
    );
    final creditLimitCtrl = TextEditingController(
      text: customer?.creditLimit != null ? customer!.creditLimit.toString() : '',
    );
    final creditPeriodCtrl = TextEditingController(
      text: customer != null ? customer.creditPeriodDays.toString() : '0',
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
            customer == null ? 'Add New Customer' : 'Edit Customer',
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
                        labelText: 'Customer / Business Name *',
                        hintText: 'e.g. Gupta Traders',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Customer name is required'
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
                              hintText: 'name@example.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: gstinCtrl,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 15,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN (Optional)',
                        hintText: 'e.g. 27AAAAA0000A1Z5',
                        counterText: '',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final gstinPattern = RegExp(
                            r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                          );
                          if (!gstinPattern.hasMatch(val.trim())) {
                            return 'Enter a valid 15-character GSTIN';
                          }
                        }
                        return null;
                      },
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
                              prefixIcon: Icon(Icons.map_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Billing Address',
                        hintText: 'Shop / Street / Area',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: openingBalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Opening Balance (₹)',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.currency_rupee_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: creditLimitCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Credit Limit (₹)',
                              hintText: '0.00',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: creditPeriodCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Credit Days',
                              hintText: '30',
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
                        if (addressCtrl.text.trim().isNotEmpty)
                          'billingAddress': addressCtrl.text.trim(),
                        if (cityCtrl.text.trim().isNotEmpty) 'city': cityCtrl.text.trim(),
                        if (stateCtrl.text.trim().isNotEmpty) 'state': stateCtrl.text.trim(),
                        'openingBalance': double.tryParse(openingBalCtrl.text.trim()) ?? 0.0,
                        if (creditLimitCtrl.text.trim().isNotEmpty)
                          'creditLimit': double.tryParse(creditLimitCtrl.text.trim()),
                        'creditPeriodDays': int.tryParse(creditPeriodCtrl.text.trim()) ?? 0,
                      };

                      final res = customer == null
                          ? await MasterDataService.instance.createCustomer(payload)
                          : await MasterDataService.instance.updateCustomer(customer.id, payload);

                      if (res.success) {
                        Navigator.pop(ctx);
                        _loadCustomers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.primary,
                            content: Text(
                              customer == null
                                  ? 'Customer created successfully!'
                                  : 'Customer updated successfully!',
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
                  : Text(customer == null ? 'Create Customer' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDetailsModal(CustomerModel c) {
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
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
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
                      Text(c.name, style: AppTextStyles.title),
                      if (c.phone != null)
                        Text(c.phone!, style: AppTextStyles.bodySecondary),
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
                  'Receivable Balance',
                  '₹${c.currentBalance.toStringAsFixed(2)}',
                  color: c.currentBalance > 0 ? Colors.orange.shade800 : Colors.green.shade700,
                ),
                _buildInfoColumn(
                  'Credit Limit',
                  c.creditLimit != null ? '₹${c.creditLimit!.toStringAsFixed(2)}' : 'No Limit',
                ),
                _buildInfoColumn('Credit Period', '${c.creditPeriodDays} days'),
              ],
            ),
            const SizedBox(height: 20),
            if (c.gstin != null) ...[
              Text('GSTIN: ${c.gstin}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
            ],
            if (c.billingAddress != null) ...[
              Text('Address: ${c.billingAddress}, ${c.city ?? ''} ${c.state ?? ''}',
                  style: AppTextStyles.bodySecondary),
              const SizedBox(height: 20),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCustomerFormDialog(customer: c);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Customer'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await MasterDataService.instance.toggleArchiveCustomer(c.id);
                    _loadCustomers();
                  },
                  icon: Icon(c.isArchived ? Icons.unarchive_rounded : Icons.archive_outlined,
                      size: 16),
                  label: Text(c.isArchived ? 'Restore' : 'Archive'),
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

  Future<void> _handleDeleteCustomer(CustomerModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Customer Deletion'),
        content: Text(
          'Are you sure you want to delete customer "${c.name}"?\n\nIf this customer has existing invoices or payments, the system will prevent deletion to preserve your accounting history.',
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
      final res = await MasterDataService.instance.deleteCustomer(c.id);
      if (res.success) {
        _loadCustomers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer deleted successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(res.errorMessage ?? 'Cannot delete customer.'),
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
            // Top Summary & Add button
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
                            child: const Icon(Icons.people_rounded, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Customers', style: AppTextStyles.label),
                              Text('${_customers.length}', style: AppTextStyles.headingMedium),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Receivables', style: AppTextStyles.label),
                              Text(
                                '₹${_totalReceivables.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
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
                  onPressed: () => _showCustomerFormDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Customer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search & Filter bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customers by name, phone, or GSTIN...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _loadCustomers();
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _loadCustomers();
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
                      _loadCustomers();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Customer List
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
                                  onPressed: _loadCustomers, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _customers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_outline_rounded,
                                      color: AppColors.textMuted, size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No customers found', style: AppTextStyles.title),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Add customers to issue invoices, track balances and manage credits.',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _showCustomerFormDialog(),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Add First Customer'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _customers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final c = _customers[idx];
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
                                      backgroundColor: c.isArchived
                                          ? Colors.grey.shade200
                                          : AppColors.primaryLight,
                                      child: Text(
                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: c.isArchived
                                              ? Colors.grey
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            c.name,
                                            style: AppTextStyles.title,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (c.gstin != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('GSTIN: ${c.gstin}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue.shade900)),
                                          ),
                                        ],
                                        if (c.isArchived) ...[
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
                                          if (c.phone != null) ...[
                                            Text(c.phone!, style: AppTextStyles.bodySecondary),
                                            const Text(' • ', style: AppTextStyles.bodySecondary),
                                          ],
                                          if (c.city != null)
                                            Text(c.city!, style: AppTextStyles.bodySecondary),
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
                                              '₹${c.currentBalance.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: c.currentBalance > 0
                                                    ? Colors.orange.shade800
                                                    : Colors.green.shade700,
                                              ),
                                            ),
                                            const Text('Receivable', style: AppTextStyles.label),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          onSelected: (val) {
                                            if (val == 'view') {
                                              _showCustomerDetailsModal(c);
                                            } else if (val == 'edit') {
                                              _showCustomerFormDialog(customer: c);
                                            } else if (val == 'archive') {
                                              MasterDataService.instance
                                                  .toggleArchiveCustomer(c.id)
                                                  .then((_) => _loadCustomers());
                                            } else if (val == 'delete') {
                                              _handleDeleteCustomer(c);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                                value: 'view', child: Text('View Details')),
                                            const PopupMenuItem(
                                                value: 'edit', child: Text('Edit Customer')),
                                            PopupMenuItem(
                                              value: 'archive',
                                              child: Text(c.isArchived
                                                  ? 'Restore Customer'
                                                  : 'Archive Customer'),
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
                                    onTap: () => _showCustomerDetailsModal(c),
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
