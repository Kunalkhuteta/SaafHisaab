import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import 'receivable_party_detail_screen.dart';

final outstandingReceivableProvider =
    FutureProvider.autoDispose<List<UdharCustomerModel>>((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];

  final customers = await SupabaseService.getAllUdharCustomers(shop.id);
  final recalculated = <UdharCustomerModel>[];
  for (final customer in customers) {
    final totalDue =
        await SupabaseService.recalculateCustomerTotalDue(customer.id);
    if (totalDue > 0) {
      recalculated.add(customer.copyWith(totalDue: totalDue));
    }
  }
  recalculated.sort((a, b) => b.totalDue.compareTo(a.totalDue));
  return recalculated;
});

class OutstandingReceivableScreen extends ConsumerWidget {
  const OutstandingReceivableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(appLanguageProvider);
    final reportAsync = ref.watch(outstandingReceivableProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(
          isEn,
          'Outstanding Receivable',
          'बकाया प्राप्तव्य',
        )),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: reportAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 64, color: AppColors.success.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    AppLang.tr(isEn, 'No outstanding receivables',
                        'कोई बकाया प्राप्तव्य नहीं'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLang.tr(
                        isEn,
                        'All customer payments are cleared!',
                        'सभी ग्राहक भुगतान चुकता हैं!'),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          final totalOutstanding = items.fold(
              0.0, (sum, item) => sum + item.totalDue);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(outstandingReceivableProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total outstanding header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.warning,
                        AppColors.warning.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Text(
                      AppLang.tr(isEn, 'Total Outstanding Receivable',
                          'कुल बकाया प्राप्तव्य'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rs ${totalOutstanding.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${items.length} ${AppLang.tr(isEn, 'customers', 'ग्राहक')}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                ...items.map((item) => _ReceivableCard(
                      item: item,
                      isEn: isEn,
                      onRecordPayment: () =>
                          _showRecordPaymentSheet(context, ref, item, isEn),
                      onOpenDetails: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ReceivablePartyDetailScreen(customer: item),
                          ),
                        );
                      },
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRecordPaymentSheet(
    BuildContext context,
    WidgetRef ref,
    UdharCustomerModel item,
    bool isEn,
  ) {
    final amountCtrl = TextEditingController(text: item.totalDue.toStringAsFixed(0));
    String paymentMethod = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppLang.tr(isEn, 'Record Payment from Customer',
                        'ग्राहक से भुगतान दर्ज करें'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Party info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (item.customerPhone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                item.customerPhone,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Text(
                              AppLang.tr(isEn, 'Pending: ',
                                  'बकाया: '),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Rs ${item.totalDue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ]),
                        ]),
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: AppLang.tr(
                          isEn, 'Received Amount Rs', 'प्राप्त राशि Rs'),
                      prefixIcon: const Icon(Icons.currency_rupee_rounded,
                          size: 20),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderBlue),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderBlue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment method
                  Text(
                    AppLang.tr(
                        isEn, 'Payment Method', 'भुगतान तरीका'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _methodChip('cash',
                        AppLang.tr(isEn, 'Cash', 'नकद'),
                        Icons.money, paymentMethod, (v) {
                      setSheetState(() => paymentMethod = v);
                    }),
                    _methodChip('upi', 'UPI',
                        Icons.phone_android_rounded, paymentMethod, (v) {
                      setSheetState(() => paymentMethod = v);
                    }),
                    _methodChip(
                        'bank',
                        AppLang.tr(isEn, 'Bank', 'बैंक'),
                        Icons.account_balance_rounded,
                        paymentMethod, (v) {
                      setSheetState(() => paymentMethod = v);
                    }),
                  ]),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final amount =
                            double.tryParse(amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(AppLang.tr(
                                isEn,
                                'Enter a valid amount',
                                'सही राशि डालें')),
                            backgroundColor: AppColors.error,
                          ));
                          return;
                        }
                        if (amount > item.totalDue) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(AppLang.tr(
                                isEn,
                                'Amount cannot exceed pending balance',
                                'राशि बकाया से अधिक नहीं हो सकती')),
                            backgroundColor: AppColors.error,
                          ));
                          return;
                        }

                        try {
                          final shop = ref.read(shopProvider).value;
                          final userId = AuthService.currentUserId;
                          if (shop == null || userId == null) {
                            throw Exception('Shop or user not found');
                          }

                          // Get first credit entry if exists to link it
                          final entries = await SupabaseService.getUdharEntriesForCustomer(item.id);
                          final creditEntries = entries.where((entry) => entry.entryType == 'credit');
                          final appliedCreditEntryId =
                              creditEntries.isEmpty ? null : creditEntries.first.id;

                          await SupabaseService.recordUdharPayment(
                            shopId: shop.id,
                            userId: userId,
                            customer: item,
                            amount: amount,
                            paymentMethod: paymentMethod,
                            appliedCreditEntryId: appliedCreditEntryId,
                          );

                          ref.invalidate(outstandingReceivableProvider);
                          ref.invalidate(udharCustomersProvider);
                          ref.invalidate(dashboardStatsProvider);
                          ref.invalidate(todayBillsProvider);

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLang.tr(
                                  isEn,
                                  'Payment of Rs ${amount.toStringAsFixed(0)} recorded from ${item.customerName}',
                                  '${item.customerName} से Rs ${amount.toStringAsFixed(0)} भुगतान दर्ज',
                                )),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(AppLang.tr(isEn, 'Record Payment',
                          'भुगतान दर्ज करें')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _methodChip(String value, String label, IconData icon,
      String current, ValueChanged<String> onTap) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 16,
              color: sel ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _ReceivableCard extends StatelessWidget {
  final UdharCustomerModel item;
  final bool isEn;
  final VoidCallback onRecordPayment;
  final VoidCallback onOpenDetails;

  const _ReceivableCard({
    required this.item,
    required this.isEn,
    required this.onRecordPayment,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenDetails,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                item.customerName.isNotEmpty
                    ? item.customerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.customerName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.customerPhone.isNotEmpty)
                    Text(
                      item.customerPhone,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              'Rs ${item.totalDue.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              AppLang.tr(isEn, 'Receivable', 'प्राप्तव्य'),
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
          ]),
        ]),

        const SizedBox(height: 12),

        // Record Payment button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onRecordPayment,
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: Text(
              AppLang.tr(isEn, 'Record Payment', 'भुगतान दर्ज करें'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
          ),
        ),
        ]),
      ),
    );
  }
}
