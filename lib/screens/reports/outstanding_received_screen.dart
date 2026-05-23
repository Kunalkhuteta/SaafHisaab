import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../widgets/credit_entry_sheet.dart';

final outstandingReceivedProvider =
    FutureProvider.autoDispose<List<OutstandingReceivedItem>>((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];

  final customers = await SupabaseService.getAllUdharCustomers(shop.id);
  final items = <OutstandingReceivedItem>[];

  for (final customer in customers) {
    final entries = await SupabaseService.getUdharEntriesForCustomer(customer.id);
    final credits = entries
        .where((entry) => entry.entryType == 'credit')
        .toList()
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));
    final payments = entries.where((entry) {
      return entry.entryType == 'debit' &&
          UdharPaymentMeta.tryParseNote(entry.note) != null;
    }).toList();

    for (final payment in payments) {
      final meta = UdharPaymentMeta.tryParseNote(payment.note)!;
      final credit = _matchingCredit(credits, payment, meta);
      final sale = credit == null
          ? null
          : SavedCreditSale.tryParseNote(credit.note, customerId: customer.id);
      items.add(OutstandingReceivedItem(
        customer: customer,
        payment: payment,
        paymentMeta: meta,
        credit: credit,
        creditSale: sale,
      ));
    }
  }

  items.sort((a, b) => b.payment.entryDate.compareTo(a.payment.entryDate));
  return items;
});

UdharEntryModel? _matchingCredit(
  List<UdharEntryModel> credits,
  UdharEntryModel payment,
  UdharPaymentMeta meta,
) {
  if (meta.appliedCreditEntryId != null) {
    for (final credit in credits) {
      if (credit.id == meta.appliedCreditEntryId) return credit;
    }
  }

  final beforePayment = credits
      .where((credit) => !credit.entryDate.isAfter(payment.entryDate))
      .toList();
  if (beforePayment.isNotEmpty) return beforePayment.last;
  return credits.isEmpty ? null : credits.last;
}

class OutstandingReceivedItem {
  final UdharCustomerModel customer;
  final UdharEntryModel payment;
  final UdharPaymentMeta paymentMeta;
  final UdharEntryModel? credit;
  final SavedCreditSale? creditSale;

  const OutstandingReceivedItem({
    required this.customer,
    required this.payment,
    required this.paymentMeta,
    this.credit,
    this.creditSale,
  });

  double get totalBillAmount => creditSale?.totalAmount ?? credit?.amount ?? 0;
  double get paidAmount => payment.amount;
  double get remainingAmount => paymentMeta.remainingAmount;
  bool get isPartial => remainingAmount > 0;
  DateTime get purchaseDate => credit?.entryDate ?? payment.entryDate;
}

class OutstandingReceivedScreen extends ConsumerWidget {
  const OutstandingReceivedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(appLanguageProvider);
    final reportAsync = ref.watch(outstandingReceivedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(
          isEn,
          'Outstanding Received',
          'बकाया प्राप्त',
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
              child: Text(
                AppLang.tr(isEn, 'No received outstanding payments',
                    'कोई बकाया भुगतान प्राप्त नहीं'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(outstandingReceivedProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _OutstandingCard(item: items[index], isEn: isEn),
            ),
          );
        },
      ),
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  final OutstandingReceivedItem item;
  final bool isEn;

  const _OutstandingCard({required this.item, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isPartial ? AppColors.warning : AppColors.success;
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.isPartial
                  ? Icons.paid_outlined
                  : Icons.check_circle_outline_rounded,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                item.customer.customerName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (item.customer.customerPhone.isNotEmpty)
                Text(
                  item.customer.customerPhone,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ]),
          ),
          Text(
            item.isPartial
                ? AppLang.tr(isEn, 'Part Payment', 'पार्ट पेमेंट')
                : AppLang.tr(isEn, 'Paid', 'भुगतान'),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _line(AppLang.tr(isEn, 'Bill generation date', 'बिल तारीख'),
            _date(item.purchaseDate)),
        _line(AppLang.tr(isEn, 'Item purchase date', 'खरीद तारीख'),
            _date(item.purchaseDate)),
        _line(AppLang.tr(isEn, 'Total bill amount', 'कुल बिल राशि'),
            'Rs ${item.totalBillAmount.toStringAsFixed(0)}'),
        _line(
          AppLang.tr(isEn, 'Amount paid', 'भुगतान राशि'),
          'Rs ${item.paidAmount.toStringAsFixed(0)} on ${_date(item.payment.entryDate)}',
          strong: true,
        ),
        if (item.isPartial)
          _line(
            AppLang.tr(isEn, 'Remaining outstanding', 'बाकी बकाया'),
            'Rs ${item.remainingAmount.toStringAsFixed(0)}',
            valueColor: AppColors.error,
          ),
        _line(
          AppLang.tr(isEn, 'Payment method', 'भुगतान तरीका'),
          item.paymentMeta.paymentMethod.toUpperCase(),
        ),
        if (item.creditSale?.items.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          ...item.creditSale!.items.map(
            (saleItem) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${saleItem.itemName} | ${saleItem.quantity.toStringAsFixed(saleItem.quantity.truncateToDouble() == saleItem.quantity ? 0 : 2)} ${saleItem.unit} | Rs ${saleItem.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        if (item.paymentMeta.receiptImageUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.paymentMeta.receiptImageUrl,
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ]),
    );
  }

  Widget _line(
    String label,
    String value, {
    bool strong = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 12,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ]),
    );
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}
