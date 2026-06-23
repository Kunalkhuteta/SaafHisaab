import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/daily_balance_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import 'package:saafhisaab/utils/indian_date_time.dart';


// Provider to manage the selected month and year
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = IndianDateTime.now();
  return IndianDateTime.date(now.year, now.month);
});

// Provider to fetch daily balances based on the selected month
final dailyBalancesProvider = FutureProvider.autoDispose<List<DailyBalanceModel>>((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];
  
  final selectedMonth = ref.watch(selectedMonthProvider);
  return await SupabaseService.syncAndGetDailyBalances(shop.id, selectedMonth.month, selectedMonth.year);
});

class DailyBalancesScreen extends ConsumerWidget {
  const DailyBalancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(appLanguageProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final balancesAsync = ref.watch(dailyBalancesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'Daily Cash & Bank', 'दैनिक नकद और बैंक')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                  onPressed: () {
                    ref.read(selectedMonthProvider.notifier).state = 
                        IndianDateTime.date(selectedMonth.year, selectedMonth.month - 1);
                  },
                ),
                Text(
                  _formatMonthYear(selectedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  onPressed: () {
                    final nextMonth = IndianDateTime.date(selectedMonth.year, selectedMonth.month + 1);
                    if (nextMonth.isBefore(IndianDateTime.now()) || _isSameMonth(nextMonth, IndianDateTime.now())) {
                      ref.read(selectedMonthProvider.notifier).state = nextMonth;
                    }
                  },
                ),
              ],
            ),
          ),

          // Total Summary Card
          balancesAsync.when(
            data: (balances) {
              double totalNetCash = 0;
              double totalNetBank = 0;
              for (var b in balances) {
                totalNetCash += b.netCash;
                totalNetBank += b.netBank;
              }

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryStat(
                        title: AppLang.tr(isEn, 'Net Cash Flow', 'कुल नकद प्रवाह'),
                        amount: totalNetCash,
                        icon: Icons.payments_rounded,
                      ),
                    ),
                    Container(width: 1, height: 50, color: Colors.white.withOpacity(0.2)),
                    Expanded(
                      child: _SummaryStat(
                        title: AppLang.tr(isEn, 'Net Bank Flow', 'कुल बैंक प्रवाह'),
                        amount: totalNetBank,
                        icon: Icons.account_balance_rounded,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),

          // List View
          Expanded(
            child: balancesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (balances) {
                if (balances.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textHint.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          AppLang.tr(isEn, 'No transactions found for this month', 'इस महीने कोई लेन-देन नहीं मिला'),
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(dailyBalancesProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: balances.length,
                    itemBuilder: (context, index) {
                      final balance = balances[index];
                      return _DailyBalanceCard(balance: balance, isEn: isEn);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}

class _SummaryStat extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;

  const _SummaryStat({required this.title, required this.amount, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _DailyBalanceCard extends StatelessWidget {
  final DailyBalanceModel balance;
  final bool isEn;

  const _DailyBalanceCard({required this.balance, required this.isEn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Date Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary.withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(
                  '${balance.balanceDate.day.toString().padLeft(2, '0')}-${balance.balanceDate.month.toString().padLeft(2, '0')}-${balance.balanceDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          
          // Data Rows
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Cash Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(AppLang.tr(isEn, 'Cash', 'नकद'), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _FlowRow(label: AppLang.tr(isEn, 'In', 'आया'), amount: balance.cashIn, color: AppColors.success),
                      const SizedBox(height: 6),
                      _FlowRow(label: AppLang.tr(isEn, 'Out', 'गया'), amount: balance.cashOut, color: AppColors.error),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _FlowRow(label: AppLang.tr(isEn, 'Net', 'कुल'), amount: balance.netCash, color: balance.netCash >= 0 ? AppColors.success : AppColors.error, isBold: true),
                    ],
                  ),
                ),
                
                Container(width: 1, height: 100, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
                
                // Bank Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(AppLang.tr(isEn, 'Bank/UPI', 'बैंक/UPI'), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _FlowRow(label: AppLang.tr(isEn, 'In', 'आया'), amount: balance.bankIn, color: AppColors.success),
                      const SizedBox(height: 6),
                      _FlowRow(label: AppLang.tr(isEn, 'Out', 'गया'), amount: balance.bankOut, color: AppColors.error),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _FlowRow(label: AppLang.tr(isEn, 'Net', 'कुल'), amount: balance.netBank, color: balance.netBank >= 0 ? AppColors.success : AppColors.error, isBold: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isBold;

  const _FlowRow({required this.label, required this.amount, required this.color, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
