import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import '../bills/bill_scan_screen.dart';
import '../stock/stock_screen.dart';
import '../udhar/udhar_screen.dart';
import '../profile/profile_screen.dart';
import '../../globalVar.dart';

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
    final shopAsync = ref.watch(shopProvider);

    final screens = [
      _DashboardTab(ref: ref),
      const BillScanScreen(),
      const StockScreen(),
      const UdharScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      // Add Drawer
      drawer: Drawer(
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
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      AppLang.tr(isEn, 'SaafHisaab', 'साफ़हिसाब'),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppLang.tr(isEn, 'Clean Accounts for Your Shop', 'आपकी दुकान का साफ़ हिसाब'),
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language_rounded, color: AppColors.primary),
                title: Text(AppLang.tr(isEn, 'Language (भाषा)', 'भाषा (Language)'), style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Switch(
                  value: isEn,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    ref.read(appLanguageProvider.notifier).setLanguage(val);
                    // Close drawer
                    Navigator.pop(context);
                  },
                ),
                subtitle: Text(isEn ? 'English' : 'हिन्दी (Hindi)'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: AppColors.textSecondary),
                title: Text(AppLang.tr(isEn, 'My Profile', 'मेरी प्रोफाइल')),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary),
                title: Text(AppLang.tr(isEn, 'Help & Support', 'मदद और सहायता')),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: Text(AppLang.tr(isEn, 'Sign Out', 'लॉग आउट करें'), style: const TextStyle(color: AppColors.error)),
                onTap: () async {
                  await AuthService.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_rounded), label: AppLang.tr(isEn, 'Home', 'होम')),
          BottomNavigationBarItem(icon: const Icon(Icons.receipt_long_rounded), label: AppLang.tr(isEn, 'Bills', 'बिल')),
          BottomNavigationBarItem(icon: const Icon(Icons.inventory_2_rounded), label: AppLang.tr(isEn, 'Stock', 'स्टॉक')),
          BottomNavigationBarItem(icon: const Icon(Icons.people_rounded), label: AppLang.tr(isEn, 'Credit', 'उधार')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings_rounded), label: AppLang.tr(isEn, 'Settings', 'सेटिंग्स')),
        ],
      ),
    );
  }
}

// ─── Dashboard Tab ──────────
class _DashboardTab extends StatelessWidget {
  final WidgetRef ref;
  const _DashboardTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final shopAsync = ref.watch(shopProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final billsAsync = ref.watch(todayBillsProvider);

    return shopAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (shop) => Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20, right: 20, bottom: 20,
            ),
            child: Row(
              children: [
                // Hamburger icon to open drawer
                GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLang.tr(isEn, 'Hello, ${shop?.ownerName ?? 'User'} 👋', 'नमस्ते, ${shop?.ownerName ?? 'जी'} 👋'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shop?.shopName ?? AppLang.tr(isEn, 'Your Shop', 'आपकी दुकान'),
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75)),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(dashboardStatsProvider);
                ref.invalidate(todayBillsProvider);
                ref.invalidate(shopProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    statsAsync.when(
                      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
                      error: (e, _) => const SizedBox(),
                      data: (stats) => Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _statCard('₹${(stats['today_sales'] ?? 0).toStringAsFixed(0)}', AppLang.tr(isEn, 'Today\'s Sales', 'आज की बिक्री'), Icons.trending_up_rounded, AppColors.primary)),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard('₹${(stats['total_udhar'] ?? 0).toStringAsFixed(0)}', AppLang.tr(isEn, 'Pending Credit', 'बकाया उधार'), Icons.people_outline_rounded, AppColors.warning)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _statCard('${stats['today_bills'] ?? 0}', AppLang.tr(isEn, 'Bills Today', 'आज के बिल'), Icons.receipt_outlined, AppColors.success)),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard('${stats['low_stock'] ?? 0}', AppLang.tr(isEn, 'Low Stock', 'कम स्टॉक'), Icons.inventory_2_outlined, AppColors.error)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(AppLang.tr(isEn, 'Quick Actions', 'त्वरित कार्य'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10, mainAxisSpacing: 10,
                      children: [
                        _quickAction(Icons.document_scanner_rounded, AppLang.tr(isEn, 'Bill\nScan', 'बिल\nस्कैन'), AppColors.primary, () {
                          final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                          homeState?.setState(() => homeState._currentIndex = 1);
                        }),
                        _quickAction(Icons.add_circle_outline_rounded, AppLang.tr(isEn, 'Add\nSale', 'बिक्री\nजोड़ें'), AppColors.success, () {
                          final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                          homeState?.setState(() => homeState._currentIndex = 1);
                        }),
                        _quickAction(Icons.people_outline_rounded, AppLang.tr(isEn, 'Credit', 'उधार'), AppColors.warning, () {
                          final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                          homeState?.setState(() => homeState._currentIndex = 3);
                        }),
                        _quickAction(Icons.inventory_2_outlined, AppLang.tr(isEn, 'Stock', 'स्टॉक'), AppColors.purple, () {
                          final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                          homeState?.setState(() => homeState._currentIndex = 2);
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLang.tr(isEn, 'Today\'s Bills', 'आज के बिल'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        TextButton(
                          onPressed: () {
                            final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                            homeState?.setState(() => homeState._currentIndex = 1);
                          },
                          child: Text(AppLang.tr(isEn, 'View All', 'सभी देखें'), style: const TextStyle(fontSize: 13, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    billsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                      error: (e, _) => const SizedBox(),
                      data: (bills) => bills.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.receipt_long_outlined, color: AppColors.textHint, size: 32),
                                    const SizedBox(height: 8),
                                    Text(AppLang.tr(isEn, 'No bills today', 'आज कोई बिल नहीं'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                                    Text(AppLang.tr(isEn, 'Scan a bill or add a sale', 'बिल स्कैन करें या बिक्री जोड़ें'), style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : Column(children: bills.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final bill = entry.value;
                              return _billItem(
                                idx + 1,
                                bill.vendorName.isEmpty ? AppLang.tr(isEn, 'Bill', 'बिल') : bill.vendorName,
                                '₹${bill.amount.toStringAsFixed(0)}',
                                bill.billType,
                              );
                            }).toList()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), maxLines: 1),
            ),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _billItem(int entryNumber, String name, String amount, String billType) {
    final isSale = billType == 'sale';
    final iconColor = isSale ? AppColors.success : AppColors.primary;
    final iconBg = isSale ? AppColors.success.withOpacity(0.1) : AppColors.primaryBg;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Text('#$entryNumber', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: iconColor)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
              Text(billType == 'sale' ? 'Sale' : 'Purchase', style: TextStyle(fontSize: 11, color: isSale ? AppColors.success : AppColors.textSecondary)),
            ],
          )),
          Text(amount, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: iconColor)),
        ],
      ),
    );
  }
}