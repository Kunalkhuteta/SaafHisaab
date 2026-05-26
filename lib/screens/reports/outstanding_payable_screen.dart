import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';

/// Provider that fetches purchase parties with pending amounts > 0
final outstandingPayableProvider =
    FutureProvider.autoDispose<List<OutstandingPayableItem>>((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];

  final parties =
      await SupabaseService.getPurchasePartiesWithPending(shop.id);
  final items = <OutstandingPayableItem>[];

  for (final party in parties) {
    final partyName = party['name'] as String? ?? '';
    final bills = await SupabaseService.getPurchaseBillsForParty(
        shop.id, partyName);

    // Filter to credit bills (bills where related sales have credit/split payment mode)
    final creditBills = <BillModel>[];
    for (final bill in bills) {
      try {
        final sales = await SupabaseService.getSalesByBillId(bill.id);
        final isCreditBill = sales.any((s) =>
            s.paymentMode == 'credit' || s.paymentMode == 'split');
        if (isCreditBill) {
          creditBills.add(bill);
        }
      } catch (_) {
        // If no sales found, still include the bill
      }
    }

    items.add(OutstandingPayableItem(
      party: party,
      creditBills: creditBills,
      allBills: bills,
    ));
  }

  return items;
});

class OutstandingPayableItem {
  final Map<String, dynamic> party;
  final List<BillModel> creditBills;
  final List<BillModel> allBills;

  OutstandingPayableItem({
    required this.party,
    required this.creditBills,
    required this.allBills,
  });

  String get partyId => party['id'] as String? ?? '';
  String get partyName => party['name'] as String? ?? '';
  String get partyPhone => party['phone_number'] as String? ?? '';
  String get partyStation => party['station'] as String? ?? '';
  String get partyGst => party['gst_number'] as String? ?? '';
  double get pendingAmount =>
      (party['pending_amount'] as num?)?.toDouble() ?? 0;
  double get totalPurchased =>
      allBills.fold(0.0, (sum, bill) => sum + bill.amount);
}

class OutstandingPayableScreen extends ConsumerWidget {
  const OutstandingPayableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(appLanguageProvider);
    final reportAsync = ref.watch(outstandingPayableProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(
          isEn,
          'Outstanding Payable',
          'बकाया देय',
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
                    AppLang.tr(isEn, 'No outstanding payables',
                        'कोई बकाया देय नहीं'),
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
                        'All supplier payments are cleared!',
                        'सभी सप्लायर भुगतान चुकता हैं!'),
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
              0.0, (sum, item) => sum + item.pendingAmount);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(outstandingPayableProvider),
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
                        AppColors.error,
                        AppColors.error.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Text(
                      AppLang.tr(isEn, 'Total Outstanding Payable',
                          'कुल बकाया देय'),
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
                      '${items.length} ${AppLang.tr(isEn, 'suppliers', 'सप्लायर')}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                ...items.map((item) => _PayableCard(
                      item: item,
                      isEn: isEn,
                      onRecordPayment: () =>
                          _showRecordPaymentSheet(context, ref, item, isEn),
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
    OutstandingPayableItem item,
    bool isEn,
  ) {
    final amountCtrl = TextEditingController();
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
                    AppLang.tr(isEn, 'Record Payment to Supplier',
                        'सप्लायर को भुगतान दर्ज करें'),
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
                            item.partyName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (item.partyPhone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                item.partyPhone,
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Rs ${item.pendingAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.error,
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
                          isEn, 'Payment Amount Rs', 'भुगतान राशि Rs'),
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
                        'card',
                        AppLang.tr(isEn, 'Card', 'कार्ड'),
                        Icons.credit_card,
                        paymentMethod, (v) {
                      setSheetState(() => paymentMethod = v);
                    }),
                  ]),
                  const SizedBox(height: 20),

                  // Pay full amount button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        amountCtrl.text =
                            item.pendingAmount.toStringAsFixed(0);
                      },
                      child: Text(
                        AppLang.tr(isEn, 'Pay Full Amount',
                            'पूरी रकम भरें'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

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
                        if (amount > item.pendingAmount) {
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
                          final newPending =
                              item.pendingAmount - amount;
                          await SupabaseService
                              .updatePurchasePartyPendingAmount(
                                  item.partyId, newPending);

                          ref.invalidate(outstandingPayableProvider);
                          ref.invalidate(purchasePartiesProvider);

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLang.tr(
                                  isEn,
                                  'Payment of Rs ${amount.toStringAsFixed(0)} recorded for ${item.partyName}',
                                  '${item.partyName} को Rs ${amount.toStringAsFixed(0)} भुगतान दर्ज',
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

class _PayableCard extends StatefulWidget {
  final OutstandingPayableItem item;
  final bool isEn;
  final VoidCallback onRecordPayment;

  const _PayableCard({
    required this.item,
    required this.isEn,
    required this.onRecordPayment,
  });

  @override
  State<_PayableCard> createState() => _PayableCardState();
}

class _PayableCardState extends State<_PayableCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isEn = widget.isEn;
    final onRecordPayment = widget.onRecordPayment;

    final displayedBills = _isExpanded ? item.allBills : item.allBills.take(3).toList();

    return Container(
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
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                item.partyName.isNotEmpty
                    ? item.partyName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.error,
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
                    item.partyName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.partyPhone.isNotEmpty)
                    Text(
                      item.partyPhone,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (item.partyStation.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.location_city_rounded,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(
                        item.partyStation,
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ]),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              'Rs ${item.pendingAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              AppLang.tr(isEn, 'Payable', 'देय'),
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ]),

        if (item.allBills.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLang.tr(
                        isEn, 'Recent Purchase Bills', 'हालिया खरीद बिल'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...displayedBills.map(
                        (bill) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            const Icon(Icons.receipt_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_date(bill.billDate)} — Rs ${bill.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                  if (item.allBills.length > 3)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded
                                  ? AppLang.tr(isEn, 'Show Less', 'कम दिखाएं')
                                  : '+${item.allBills.length - 3} ${AppLang.tr(isEn, 'more', 'और')}',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],

        if (item.partyGst.isNotEmpty) ...[
          const SizedBox(height: 8),
          _infoLine(
            AppLang.tr(isEn, 'GST', 'GST'),
            item.partyGst,
          ),
        ],

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
    );
  }

  Widget _infoLine(String label, String value) {
    return Row(children: [
      Text(
        '$label: ',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      Flexible(
        child: Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ]);
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}
