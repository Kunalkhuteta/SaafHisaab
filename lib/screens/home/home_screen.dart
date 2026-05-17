import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import '../bills/bill_scan_screen.dart';
import '../profile/profile_screen.dart';
import '../stock/stock_screen.dart';
import '../udhar/udhar_screen.dart';
import '../purchase/purchase_parties_list_screen.dart';
import 'reports_tab.dart';
import 'dashboard_tab.dart';
import '../settings/system_params_screen.dart';

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

    final screens = [
      const DashboardTab(),
      const BillScanScreen(),
      const StockScreen(),
      const UdharScreen(),
      const ReportsTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _HomeDrawer(
        isEn: isEn,
        onProfile: () => _openSettings(context),
        onSettings: () => _openSettings(context),
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: AppLang.tr(isEn, 'Home', 'Home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_rounded),
            label: AppLang.tr(isEn, 'Bills', 'Bills'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2_rounded),
            label: AppLang.tr(isEn, 'Stock', 'Stock'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_rounded),
            label: AppLang.tr(isEn, 'Credit', 'Credit'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.insert_chart_rounded),
            label: AppLang.tr(isEn, 'Reports', 'रिपोर्ट्स'),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }
}

class _HomeDrawer extends StatelessWidget {
  final bool isEn;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  const _HomeDrawer({
    required this.isEn,
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
                  Text(
                    AppLang.tr(isEn, 'SaafHisaab', 'SaafHisaab'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    AppLang.tr(
                      isEn,
                      'Clean Accounts for Your Shop',
                      'Clean Accounts for Your Shop',
                    ),
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
            ListTile(
              leading:
                  const Icon(Icons.person_rounded, color: AppColors.textSecondary),
              title: Text(AppLang.tr(isEn, 'My Profile', 'My Profile')),
              onTap: onProfile,
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_rounded,
                  color: AppColors.textSecondary),
              title: Text(AppLang.tr(isEn, 'Purchase Account', 'खरीद खाता')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PurchasePartiesListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded,
                  color: AppColors.textSecondary),
              title: Text(AppLang.tr(isEn, 'Settings', 'Settings')),
              onTap: onSettings,
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded,
                  color: AppColors.textSecondary),
              title: Text(AppLang.tr(isEn, 'System Params', 'सिस्टम पैरामीटर')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SystemParamsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded,
                  color: AppColors.textSecondary),
              title: Text(AppLang.tr(isEn, 'Help & Support', 'Help & Support')),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: Text(
                AppLang.tr(isEn, 'Sign Out', 'Sign Out'),
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (r) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
