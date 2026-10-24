import 'package:flutter/material.dart';

import '../../core/security/session_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/presentation/screens/business_setup_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';

class AppShell extends StatefulWidget {
  final bool showBusinessOnboarding;

  const AppShell({super.key, this.showBusinessOnboarding = false});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showBusinessOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBusinessOnboardingDialog();
      });
    }
  }

  void _showBusinessOnboardingDialog() {
    if (!mounted) return;
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Setup Your Business Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Add your GSTIN, registered business address, and billing format to begin issuing GST-compliant tax invoices.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BusinessSetupScreen(),
                    ),
                  );
                },
                child: const Text('Complete Business Setup Now'),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Explore dashboard first',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final List<_NavigationItem> navigationItems = const [
    _NavigationItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    _NavigationItem(
      label: 'Sales',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    _NavigationItem(
      label: 'Purchases',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart_rounded,
    ),
    _NavigationItem(
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
    ),
    _NavigationItem(
      label: 'Customers',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
    ),
    _NavigationItem(
      label: 'Suppliers',
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping_rounded,
    ),
    _NavigationItem(
      label: 'Expenses',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
    ),
    _NavigationItem(
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
    ),
  ];

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Sign out',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out of your AirthAI account?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await SessionManager.instance.logout();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: AppDimensions.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _buildBrand(),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12, bottom: 10),
                  child: Text('MAIN MENU', style: AppTextStyles.label),
                ),

                ...List.generate(
                  navigationItems.length,
                  (index) =>
                      _buildNavigationItem(index, navigationItems[index]),
                ),
              ],
            ),
          ),

          _buildUserSection(),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'AirthAI',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(int index, _NavigationItem item) {
    final selected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          onTap: () {
            setState(() {
              selectedIndex = index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),

                if (selected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final user = SessionManager.instance.currentUser;
    final initial = (user != null && user.fullName.isNotEmpty)
        ? user.fullName[0].toUpperCase()
        : 'A';

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              navigationItems[selectedIndex].label,
              style: AppTextStyles.headingMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 21,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(width: 12),

          PopupMenuButton<String>(
            tooltip: 'Account menu',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Sign out',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: Text(
        '${navigationItems[selectedIndex].label} Screen',
        style: AppTextStyles.headingLarge,
      ),
    );
  }

  Widget _buildUserSection() {
    final user = SessionManager.instance.currentUser;
    final userName = user?.fullName ?? 'Admin User';
    final userRole = user?.role ?? 'Administrator';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userRole,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }
}

class _NavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
