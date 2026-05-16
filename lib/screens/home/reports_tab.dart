import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  final List<_ReportItem> _allReports = [
    _ReportItem(
      title: 'Top Trending',
      icon: Icons.trending_up_rounded,
      description: 'Most frequently sold and popular items',
    ),
    _ReportItem(
      title: 'Top Re-Order Items',
      icon: Icons.refresh_rounded,
      description: 'The Most Re-Order Items',
    ),
    _ReportItem(
      title: 'Transaction Voucher',
      icon: Icons.receipt_long_rounded,
      description: 'View and track all transaction vouchers',
    ),
    _ReportItem(
      title: 'Daily Cash & Bank Balance',
      icon: Icons.account_balance_rounded,
      description: 'Daily cash and bank account balances',
    ),
    _ReportItem(
      title: 'Cash Received from Party',
      icon: Icons.payments_rounded,
      description: 'Payments received in Cash from parties',
    ),
    _ReportItem(
      title: 'Dump Stock',
      icon: Icons.delete_outline_rounded,
      description: 'Damaged or unusable stock details',
    ),
    _ReportItem(
      title: 'Daily Item Wise Sale',
      icon: Icons.insert_chart_outlined_rounded,
      description: 'Daily sales report item by item',
    ),
    _ReportItem(
      title: 'Balance Sheet',
      icon: Icons.description_rounded,
      description: 'Overall financial position of the business',
    ),
    _ReportItem(
      title: 'Trading A/C',
      icon: Icons.swap_horiz_rounded,
      description: 'Trading account summary for the period',
    ),
    _ReportItem(
      title: 'Profit & Loss Account',
      icon: Icons.trending_down_rounded,
      description: 'Profit or loss calculation for the period',
    ),
    _ReportItem(
      title: 'Trial Balance',
      icon: Icons.account_balance_wallet_rounded,
      description: 'Verification of debit and credit balances',
    ),
    _ReportItem(
      title: 'Ledger Reports',
      icon: Icons.menu_book_rounded,
      description: 'Party-wise ledger account reports',
    ),
    _ReportItem(
      title: 'Goods Trading Accounts',
      icon: Icons.store_rounded,
      description: 'Item Wise Stock Report',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'Reports', 'रिपोर्ट्स')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;

          return ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 16,
              vertical: 16,
            ),
            itemCount: _allReports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _allReports[index];

              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                elevation: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.title} coming soon')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportItem {
  final String title;
  final IconData icon;
  final String description;

  _ReportItem({
    required this.title,
    required this.icon,
    required this.description,
  });
}
