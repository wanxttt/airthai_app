import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Terms & Conditions Screen for AirthAI.
///
/// Phase 3 & 4: Statutory Compliance & User Agreement Architecture
/// Features transparent service definitions, subscription quotas, offline reconciliation terms,
/// and the statutory Chartered Accountant disclaimer.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Terms & Conditions',
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
                          Icons.gavel_rounded,
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
                              'AirthAI Terms of Service',
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

                  // Important Statutory Notice Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'IMPORTANT STATUTORY DISCLAIMER',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'AirthAI provides digital bookkeeping, double-entry ledger calculation, and statutory return preparation summaries. AirthAI is NOT a chartered accounting firm, legal advisor, or tax consultancy. Use of AirthAI does not substitute for professional accounting advice or official verification with the Goods and Services Tax Network (GSTN).',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF78350F),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 20),

                  _buildSection(
                    title: '1. Agreement to Terms',
                    content:
                        'By creating an account, registering a business tenant, accessing, or using the AirthAI software platform (available via web, desktop, and mobile applications), you agree to be bound by these Terms and Conditions. If you are registering on behalf of a business entity, you represent and warrant that you possess the requisite authority to bind that entity.',
                  ),

                  _buildSection(
                    title: '2. Description of Service',
                    content:
                        'AirthAI is a commercial SaaS solution providing:\n\n'
                        '• GST-compliant sales invoicing, quotations, and delivery challans.\n'
                        '• Vendor purchase recording and invoice settlement allocation.\n'
                        '• Multi-tier inventory valuation (FIFO, weighted average) with overselling protection.\n'
                        '• Automated double-entry journal vouchers and balanced trial balance reports.\n'
                        '• GSTR-1 and GSTR-3B preparation summaries.\n'
                        '• Offline-first SQLite local durability with background cloud synchronization.\n'
                        '• Read-only AI Business Copilot for diagnostic querying.',
                  ),

                  _buildSection(
                    title: '3. Tax Accuracy & Statutory Responsibility',
                    content:
                        'While AirthAI calculates CGST, SGST, IGST, and cess amounts according to statutory formulas and place-of-supply rules, the user and business owner remain solely responsible for:\n\n'
                        '• Verifying correct HSN/SAC codes and tax rates applied to commercial line items.\n'
                        '• Confirming intra-state versus inter-state supply classifications.\n'
                        '• Validating counterparty GSTIN credentials prior to issuing tax invoices.\n'
                        '• Ensuring all statutory returns (GSTR-1, GSTR-3B, GSTR-9) are accurately filed and reconciled on the government GST Common Portal (gst.gov.in).\n'
                        '• Retaining certified fiscal audit records as required by Indian tax legislation.',
                  ),

                  _buildSection(
                    title: '4. User Accounts, Access Control & Tenant Security',
                    content:
                        '• Account Credentials: You are responsible for safeguarding your login credentials, passwords, and API tokens. You must immediately notify AirthAI of any suspected unauthorized access.\n'
                        '• Role-Based Access: Business owners are responsible for properly delegating role permissions (Owner, Accountant, Cashier) to internal staff.\n'
                        '• Prohibited Activities: You agree not to attempt security circumvention, multi-tenant boundary penetration, automated API abuse, or unauthorized reverse engineering of the platform.',
                  ),

                  _buildSection(
                    title: '5. Subscription Plans, Quotas & Fair Usage',
                    content:
                        'AirthAI services are structured under transparent subscription tiers:\n\n'
                        '• Starter (Free Development Tier): Designed for evaluation and small traders; includes up to 50 invoices per month and 1 registered user account.\n'
                        '• Professional Tier (₹999/month): Designed for growing commercial businesses; includes up to 500 invoices per month, 5 users, and full double-entry accounting ledgers.\n'
                        '• Enterprise Tier (₹2,999/month): Designed for high-volume distributors; includes up to 10,000 invoices per month, 50 users, priority synchronization, and custom audit trails.\n\n'
                        'Accounts exceeding monthly invoice quotas are guided to upgrade their subscription tier to maintain uninterrupted billing operations.',
                  ),

                  _buildSection(
                    title: '6. Offline Synchronization & Data Consistency',
                    content:
                        'AirthAI operates on an offline-first architecture. When working offline:\n\n'
                        '• Invoices generated offline are assigned non-authoritative temporary identifiers (e.g., OFFLINE-INV-*).\n'
                        '• Upon network restoration, pending operations drain sequentially and receive authoritative sequential invoice numbers from the backend database sequence engine.\n'
                        '• In the event of concurrency conflicts across multiple offline devices, AirthAI preserves both records and alerts the business owner for deterministic reconciliation.',
                  ),

                  _buildSection(
                    title: '7. Intellectual Property & Data Ownership',
                    content:
                        '• Your Data: You retain 100% ownership of your business data, customer profiles, catalog pricing, and financial ledgers.\n'
                        '• Software IP: The AirthAI platform, design architecture, database schema, user interfaces, and source code are the exclusive intellectual property of AirthAI Software Technologies.',
                  ),

                  _buildSection(
                    title: '8. Limitation of Liability',
                    content:
                        'To the maximum extent permitted by applicable law, AirthAI and its affiliates shall not be liable for any indirect, incidental, punitive, or consequential damages resulting from tax penalties, loss of commercial profits, business interruption, or hardware device failure. Our total cumulative liability arising out of or related to these Terms shall not exceed the amount paid by you to AirthAI during the six (6) months preceding the incident.',
                  ),

                  _buildSection(
                    title: '9. Governing Law & Jurisdiction',
                    content:
                        'These Terms and Conditions shall be governed by and construed in accordance with the laws of the Republic of India. The courts of Bengaluru, Karnataka, India shall have exclusive jurisdiction over any disputes arising under or in connection with these Terms.',
                  ),

                  _buildSection(
                    title: '10. Contact Information',
                    content:
                        'For legal inquiries, terms clarifications, or compliance documentation, contact:\n\n'
                        'Email: legal@airthai.in\n'
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

