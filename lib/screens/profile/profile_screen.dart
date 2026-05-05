import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(shopProvider);

    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20, right: 20, bottom: 20,
          ),
          child: shopAsync.when(
            loading: () => const SizedBox(height: 60),
            error: (_, __) => const SizedBox(height: 60),
            data: (shop) => Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(
                    shop?.ownerName.isNotEmpty == true ? shop!.ownerName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(shop?.ownerName ?? 'User',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(shop?.shopName ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
                ])),
              ],
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Shop info card
                shopAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (shop) => shop == null
                      ? const SizedBox()
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(children: [
                            _infoRow(Icons.store_rounded, 'Dukaan', shop.shopName),
                            _infoRow(Icons.category_rounded, 'Type', shop.shopType),
                            _infoRow(Icons.location_city_rounded, 'Shahar', shop.city),
                            _infoRow(Icons.phone_rounded, 'Phone', shop.phone),
                            if (shop.gstNumber.isNotEmpty)
                              _infoRow(Icons.receipt_rounded, 'GST', shop.gstNumber),
                            _infoRow(Icons.star_rounded, 'Plan', shop.plan.toUpperCase()),
                          ]),
                        ),
                ),

                const SizedBox(height: 16),

                // Menu items
                _menuItem(Icons.notifications_outlined, 'Notifications', () {}),
                _menuItem(Icons.help_outline_rounded, 'Help & Support', () {}),
                _menuItem(Icons.info_outline_rounded, 'About SaafHisaab', () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'SaafHisaab',
                    applicationVersion: '1.0.0',
                    children: [const Text('Aapki dukaan ka saaf hisaab')],
                  );
                }),

                const SizedBox(height: 16),

                // Sign out
                SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                    label: const Text('Sign Out',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Text('SaafHisaab v1.0.0',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Expanded(child: Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ]),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
        ]),
      ),
    );
  }
}
