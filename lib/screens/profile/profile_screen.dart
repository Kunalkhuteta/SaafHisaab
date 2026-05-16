import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../auth/login_screen.dart';
import '../auth/set_passcode_screen.dart';
import '../settings/session_timeout_screen.dart';
import '../../globalVar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(appLanguageProvider);
    final shopAsync = ref.watch(shopProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 20),
          child: shopAsync.when(
            loading: () => const SizedBox(height: 60),
            error: (_, __) => const SizedBox(height: 60),
            data: (shop) => Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(
                    shop?.ownerName.isNotEmpty == true ? shop!.ownerName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(shop?.ownerName ?? AppLang.tr(isEn, 'User', 'उपयोगकर्ता'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(shop?.shopName ?? '', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
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
                shopAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (shop) => shop == null
                      ? const SizedBox()
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                          child: Column(children: [
                            _infoRow(Icons.store_rounded, AppLang.tr(isEn, 'Shop', 'दुकान'), shop.shopName),
                            _infoRow(Icons.category_rounded, AppLang.tr(isEn, 'Type', 'प्रकार'), shop.shopType),
                            _infoRow(Icons.location_city_rounded, AppLang.tr(isEn, 'City', 'शहर'), shop.city),
                            _infoRow(Icons.phone_rounded, AppLang.tr(isEn, 'Phone', 'फ़ोन'), shop.phone),
                            if (shop.gstNumber.isNotEmpty)
                              _infoRow(Icons.receipt_rounded, 'GST', shop.gstNumber),
                            _infoRow(Icons.star_rounded, AppLang.tr(isEn, 'Plan', 'प्लान'), shop.plan.toUpperCase()),
                          ]),
                        ),
                ),
                const SizedBox(height: 16),
                
                // Language Dropdown Setting
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(AppLang.tr(isEn, 'App Language', 'ऐप की भाषा'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<bool>(
                          value: isEn,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textHint),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('English')),
                            DropdownMenuItem(value: false, child: Text('हिन्दी')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(appLanguageProvider.notifier).setLanguage(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Chart Type Setting
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(AppLang.tr(isEn, 'Default Chart Type', 'डिफ़ॉल्ट चार्ट प्रकार'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      ),
                      Consumer(
                        builder: (ctx, ref, _) {
                          final chartType = ref.watch(chartTypeProvider);
                          return DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: chartType,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textHint),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                              items: const [
                                DropdownMenuItem(value: 'bar', child: Text('Bar Chart')),
                                DropdownMenuItem(value: 'line', child: Text('Line Chart')),
                                DropdownMenuItem(value: 'pie', child: Text('Pie Chart')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(chartTypeProvider.notifier).setChartType(val);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Security section
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(AppLang.tr(isEn, 'Security', 'सुरक्षा'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                _menuItem(Icons.lock_outline_rounded, AppLang.tr(isEn, 'Change Passcode', 'Passcode बदलें'), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SetPasscodeScreen()));
                }),
                _menuItem(Icons.timer_outlined, AppLang.tr(isEn, 'Session Timeout', 'सेशन टाइमआउट'), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionTimeoutScreen()));
                }),
                _menuItem(Icons.delete_outline_rounded, AppLang.tr(isEn, 'Remove Passcode', 'Passcode हटाएं'), () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(AppLang.tr(isEn, 'Remove Passcode?', 'Passcode हटाएं?')),
                      content: Text(AppLang.tr(isEn, 'Your app will no longer be locked.', 'आपका ऐप अब लॉक नहीं रहेगा।')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLang.tr(isEn, 'Cancel', 'रद्द करें'))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLang.tr(isEn, 'Remove', 'हटाएं'), style: const TextStyle(color: AppColors.error))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await SessionService.clearPasscode();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(AppLang.tr(isEn, 'Passcode removed', 'Passcode हटा दिया गया')),
                        backgroundColor: AppColors.success,
                      ));
                    }
                  }
                }),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(AppLang.tr(isEn, 'General', 'सामान्य'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                _menuItem(Icons.notifications_outlined, AppLang.tr(isEn, 'Notifications', 'सूचनाएं'), () {}),
                _menuItem(Icons.help_outline_rounded, AppLang.tr(isEn, 'Help & Support', 'मदद और सहायता'), () {}),
                _menuItem(Icons.info_outline_rounded, AppLang.tr(isEn, 'About SaafHisaab', 'SaafHisaab के बारे में'), () {
                  showAboutDialog(context: context, applicationName: 'SaafHisaab', applicationVersion: '1.0.0', children: [Text(AppLang.tr(isEn, 'Clean Accounts for Your Shop', 'आपकी दुकान का साफ़ हिसाब'))]);
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await SessionService.clearPasscode();
                      await AuthService.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                    label: Text(AppLang.tr(isEn, 'Sign Out', 'लॉग आउट करें'), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.error.withOpacity(0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('SaafHisaab v1.0.0', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ]),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
        ]),
      ),
    );
  }
}
