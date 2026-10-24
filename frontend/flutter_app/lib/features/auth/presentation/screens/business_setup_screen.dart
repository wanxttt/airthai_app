import 'package:flutter/material.dart';

import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_shell.dart';

class BusinessSetupScreen extends StatefulWidget {
  final String? initialBusinessName;

  const BusinessSetupScreen({
    super.key,
    this.initialBusinessName,
  });

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _businessNameController;
  final _legalNameController = TextEditingController();
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  String _taxType = 'REGULAR';
  String _billFormat = 'A4_STANDARD';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _indianStates = const [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
  ];

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController(
      text: widget.initialBusinessName ?? '',
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _legalNameController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _submitSetup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await SessionManager.instance.updateBusinessSetup(
        businessName: _businessNameController.text,
        legalName: _legalNameController.text.isNotEmpty
            ? _legalNameController.text
            : null,
        gstin: _gstinController.text.isNotEmpty ? _gstinController.text : null,
        pan: _panController.text.isNotEmpty ? _panController.text : null,
        addressLine1: _addressController.text.isNotEmpty
            ? _addressController.text
            : null,
        city: _cityController.text.isNotEmpty ? _cityController.text : null,
        state: _stateController.text.isNotEmpty ? _stateController.text : null,
        pincode:
            _pincodeController.text.isNotEmpty ? _pincodeController.text : null,
        taxType: _taxType,
        defaultBillFormat: _billFormat,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Business profile setup completed successfully!'),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred while saving setup.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _skip() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _skip,
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Business Onboarding',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Complete your business and tax profile for GST invoicing and reporting.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Business Name
                    _buildLabel('Business Name *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _businessNameController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Sharma Traders',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your business name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Legal / Trade Name
                    _buildLabel('Legal Name (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _legalNameController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Sharma Enterprises Pvt Ltd',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // GSTIN
                    _buildLabel('GSTIN (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _gstinController,
                      enabled: !_isLoading,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 15,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 27AAAAA0000A1Z5',
                        prefixIcon: Icon(Icons.receipt_rounded),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final gstinPattern = RegExp(
                            r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                          );
                          if (!gstinPattern.hasMatch(value.trim())) {
                            return 'Enter a valid 15-character GSTIN format';
                          }
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Tax Type & Bill Format Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Tax Regime'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _taxType,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'REGULAR',
                                    child: Text('Regular GST'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'COMPOSITION',
                                    child: Text('Composition'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'UNREGISTERED',
                                    child: Text('Unregistered'),
                                  ),
                                ],
                                onChanged: _isLoading
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() => _taxType = val);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Default Invoice'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _billFormat,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'A4_STANDARD',
                                    child: Text('A4 Standard'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'THERMAL_3INCH',
                                    child: Text('3-Inch Thermal'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'THERMAL_2INCH',
                                    child: Text('2-Inch Thermal'),
                                  ),
                                ],
                                onChanged: _isLoading
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() => _billFormat = val);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // State
                    _buildLabel('State / Union Territory'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: 'Select business state',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: _indianStates
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              if (val != null) {
                                _stateController.text = val;
                              }
                            },
                    ),

                    const SizedBox(height: 16),

                    // Address
                    _buildLabel('Business Address (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'Shop / Building / Street address',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitSetup,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save & Complete Setup',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _skip,
                        child: const Text(
                          'Skip for now and go to dashboard',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
