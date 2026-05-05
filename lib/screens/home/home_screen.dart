import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(shopProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final billsAsync = ref.watch(todayBillsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: shopAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shop) => Column(
          children: [
            // Blue header with real shop name
            Container(
              color: AppColors.primary,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20, right: 20, bottom: 20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Namaste, ${shop?.ownerName ?? 'ji'} 👋',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shop?.shopName ?? 'Aapki Dukaan',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sign out button
                  GestureDetector(
                    onTap: () async {
                      await AuthService.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Real stats from Supabase
                    statsAsync.when(
                      loading: () => const SizedBox(
                        height: 100,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                        ),
                      ),
                      error: (e, _) => const SizedBox(),
                      data: (stats) => Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _statCard(
                                '₹${(stats['today_sales'] ?? 0).toStringAsFixed(0)}',
                                'Aaj ki sale',
                                Icons.trending_up_rounded,
                                AppColors.primary,
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard(
                                '₹${(stats['total_udhar'] ?? 0).toStringAsFixed(0)}',
                                'Pending udhar',
                                Icons.people_outline_rounded,
                                AppColors.warning,
                              )),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _statCard(
                                '${stats['today_bills'] ?? 0}',
                                'Bills aaj',
                                Icons.receipt_outlined,
                                AppColors.success,
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard(
                                '${stats['low_stock'] ?? 0}',
                                'Low stock',
                                Icons.inventory_2_outlined,
                                AppColors.error,
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Quick actions
                    const Text('Quick Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _quickAction(Icons.document_scanner_rounded,
                            'Bill\nScan', AppColors.primary, () {}),
                        _quickAction(Icons.add_circle_outline_rounded,
                            'Sale\nAdd', AppColors.success, () {}),
                        _quickAction(Icons.people_outline_rounded,
                            'Udhar', AppColors.warning, () {}),
                        _quickAction(Icons.inventory_2_outlined,
                            'Stock', AppColors.purple, () {}),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Today's bills — real data
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Aaj ke Bills',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            )),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Sab dekho',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    billsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                      ),
                      error: (e, _) => const SizedBox(),
                      data: (bills) => bills.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_outlined,
                                        color: AppColors.textHint, size: 32),
                                    SizedBox(height: 8),
                                    Text('Aaj koi bill nahi',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 14)),
                                    Text('Bill scan karo ya sale add karo',
                                        style: TextStyle(
                                            color: AppColors.textHint,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: bills
                                  .map((bill) => _billItem(
                                        bill.vendorName.isEmpty
                                            ? 'Bill'
                                            : bill.vendorName,
                                        '₹${bill.amount.toStringAsFixed(0)}',
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), label: 'Bills'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded), label: 'Stock'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded), label: 'Udhar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded), label: 'More'),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _billItem(String name, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
          Text(amount,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}