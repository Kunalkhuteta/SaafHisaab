import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/shop_access_model.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import '../bills/bill_scan_screen.dart';
import '../master/master_screen.dart';
import '../master/role_master_screen.dart';
import '../master/user_master_screen.dart';
import '../profile/profile_screen.dart';
import '../purchase/purchase_parties_list_screen.dart';
import '../settings/system_params_screen.dart';
import '../stock/stock_screen.dart';
import '../udhar/udhar_screen.dart';
import 'dashboard_tab.dart';
import 'reports_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final userId = AuthService.currentUserId;
    if (userId != null) {
      NotificationService.saveTokenToSupabase(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final accessAsync = ref.watch(shopAccessProvider);
    final access = accessAsync.valueOrNull;

    if (accessAsync.isLoading && access == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (accessAsync.hasError) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load your shop access. ${accessAsync.error}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (access == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('No shop access found. Please sign in again.')),
      );
    }

    final role = access.role;
    final tabs = _tabsFor(role, isEn);

    if (_currentIndex >= tabs.length) _currentIndex = 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _HomeDrawer(
        isEn: isEn,
        role: role,
        onProfile: () => _openSettings(context),
        onSettings: () => _openSettings(context),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs.map((tab) => tab.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: tabs
            .map((tab) => BottomNavigationBarItem(
                  icon: Icon(tab.icon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }

  List<_HomeTab> _tabsFor(ShopRole role, bool isEn) {
    return [
      _HomeTab(
        screen: const DashboardTab(),
        icon: Icons.home_rounded,
        label: AppLang.tr(isEn, 'Home', 'Home'),
      ),
      _HomeTab(
        screen: const BillScanScreen(),
        icon: Icons.receipt_long_rounded,
        label: AppLang.tr(isEn, 'Bills', 'Bills'),
      ),
      if (role.canViewMaster)
        _HomeTab(
          screen: const MasterScreen(),
          icon: Icons.dashboard_rounded,
          label: AppLang.tr(isEn, 'Master', 'Master'),
        ),
      if (role.canViewUdhar)
        _HomeTab(
          screen: const UdharScreen(),
          icon: Icons.people_rounded,
          label: AppLang.tr(isEn, 'Credit', 'Credit'),
        ),
      if (role.canViewReports)
        _HomeTab(
          screen: const ReportsTab(),
          icon: Icons.insert_chart_rounded,
          label: AppLang.tr(isEn, 'Reports', 'Reports'),
        ),
    ];
  }

  void _openSettings(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }
}

class _HomeTab {
  final Widget screen;
  final IconData icon;
  final String label;

  const _HomeTab({
    required this.screen,
    required this.icon,
    required this.label,
  });
}

class _HomeDrawer extends StatelessWidget {
  final bool isEn;
  final ShopRole role;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  const _HomeDrawer({
    required this.isEn,
    required this.role,
    required this.onProfile,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: AppColors.background,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'SaafHisaab',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    role.label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final isEnglish = ref.watch(appLanguageProvider);
                return ListTile(
                  leading: const Icon(Icons.language_rounded,
                      color: AppColors.primary),
                  title: const Text(
                    'Language',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(isEnglish ? 'English' : 'Hindi'),
                  trailing: Switch(
                    value: isEnglish,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      ref.read(appLanguageProvider.notifier).setLanguage(val);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
            const Divider(),
            if (!role.isStaff)
              ListTile(
                leading: const Icon(Icons.person_rounded,
                    color: AppColors.textSecondary),
                title: const Text('My Profile'),
                onTap: onProfile,
              ),
            if (role.canViewPurchases)
              ListTile(
                leading: const Icon(Icons.shopping_cart_rounded,
                    color: AppColors.textSecondary),
                title: const Text('Purchase Account'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PurchasePartiesListScreen()),
                  );
                },
              ),
            if (role.canViewStock)
              ListTile(
                leading: const Icon(Icons.inventory_2_rounded,
                    color: AppColors.textSecondary),
                title: const Text('Stock'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Stock'),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        body: const StockScreen(),
                      ),
                    ),
                  );
                },
              ),
            if (role.canManageUsers)
              ListTile(
                leading: const Icon(Icons.group_add_rounded,
                    color: AppColors.textSecondary),
                title: const Text('User Master'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserMasterScreen()),
                  );
                },
              ),
            if (role.canManageUsers)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_rounded,
                    color: AppColors.textSecondary),
                title: const Text('Role Master'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoleMasterScreen()),
                  );
                },
              ),
            if (role.canOpenSettings)
              ListTile(
                leading: const Icon(Icons.settings_rounded,
                    color: AppColors.textSecondary),
                title: const Text('Settings'),
                onTap: onSettings,
              ),
            if (role.canOpenSettings)
              ListTile(
                leading: const Icon(Icons.tune_rounded,
                    color: AppColors.textSecondary),
                title: const Text('System Params'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SystemParamsScreen()),
                  );
                },
              ),
            if (!role.isStaff)
              ListTile(
                leading: const Icon(Icons.help_outline_rounded,
                    color: AppColors.textSecondary),
                title: const Text('Help & Support'),
                onTap: () => Navigator.pop(context),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                final navigator = Navigator.of(context);
                final container = ProviderScope.containerOf(context);
                await AuthService.signOut();
                container.invalidate(shopAccessProvider);
                container.invalidate(shopProvider);
                container.invalidate(currentRoleProvider);
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
