import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/accounting_service.dart';
import '../../models/account_model.dart';
import '../../models/journal_model.dart';
import '../../models/financial_report_models.dart';
import '../../models/gst_report_models.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data states
  bool _isLoading = false;
  String? _errorMessage;

  List<AccountModel> _accounts = [];
  List<JournalEntryModel> _journals = [];
  TrialBalanceModel? _trialBalance;
  ProfitLossModel? _profitLoss;
  Gstr1Model? _gstr1;
  Gstr3bModel? _gstr3b;

  String _selectedGstPeriod = '2026-10';
  final List<String> _gstPeriods = ['2026-10', '2026-09', '2026-08', '2026-07'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadCurrentTabData();
      }
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _fetchAccounts(),
        _fetchJournals(),
        _fetchTrialBalance(),
        _fetchProfitLoss(),
        _fetchGstReports(),
      ]);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadCurrentTabData() {
    switch (_tabController.index) {
      case 0:
        _fetchAccounts();
        break;
      case 1:
        _fetchJournals();
        break;
      case 2:
        _fetchTrialBalance();
        break;
      case 3:
        _fetchProfitLoss();
        break;
      case 4:
        _fetchGstReports();
        break;
    }
  }

  Future<void> _fetchAccounts() async {
    final res = await AccountingService.instance.getAccounts();
    if (mounted) {
      setState(() {
        if (res.isSuccess) {
          _accounts = res.data ?? [];
        } else {
          _errorMessage = res.error;
        }
      });
    }
  }

  Future<void> _fetchJournals() async {
    final res = await AccountingService.instance.getJournalEntries();
    if (mounted) {
      setState(() {
        if (res.isSuccess) {
          _journals = res.data ?? [];
        } else {
          _errorMessage = res.error;
        }
      });
    }
  }

  Future<void> _fetchTrialBalance() async {
    final res = await AccountingService.instance.getTrialBalance();
    if (mounted) {
      setState(() {
        if (res.isSuccess) {
          _trialBalance = res.data;
        } else {
          _errorMessage = res.error;
        }
      });
    }
  }

  Future<void> _fetchProfitLoss() async {
    final res = await AccountingService.instance.getProfitLoss();
    if (mounted) {
      setState(() {
        if (res.isSuccess) {
          _profitLoss = res.data;
        } else {
          _errorMessage = res.error;
        }
      });
    }
  }

  Future<void> _fetchGstReports() async {
    final res1 = await AccountingService.instance.getGstr1(returnPeriod: _selectedGstPeriod);
    final res3b = await AccountingService.instance.getGstr3b(returnPeriod: _selectedGstPeriod);
    if (mounted) {
      setState(() {
        if (res1.isSuccess) _gstr1 = res1.data;
        if (res3b.isSuccess) _gstr3b = res3b.data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeaderBar(),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAccountsTab(),
                      _buildJournalsTab(),
                      _buildTrialBalanceTab(),
                      _buildProfitLossTab(),
                      _buildGstTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Accounting & GST Engine',
                  style: AppTextStyles.headingMedium,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Record Journal Entry'),
                onPressed: _showCreateJournalDialog,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                ),
                icon: const Icon(Icons.account_balance, size: 18),
                label: const Text('+ Account'),
                onPressed: _showCreateAccountDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Chart of Accounts'),
              Tab(text: 'Journal Entries'),
              Tab(text: 'Trial Balance'),
              Tab(text: 'Profit & Loss'),
              Tab(text: 'GST Returns (GSTR-1 & 3B)'),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: CHART OF ACCOUNTS
  // =========================================================================
  Widget _buildAccountsTab() {
    if (_accounts.isEmpty) {
      return const Center(child: Text('No accounts found in the Chart of Accounts.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _accounts.length,
      itemBuilder: (context, index) {
        final acc = _accounts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: acc.type.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      acc.code,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: acc.type.color,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        acc.type.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: acc.type.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${acc.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      acc.type.isDebitNormal ? 'Dr normal' : 'Cr normal',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 2: JOURNAL ENTRIES
  // =========================================================================
  Widget _buildJournalsTab() {
    if (_journals.isEmpty) {
      return const Center(child: Text('No journal entries recorded.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _journals.length,
      itemBuilder: (context, index) {
        final jrn = _journals[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          jrn.entryNumber,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (jrn.referenceType != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              jrn.referenceType!,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${jrn.date.day.toString().padLeft(2, '0')}/${jrn.date.month.toString().padLeft(2, '0')}/${jrn.date.year}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  jrn.narration,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
                const Divider(height: 20),
                // Ledger lines
                ...jrn.entries.map((line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line.accountCode} - ${line.accountName}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              line.debit > 0 ? '₹${line.debit.toStringAsFixed(2)}' : '-',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: line.debit > 0 ? FontWeight.w600 : FontWeight.normal,
                                color: line.debit > 0 ? Colors.blue.shade800 : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 100,
                            child: Text(
                              line.credit > 0 ? '₹${line.credit.toStringAsFixed(2)}' : '-',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: line.credit > 0 ? FontWeight.w600 : FontWeight.normal,
                                color: line.credit > 0 ? Colors.green.shade800 : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 3: TRIAL BALANCE
  // =========================================================================
  Widget _buildTrialBalanceTab() {
    final tb = _trialBalance;
    if (tb == null) {
      return const Center(child: Text('Trial Balance not available.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balanced Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tb.isBalanced ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tb.isBalanced ? Colors.green.shade300 : Colors.red.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  tb.isBalanced ? Icons.check_circle : Icons.error,
                  color: tb.isBalanced ? Colors.green.shade700 : Colors.red.shade700,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tb.isBalanced
                            ? 'Double-Entry Ledger is Balanced'
                            : 'Ledger Out of Balance!',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: tb.isBalanced ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                      Text(
                        tb.isBalanced
                            ? 'Total Debits (₹${tb.totalDebits.toStringAsFixed(2)}) equal Total Credits (₹${tb.totalCredits.toStringAsFixed(2)}).'
                            : 'Difference of ₹${tb.difference.toStringAsFixed(2)} between total debits and credits.',
                        style: TextStyle(
                          fontSize: 13,
                          color: tb.isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Trial Balance Table
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: const [
                      SizedBox(width: 70, child: Text('Code', style: TextStyle(fontWeight: FontWeight.w700))),
                      Expanded(child: Text('Account Name', style: TextStyle(fontWeight: FontWeight.w700))),
                      SizedBox(width: 120, child: Text('Debit (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
                      SizedBox(width: 16),
                      SizedBox(width: 120, child: Text('Credit (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const Divider(height: 20),
                  ...tb.items.map((line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 70, child: Text(line.code, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(child: Text(line.name)),
                            SizedBox(
                              width: 120,
                              child: Text(
                                line.debit > 0 ? line.debit.toStringAsFixed(2) : '-',
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 120,
                              child: Text(
                                line.credit > 0 ? line.credit.toStringAsFixed(2) : '-',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 24, thickness: 1.5),
                  Row(
                    children: [
                      const SizedBox(width: 70),
                      const Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          '₹${tb.totalDebits.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: Text(
                          '₹${tb.totalCredits.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 4: PROFIT & LOSS
  // =========================================================================
  Widget _buildProfitLossTab() {
    final pl = _profitLoss;
    if (pl == null) {
      return const Center(child: Text('Profit & Loss statement not available.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Summary Cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildKpiCard('Total Revenue', '₹${pl.totalRevenue.toStringAsFixed(2)}', Colors.blue),
              _buildKpiCard('Cost of Goods Sold', '₹${pl.costOfGoodsSold.toStringAsFixed(2)}', Colors.orange),
              _buildKpiCard('Gross Profit', '₹${pl.grossProfit.toStringAsFixed(2)}', Colors.teal),
              _buildKpiCard('Operating Expenses', '₹${pl.totalOperatingExpenses.toStringAsFixed(2)}', Colors.purple),
              _buildKpiCard(
                'Net Profit / (Loss)',
                '₹${pl.netProfit.toStringAsFixed(2)}',
                pl.netProfit >= 0 ? Colors.green : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Revenue Breakdown
          _buildBreakdownCard('Operating Revenue', pl.revenueBreakdown, pl.totalRevenue, Colors.blue),
          const SizedBox(height: 16),
          // Operating Expenses Breakdown
          _buildBreakdownCard('Operating Expenses', pl.expenseBreakdown, pl.totalOperatingExpenses, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(String title, List<ReportLineItem> lines, double total, Color color) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Total: ₹${total.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color)),
              ],
            ),
            const Divider(height: 20),
            if (lines.isEmpty)
              const Text('No records under this category.')
            else
              ...lines.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${l.code} - ${l.name}', style: const TextStyle(fontSize: 13)),
                        Text('₹${l.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 5: GST STATUTORY PREPARATION REPORTS
  // =========================================================================
  Widget _buildGstTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector & Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GST Preparation Summaries',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              DropdownButton<String>(
                value: _selectedGstPeriod,
                items: _gstPeriods
                    .map((p) => DropdownMenuItem(value: p, child: Text('Return Period: $p')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedGstPeriod = val;
                    });
                    _fetchGstReports();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Prominent Statutory Notice Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.amber.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _gstr1?.disclaimer ??
                        'Preparation summary generated from AirthAI financial ledgers. '
                        'AirthAI does not provide automated filing or direct transmission to the GST Common Portal (GSTN). '
                        'Returns must be reviewed and filed by a qualified tax professional.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Form GSTR-1 Summary Card
          if (_gstr1 != null) _buildGstr1Card(_gstr1!),
          const SizedBox(height: 20),
          // Form GSTR-3B Summary Card
          if (_gstr3b != null) _buildGstr3bCard(_gstr3b!),
        ],
      ),
    );
  }

  Widget _buildGstr1Card(Gstr1Model g1) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Form GSTR-1: Outward Supplies Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                Text('Liability: ₹${g1.totalTaxLiability.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo)),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildGstMetricTile('Total Taxable Value', '₹${g1.totalTaxableValue.toStringAsFixed(2)}'),
                _buildGstMetricTile('CGST Liability', '₹${g1.totalCgst.toStringAsFixed(2)}'),
                _buildGstMetricTile('SGST Liability', '₹${g1.totalSgst.toStringAsFixed(2)}'),
                _buildGstMetricTile('B2B Invoices (Table 4)', '${g1.table4B2bCount} (₹${g1.table4B2bTaxable.toStringAsFixed(2)})'),
                _buildGstMetricTile('B2C Small (Table 7)', '${g1.table7B2cCount} (₹${g1.table7B2cTaxable.toStringAsFixed(2)})'),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Table 12: HSN Summary of Outward Supplies',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...g1.hsnSummary.map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(width: 70, child: Text(h.hsnCode, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Expanded(child: Text(h.description, overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 80, child: Text('Qty: ${h.quantity}', textAlign: TextAlign.right)),
                      SizedBox(width: 100, child: Text('₹${h.totalTax.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildGstr3bCard(Gstr3bModel g3) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Form GSTR-3B: Monthly Return Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.deepPurple)),
                Text('Net Payable: ₹${g3.totalNetPayable.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.red)),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildGstMetricTile('Outward Tax (Table 3.1)', '₹${g3.totalOutwardTax.toStringAsFixed(2)}'),
                _buildGstMetricTile('Eligible ITC (Table 4)', '₹${g3.totalItcAvailable.toStringAsFixed(2)}'),
                _buildGstMetricTile('Net CGST Payable', '₹${g3.netPayableCgst.toStringAsFixed(2)}'),
                _buildGstMetricTile('Net SGST Payable', '₹${g3.netPayableSgst.toStringAsFixed(2)}'),
                _buildGstMetricTile('Net IGST Payable', '₹${g3.netPayableIgst.toStringAsFixed(2)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGstMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // =========================================================================
  // DIALOGS: CREATE ACCOUNT & CREATE JOURNAL ENTRY
  // =========================================================================

  void _showCreateAccountDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    AccountType selectedType = AccountType.asset;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Add Account to Chart of Accounts'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Account Code (e.g. 1020, 5400)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<AccountType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Account Classification'),
                items: AccountType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDlgState(() => selectedType = val);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Opening Balance (optional, ₹)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
                final op = double.tryParse(balanceCtrl.text);
                final res = await AccountingService.instance.createAccount(
                  code: codeCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  type: selectedType,
                  openingBalance: op,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (res.isSuccess) {
                  _loadAllData();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res.error ?? 'Failed to create account')),
                  );
                }
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateJournalDialog() {
    final narrationCtrl = TextEditingController();
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chart of Accounts is loading...')),
      );
      return;
    }

    final List<Map<String, dynamic>> draftLines = [
      {'accountId': _accounts.first.id, 'debit': 0.0, 'credit': 0.0},
      {'accountId': _accounts.length > 1 ? _accounts[1].id : _accounts.first.id, 'debit': 0.0, 'credit': 0.0},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          double totalDebit = 0.0;
          double totalCredit = 0.0;
          for (final line in draftLines) {
            totalDebit += (line['debit'] as num?)?.toDouble() ?? 0.0;
            totalCredit += (line['credit'] as num?)?.toDouble() ?? 0.0;
          }
          final difference = (totalDebit - totalCredit).abs();
          final isBalanced = difference < 0.01 && totalDebit > 0;

          return AlertDialog(
            title: const Text('Record Journal Entry (Double-Entry)'),
            content: SizedBox(
              width: 550,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: narrationCtrl,
                      decoration: const InputDecoration(labelText: 'Narration / Description *'),
                    ),
                    const SizedBox(height: 16),
                    // Balancing Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isBalanced ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isBalanced ? Colors.green.shade300 : Colors.red.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isBalanced
                                ? 'Balanced (₹${totalDebit.toStringAsFixed(2)})'
                                : 'Unbalanced (Diff: ₹${difference.toStringAsFixed(2)})',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                          Text('Dr: ₹${totalDebit.toStringAsFixed(2)} | Cr: ₹${totalCredit.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Lines
                    ...List.generate(draftLines.length, (idx) {
                      final item = draftLines[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: item['accountId'],
                                isExpanded: true,
                                items: _accounts
                                    .map((a) => DropdownMenuItem(
                                          value: a.id,
                                          child: Text('${a.code} - ${a.name}',
                                              overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDlgState(() => item['accountId'] = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Debit (₹)'),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val) ?? 0.0;
                                  setDlgState(() {
                                    item['debit'] = numVal;
                                    if (numVal > 0) item['credit'] = 0.0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Credit (₹)'),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val) ?? 0.0;
                                  setDlgState(() {
                                    item['credit'] = numVal;
                                    if (numVal > 0) item['debit'] = 0.0;
                                  });
                                },
                              ),
                            ),
                            if (draftLines.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  setDlgState(() => draftLines.removeAt(idx));
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Line'),
                      onPressed: () {
                        setDlgState(() {
                          draftLines.add({
                            'accountId': _accounts.first.id,
                            'debit': 0.0,
                            'credit': 0.0,
                          });
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isBalanced
                    ? () async {
                        final res = await AccountingService.instance.createJournalEntry(
                          narration: narrationCtrl.text.trim().isEmpty
                              ? 'General Journal'
                              : narrationCtrl.text.trim(),
                          entries: draftLines,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (res.isSuccess) {
                          _loadAllData();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(res.error ?? 'Failed to post entry')),
                          );
                        }
                      }
                    : null,
                child: const Text('Post Entry'),
              ),
            ],
          );
        },
      ),
    );
  }
}
