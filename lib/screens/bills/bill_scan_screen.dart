import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../globalVar.dart';
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ──
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                bottom: 20),
            child: Row(children: [
              Expanded(
                child: Text(
                  AppLang.tr(isEn, 'Invoices', 'चालान (Invoices)'),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ]),
          ),

          // ── Dashboard Grid ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLang.tr(isEn, 'Manage Records', 'रिकॉर्ड प्रबंधित करें'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(child: _dashboardCard(
                        isEn, 'Sales Invoice', 'बिक्री चालान (SIN)', 
                        Icons.trending_up_rounded, AppColors.success, 
                        'sale'
                      )),
                      const SizedBox(width: 14),
                      Expanded(child: _dashboardCard(
                        isEn, 'Purchase Invoice', 'खरीद चालान (PIN)', 
                        Icons.shopping_cart_rounded, AppColors.primary, 
                        'purchase'
                      )),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _dashboardCard(
                        isEn, 'Sales Return', 'बिक्री वापसी (SRN)', 
                        Icons.assignment_return_rounded, AppColors.warning, 
                        'sale_return'
                      )),
                      const SizedBox(width: 14),
                      Expanded(child: _dashboardCard(
                        isEn, 'Purchase Return', 'खरीद वापसी (PRN)', 
                        Icons.outbox_rounded, AppColors.purple, 
                        'purchase_return'
                      )),
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

  Widget _dashboardCard(bool isEn, String title, String titleHi, IconData icon, Color color, String billType) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => InvoiceListScreen(
            billType: billType,
            title: title,
            titleHi: titleHi,
          ),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              AppLang.tr(isEn, title, titleHi),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
