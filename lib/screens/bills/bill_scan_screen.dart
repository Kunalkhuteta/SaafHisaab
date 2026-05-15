import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import 'invoice_list_screen.dart';

class BillScanScreen extends ConsumerStatefulWidget {
  const BillScanScreen({super.key});

  @override
  ConsumerState<BillScanScreen> createState() => _BillScanScreenState();
}

class _BillScanScreenState extends ConsumerState<BillScanScreen> {
  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLang.tr(isEn, 'Invoices', 'चालान (Invoices)'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                  Text(
                    AppLang.tr(isEn, 'Manage Records', 'रिकॉर्ड प्रबंधित करें'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _dashboardCard(
                    isEn,
                    'Sales Invoice',
                    'बिक्री चालान (SIN)',
                    Icons.trending_up_rounded,
                    'sale',
                  ),
                  const SizedBox(height: 12),
                  _dashboardCard(
                    isEn,
                    'Purchase Invoice',
                    'खरीद चालान (PIN)',
                    Icons.shopping_cart_rounded,
                    'purchase',
                  ),
                  const SizedBox(height: 12),
                  _dashboardCard(
                    isEn,
                    'Sales Return',
                    'बिक्री वापसी (SRN)',
                    Icons.assignment_return_rounded,
                    'sale_return',
                  ),
                  const SizedBox(height: 12),
                  _dashboardCard(
                    isEn,
                    'Purchase Return',
                    'खरीद वापसी (PRN)',
                    Icons.outbox_rounded,
                    'purchase_return',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard(
    bool isEn,
    String title,
    String titleHi,
    IconData icon,
    String billType,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceListScreen(
              billType: billType,
              title: title,
              titleHi: titleHi,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderBlue),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                AppLang.tr(isEn, title, titleHi),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
