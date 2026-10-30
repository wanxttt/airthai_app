import 'package:flutter/material.dart';

import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'package:airthai/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:airthai/features/legal/presentation/screens/terms_screen.dart';

/// Primary Product Landing Screen & Feature Showcase for AirthAI.
///
/// Phase 2 & 3: Professional Brand Presence & Conversion Architecture
/// Eliminates generic AI gradients, pill buttons, fake social proof, and vague copy.
/// Delivers an authoritative, trustworthy presentation of GST billing, inventory,
/// double-entry accounting, and read-only AI Copilot capabilities.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _accountingKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildNavigationBar(context),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // 1. Hero Section
            _buildHeroSection(context),

            // 2. Core Operational Pillars
            _buildCorePillars(context),

            // 3. In-Depth Capabilities (Features Anchor)
            Container(key: _featuresKey, child: _buildCapabilitiesSection(context)),

            // 4. Double-Entry Accounting & Statutory GST (Accounting Anchor)
            Container(key: _accountingKey, child: _buildAccountingSection(context)),

            // 5. Read-Only AI Business Copilot
            _buildCopilotSection(context),

            // 6. Transparent Pricing Plans (Pricing Anchor)
            Container(key: _pricingKey, child: _buildPricingSection(context)),

            // 7. Frequently Asked Questions (FAQ Anchor)
            Container(key: _faqKey, child: _buildFaqSection(context)),

            // 8. Conversion Call-To-Action Banner
            _buildCtaBanner(context),

            // 9. Professional Footer with Legal Links
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNavigationBar(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 860;

    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleSpacing: 24,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'AirthAI',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
      actions: [
        if (isDesktop) ...[
          TextButton(
            onPressed: () => _scrollToKey(_featuresKey),
            child: const Text('Capabilities', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => _scrollToKey(_accountingKey),
            child: const Text('Accounting & GST', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => _scrollToKey(_pricingKey),
            child: const Text('Pricing', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => _scrollToKey(_faqKey),
            child: const Text('FAQ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, RouteNames.login),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: Size.zero,
            ),
            child: const Text('Sign in'),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, RouteNames.register),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              minimumSize: Size.zero,
            ),
            child: const Text('Get Started'),
          ),
          const SizedBox(width: 24),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.pushNamed(context, RouteNames.login),
            child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            onPressed: () => _showMobileMenu(context),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.checklist_rounded, color: AppColors.primary),
                title: const Text('Capabilities'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scrollToKey(_featuresKey);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_rounded, color: AppColors.primary),
                title: const Text('Accounting & GST Returns'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scrollToKey(_accountingKey);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sell_outlined, color: AppColors.primary),
                title: const Text('Pricing & Plans'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scrollToKey(_pricingKey);
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                title: const Text('Frequently Asked Questions'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scrollToKey(_faqKey);
                },
              ),
              const Divider(),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, RouteNames.register);
                },
                child: const Text('Create Free Account'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, RouteNames.login);
                },
                child: const Text('Sign in to Workspace'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 940;

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isDesktop ? 64 : 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: _buildHeroCopy(context)),
                    const SizedBox(width: 48),
                    Expanded(flex: 5, child: _buildHeroInteractiveCard()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCopy(context),
                    const SizedBox(height: 40),
                    _buildHeroInteractiveCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroCopy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'GST-COMPLIANT BILLING & DOUBLE-ENTRY LEDGER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Run your business on accurate numbers, from invoice to tax return.',
          style: TextStyle(
            fontSize: 38,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'AirthAI delivers an offline-first workspace uniting GST tax invoicing, live inventory management, balanced double-entry accounting, and read-only AI business insights for Indian MSMEs.',
          style: TextStyle(
            fontSize: 16,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, RouteNames.register),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Start Free Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, RouteNames.login),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('Sign in to Workspace', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildCheckmarkItem('100% Offline-First (SQLite)'),
            _buildCheckmarkItem('GSTR-1 & GSTR-3B Ready'),
            _buildCheckmarkItem('Real-Time Trial Balance'),
            _buildCheckmarkItem('Strict Tenant Isolation'),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckmarkItem(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroInteractiveCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusMedium)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.receipt_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Tax Invoice • INV-2026-27-0042',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ISSUED • GST BALANCED',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // Invoice Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 10,
                  children: const [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Billed To Customer', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        SizedBox(height: 2),
                        Text('Shree Ganesh Hardware', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('GSTIN: 27AABCU9603R1ZM • Maharashtra', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Place of Supply', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        SizedBox(height: 2),
                        Text('27 - Intra-State', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        Text('CGST (9%) + SGST (9%)', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),

                // Line Item
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Industrial Safety Helmet (HSN 6506)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          Text('Qty: 25 Units @ ₹600.00', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Text('₹15,000.00', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Calculations
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: const [
                      _SummaryLine(label: 'Taxable Value', value: '₹15,000.00'),
                      SizedBox(height: 4),
                      _SummaryLine(label: 'Central GST (CGST 9%)', value: '₹1,350.00'),
                      SizedBox(height: 4),
                      _SummaryLine(label: 'State GST (SGST 9%)', value: '₹1,350.00'),
                      Divider(height: 12, color: AppColors.border),
                      _SummaryLine(
                        label: 'Total Invoice Value (INR)',
                        value: '₹17,700.00',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Live Operational Badges
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ledger Vouchers Balanced',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '28 Units in Stock',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                              ),
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
        ],
      ),
    );
  }

  Widget _buildCorePillars(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const Text(
                'DESIGNED SPECIFICALLY FOR INDIAN COMMERCIAL ENTERPRISES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Complete financial control from point of sale to monthly compliance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 36),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 840;
                  final width = isWide ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth;

                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      _buildPillarCard(
                        icon: Icons.wifi_off_rounded,
                        title: '100% Offline-First Operation',
                        description:
                            'Never stall your billing counter when broadband drops. Local SQLite storage maintains transactional integrity and auto-syncs with backend sequence engines on reconnect.',
                        width: width,
                      ),
                      _buildPillarCard(
                        icon: Icons.account_balance_rounded,
                        title: 'Double-Entry General Ledger',
                        description:
                            'Every invoice, expense, and receipt automatically records balancing debit and credit entries. Real-time Trial Balance and P&L reports guarantee financial reconciliation.',
                        width: width,
                      ),
                      _buildPillarCard(
                        icon: Icons.analytics_outlined,
                        title: 'Read-Only AI Copilot',
                        description:
                            'Ask questions regarding low-stock products, overdue customer balances, and sales performance. Architecturally read-only to eliminate any risk of unverified data mutation.',
                        width: width,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarCard({
    required IconData icon,
    required String title,
    required String description,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(fontSize: 13, height: 1.55, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCapabilitiesSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OPERATIONAL CAPABILITIES', style: AppTextStyles.label),
              const SizedBox(height: 8),
              const Text(
                'Engineered for wholesale, distribution, and retail workflows',
                style: AppTextStyles.headingLarge,
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 840;
                  final width = isWide ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth;

                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      _buildCapabilityItem(
                        icon: Icons.receipt_long_rounded,
                        title: 'GST-Compliant Sales & Quotations',
                        bullets: const [
                          'Automated intra-state (CGST + SGST) vs inter-state (IGST) taxation.',
                          'Support for reverse charge, HSN/SAC classifications, and rounding rules.',
                          'Seamless conversion from quotation to authoritative tax invoice.',
                          'Multi-tenant sequence generation ensuring unbroken financial auditing.',
                        ],
                        width: width,
                      ),
                      _buildCapabilityItem(
                        icon: Icons.inventory_2_rounded,
                        title: 'Live Inventory & Stock Locking',
                        bullets: const [
                          'Strict row-level locks prevent overselling during concurrent billing.',
                          'Opening stock balance initialization and categorized adjustments (ADD/SUB).',
                          'Automated reorder point alerts when items fall below safety thresholds.',
                          'Item-level valuation reconciliation with general ledger asset accounts.',
                        ],
                        width: width,
                      ),
                      _buildCapabilityItem(
                        icon: Icons.payments_rounded,
                        title: 'Receipts & Vendor Settlements',
                        bullets: const [
                          'Customer payment recording with automated FIFO invoice allocation.',
                          'Vendor bill payment allocation preventing over-disbursement.',
                          'Real-time receivables and payables ageing analysis.',
                          'Support for multiple payment instruments: Bank Transfer, UPI, Cash, Cheque.',
                        ],
                        width: width,
                      ),
                      _buildCapabilityItem(
                        icon: Icons.security_rounded,
                        title: 'Role-Based Access & Data Isolation',
                        bullets: const [
                          'Fine-grained roles: Owner, Accountant, Cashier, and Staff.',
                          'Tenant database isolation: user accounts strictly cannot view cross-business data.',
                          'Complete audit logs recording every commercial creation, update, and deletion.',
                          'Tamper-resistant token handling with platform-native secure storage.',
                        ],
                        width: width,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapabilityItem({
    required IconData icon,
    required String title,
    required List<String> bullets,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(b, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAccountingSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ACCOUNTING ENGINE & TAX COMPLIANCE', style: AppTextStyles.label),
              const SizedBox(height: 8),
              const Text(
                'Double-entry ledgers with statutory GST preparation summaries',
                style: AppTextStyles.headingLarge,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chart of Accounts & Automated Double-Entry',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'AirthAI pre-seeds an authoritative Indian business Chart of Accounts (Cash on Hand, Bank Accounts, Accounts Receivable, Inventory Asset, Accounts Payable, Output CGST/SGST/IGST, Input Tax Credit, Sales Revenue, and Cost of Goods Sold). Every voucher enforces equality between debit and credit totals before committal.',
                      style: TextStyle(fontSize: 14, height: 1.55, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 20),
                    const Text(
                      'Statutory GST Return Summaries (GSTR-1 & GSTR-3B)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Form GSTR-1 preparation aggregates outward supplies across B2B taxable invoices, B2C intra-state transactions, and zero-rated supplies with total tax liability breakdown. Form GSTR-3B monthly return summaries calculate net eligible Input Tax Credit (ITC) against outward liabilities to determine net tax payable.',
                      style: TextStyle(fontSize: 14, height: 1.55, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: Color(0xFFB45309)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Statutory Disclaimer: Summaries generated by AirthAI assist business owners and their certified Chartered Accountants in preparing statutory filings. Returns must be verified and filed on the GSTN Common Portal.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopilotSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('READ-ONLY AI COPILOT', style: AppTextStyles.label),
              const SizedBox(height: 8),
              const Text(
                'Actionable business intelligence grounded in your verified data',
                style: AppTextStyles.headingLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unlike generic chatbots that speculate or produce inaccurate numbers, AirthAI Copilot queries verified database ledgers and enforces read-only boundaries.',
                style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final width = isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;

                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      _buildCopilotQuestionCard(
                        question: 'Which products are low in stock?',
                        answer: 'Industrial Safety Helmet has reached 5 units (below minimum threshold of 10). Reorder recommended.',
                        dataUsed: 'local_products, inventory_stock_levels',
                        width: width,
                      ),
                      _buildCopilotQuestionCard(
                        question: 'Which customers have outstanding payments?',
                        answer: '1 customer has outstanding receivables of ₹17,700.00: Shree Ganesh Hardware (INV-2026-27-0001).',
                        dataUsed: 'sales_invoices, payments_receipts',
                        width: width,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopilotQuestionCard({
    required String question,
    required String answer,
    required String dataUsed,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(answer, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Text('Verified Data Sources: $dataUsed', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const Text('TRANSPARENT PRICING TIERS', style: AppTextStyles.label),
              const SizedBox(height: 8),
              const Text(
                'Simple, predictable plans with no hidden transaction fees',
                textAlign: TextAlign.center,
                style: AppTextStyles.headingLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'All plans include offline-first capability, GST invoicing, and data export sovereignty.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 860;
                  final width = isWide ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth;

                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      _buildPricingCard(
                        context: context,
                        name: 'Starter',
                        tagline: 'Ideal for evaluation and small traders',
                        price: '₹0',
                        period: 'forever free in dev mode',
                        features: const [
                          'Up to 50 invoices / month',
                          '1 user account (Owner)',
                          'Local SQLite offline storage',
                          'Standard A4 tax invoice format',
                          'Customer & supplier directories',
                        ],
                        isFeatured: false,
                        width: width,
                      ),
                      _buildPricingCard(
                        context: context,
                        name: 'Professional',
                        tagline: 'For growing retail & wholesale firms',
                        price: '₹999',
                        period: 'per month',
                        features: const [
                          'Up to 500 invoices / month',
                          '5 user accounts (Owner, Accountant, Cashier)',
                          'Full double-entry ledger & trial balance',
                          'GSTR-1 & GSTR-3B preparation summaries',
                          'Multi-device synchronization',
                          'Read-only AI Business Copilot',
                        ],
                        isFeatured: true,
                        width: width,
                      ),
                      _buildPricingCard(
                        context: context,
                        name: 'Enterprise',
                        tagline: 'For high-volume distributors & factories',
                        price: '₹2,999',
                        period: 'per month',
                        features: const [
                          'Up to 10,000 invoices / month',
                          '50 user accounts with custom roles',
                          'Priority cloud synchronization queue',
                          'Multi-branch inventory allocation',
                          'Full audit log export & compliance history',
                          'Dedicated technical support',
                        ],
                        isFeatured: false,
                        width: width,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required String name,
    required String tagline,
    required String price,
    required String period,
    required List<String> features,
    required bool isFeatured,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isFeatured ? AppColors.primary : AppColors.border,
          width: isFeatured ? 2 : 1,
        ),
        boxShadow: isFeatured
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFeatured)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'MOST POPULAR FOR MSMEs',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(tagline, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(price, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(period, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: isFeatured
                ? ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, RouteNames.register),
                    child: const Text('Get Started with Professional'),
                  )
                : OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, RouteNames.register),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                    child: Text('Choose $name'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: const [
              Text('FREQUENTLY ASKED QUESTIONS', style: AppTextStyles.label),
              SizedBox(height: 8),
              Text(
                'Clear answers to common operational questions',
                textAlign: TextAlign.center,
                style: AppTextStyles.headingLarge,
              ),
              SizedBox(height: 36),
              _FaqAccordion(
                question: 'How does offline billing work if my internet connection drops?',
                answer:
                    'AirthAI stores all products, customers, and pending invoices locally in an encrypted SQLite database on your device. You can continue issuing tax invoices without interruption. When your internet connection is restored, the synchronization engine automatically drains the queue and reconciles invoice numbers with the central server.',
              ),
              _FaqAccordion(
                question: 'Are CGST, SGST, and IGST calculated automatically?',
                answer:
                    'Yes. AirthAI uses your registered business state code and the customer\'s Place of Supply to determine whether supply is intra-state (split into equal CGST and SGST) or inter-state (IGST). HSN codes determine the statutory percentage rate.',
              ),
              _FaqAccordion(
                question: 'Can the AI Copilot accidentally modify or delete my invoices?',
                answer:
                    'No. The AI Copilot is strictly read-only by architectural design. It can only execute read queries against your business records to provide insights (such as low stock alerts or unpaid customer invoices). Any request asking the Copilot to create, edit, or delete records is immediately rejected.',
              ),
              _FaqAccordion(
                question: 'Can multiple staff members use AirthAI simultaneously?',
                answer:
                    'Yes. AirthAI supports multi-user collaboration with Role-Based Access Control (RBAC). You can assign roles such as Owner, Accountant, Cashier, and Staff to ensure appropriate permissions for sensitive financial ledgers.',
              ),
              _FaqAccordion(
                question: 'Can I export my accounting data at any time?',
                answer:
                    'Yes. You maintain full data sovereignty. You can export sales registers, purchase bills, general ledgers, trial balances, and GST preparation summaries to CSV or Excel at any time.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCtaBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              const Text(
                'Ready to streamline your business billing and accounting?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Join Indian MSMEs operating on accurate GST billing, live inventory, and balanced double-entry ledgers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, RouteNames.register),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    child: const Text('Create Free Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, RouteNames.login),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: const Text('Sign in to Workspace', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'AirthAI',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Intelligent, GST-compliant billing, inventory management, and double-entry bookkeeping platform for Indian enterprises.',
                          style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Product Capabilities', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 12),
                        _buildFooterLink('GST Invoicing & Bills', () => _scrollToKey(_featuresKey)),
                        _buildFooterLink('Inventory & Stock Tracking', () => _scrollToKey(_featuresKey)),
                        _buildFooterLink('Double-Entry Accounting', () => _scrollToKey(_accountingKey)),
                        _buildFooterLink('Read-Only AI Copilot', () => _scrollToKey(_featuresKey)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Legal & Compliance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 12),
                        _buildFooterLink('Privacy Policy', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                        }),
                        _buildFooterLink('Terms & Conditions', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()));
                        }),
                        _buildFooterLink('Pricing & Plans', () => _scrollToKey(_pricingKey)),
                        _buildFooterLink('Support: support@airthai.in', () {}),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: const [
                  Text(
                    '© 2026 AirthAI Software Technologies. All rights reserved.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Made for Indian Commerce • Bengaluru, India',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryLine({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 13 : 11,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 14 : 11,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _FaqAccordion extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqAccordion({
    required this.question,
    required this.answer,
  });

  @override
  State<_FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<_FaqAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Text(
                widget.answer,
                style: const TextStyle(fontSize: 13, height: 1.55, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
