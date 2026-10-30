import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Privacy Policy Screen for AirthAI.
///
/// Phase 3 & 4: Legal & Trust Architecture
/// Formulated specifically for Indian MSME data privacy, GST transaction handling,
/// tenant isolation, and encrypted local storage practices.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AirthAI Privacy Policy',
                              style: AppTextStyles.headingMedium,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Effective Date: October 2026 • Version 1.2',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 20),

                  _buildSection(
                    title: '1. Introduction & Overview',
                    content:
                        'AirthAI ("the Application", "we", "us", or "our") is an intelligent, offline-first GST billing, inventory tracking, and double-entry bookkeeping platform designed for commercial enterprises and MSMEs in India. We take data privacy seriously and adhere to principled data governance standards.\n\n'
                        'This Privacy Policy describes what commercial and technical information we collect, how it is processed to deliver invoicing and accounting services, how multi-tenant isolation is enforced, and how your data is protected on local devices and cloud synchronization infrastructure.',
                  ),

                  _buildSection(
                    title: '2. Information We Collect',
                    content:
                        'To operate commercial accounting workflows, AirthAI collects and processes the following categories of information:\n\n'
                        '• Business Identity & Profile: Business legal name, trade name, GSTIN (Goods and Services Tax Identification Number), PAN, registered address, state code, and contact information.\n'
                        '• Account Credentials: User full name, business email address, phone number, role classification (e.g. Owner, Accountant, Cashier), and cryptographically salted password hashes.\n'
                        '• Commercial Transactional Records: Tax invoices, quotation bills, purchase orders, customer receipts, vendor payments, expense vouchers, itemized lines, HSN/SAC codes, applicable GST rates (CGST, SGST, IGST), and reverse charge flags.\n'
                        '• Counterparty Records: Customer and supplier names, phone numbers, email addresses, billing/shipping addresses, and place of supply state identifiers.\n'
                        '• Technical & Storage Telemetry: Cryptographic session tokens stored in platform-native secure storage, offline mutation queues stored in encrypted local SQLite databases, synchronization timestamps, and network connectivity status.',
                  ),

                  _buildSection(
                    title: '3. How We Use Your Data',
                    content:
                        'Your business information is strictly processed to execute requested software capabilities:\n\n'
                        '• Generating authoritative, GST-compliant tax invoices, credit notes, and purchase orders.\n'
                        '• Maintaining a balanced double-entry General Ledger, Chart of Accounts, and real-time Trial Balance.\n'
                        '• Reconciling input tax credits (ITC) and generating preparation summaries for statutory GSTR-1 and GSTR-3B monthly/quarterly filings.\n'
                        '• Draining offline sync queues and assigning authoritative sequential invoice numbers upon cloud reconnection.\n'
                        '• Providing read-only AI Business Copilot analysis on customer outstanding balances and inventory reorder points.',
                  ),

                  _buildSection(
                    title: '4. AI Business Copilot & Model Privacy',
                    content:
                        'AirthAI includes a source-grounded, read-only AI Business Copilot. We maintain strict safeguards regarding artificial intelligence interactions:\n\n'
                        '• Tenant Boundary: Copilot inquiries only analyze commercial records belonging strictly to your authenticated business tenant.\n'
                        '• Read-Only Architecture: The AI Copilot is architecturally barred from executing write operations, creating vouchers, deleting items, or modifying ledger balances.\n'
                        '• No Public Model Training: Your commercial financial records, invoice items, and counterparty data are NEVER used to train, tune, or improve public third-party foundation models.\n'
                        '• Deterministic Verification: AI-generated financial insights cite verifiable calculation definitions and caveats.',
                  ),

                  _buildSection(
                    title: '5. Database Isolation & Security Architecture',
                    content:
                        'We employ defense-in-depth architectural safeguards to protect business records:\n\n'
                        '• Tenant Isolation: Every query and transaction in our relational database is strictly scoped by tenant identifier (businessId). Cross-tenant access is structurally prohibited.\n'
                        '• Local Encrypted Storage: Mobile and desktop offline caches utilize secure storage for access tokens and localized encrypted SQLite databases for transactional continuity.\n'
                        '• Transport Security: All communications with cloud synchronization endpoints utilize TLS 1.3 encryption in transit.\n'
                        '• Role-Based Permissions: Access to sensitive accounting views and reports is governed by strict user role authorization (Owner, Accountant, Cashier).',
                  ),

                  _buildSection(
                    title: '6. Zero Third-Party Data Monetization',
                    content:
                        'We do not sell, rent, lease, trade, or monetize your business records, invoice lines, customer lists, or financial data to third-party data brokers, marketing agencies, or advertisers.',
                  ),

                  _buildSection(
                    title: '7. Data Retention & User Control',
                    content:
                        'Business owners retain full sovereignty over their accounting and inventory records:\n\n'
                        '• Exportability: You may export your sales register, purchase register, trial balance, and GST summaries to CSV or Excel at any time.\n'
                        '• Local Data Purge: Signing out of the application purges local device authentication tokens and unlinks tenant session caches.\n'
                        '• Account Closure: Upon verified request by the registered business owner, tenant cloud records are scheduled for secure deletion subject to legal and statutory recordkeeping mandates.',
                  ),

                  _buildSection(
                    title: '8. Contact Information',
                    content:
                        'For questions regarding this Privacy Policy or your business data rights, contact our Data Governance Team at:\n\n'
                        'Email: privacy@airthai.in\n'
                        'AirthAI Software Technologies • Bengaluru, Karnataka, India',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

