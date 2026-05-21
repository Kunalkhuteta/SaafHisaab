import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/udhar_model.dart';
import '../../services/supabase_service.dart';
import '../../widgets/credit_entry_sheet.dart';

final udharEntriesProvider =
    FutureProvider.autoDispose.family<List<UdharEntryModel>, String>(
  (ref, customerId) => SupabaseService.getUdharEntriesForCustomer(customerId),
);

class UdharDetailScreen extends ConsumerWidget {
  final UdharCustomerModel customer;

  const UdharDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(appLanguageProvider);
    final entriesAsync = ref.watch(udharEntriesProvider(customer.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        _Header(customer: customer, isEn: isEn),
        Expanded(
          child: entriesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (entries) => RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async =>
                  ref.invalidate(udharEntriesProvider(customer.id)),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _SummaryPanel(
                    customer: customer,
                    entries: entries,
                    isEn: isEn,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLang.tr(isEn, 'Credit Activity', 'उधार गतिविधि'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (entries.isEmpty)
                    _EmptyHistory(isEn: isEn)
                  else
                    ...entries.map((entry) => _EntryCard(
                          entry: entry,
                          customer: customer,
                          isEn: isEn,
                        )),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  final UdharCustomerModel customer;
  final bool isEn;

  const _Header({required this.customer, required this.isEn});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 18,
        right: 18,
        bottom: 20,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              AppLang.tr(isEn, 'Customer Credit', 'ग्राहक उधार'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Center(
              child: Text(
                customer.customerName.isEmpty
                    ? '?'
                    : customer.customerName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                customer.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                customer.customerPhone.isEmpty
                    ? AppLang.tr(isEn, 'No phone number', 'फोन नंबर नहीं है')
                    : customer.customerPhone,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLang.tr(isEn, 'Total Pending', 'कुल बाकी'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs ${customer.totalDue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.error, size: 32),
          ]),
        ),
      ]),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final UdharCustomerModel customer;
  final List<UdharEntryModel> entries;
  final bool isEn;

  const _SummaryPanel({
    required this.customer,
    required this.entries,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final creditTotal = entries
        .where((entry) => entry.entryType == 'credit')
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final paidTotal = entries
        .where((entry) => entry.entryType == 'debit')
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final purchaseTotal = entries.fold<double>(0, (sum, entry) {
      final parsed = SavedCreditSale.tryParseNote(entry.note);
      return sum + (parsed?.totalAmount ?? (entry.entryType == 'credit' ? entry.amount : 0));
    });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        _Metric(
          label: AppLang.tr(isEn, 'Sales', 'बिक्री'),
          value: purchaseTotal,
          color: AppColors.primary,
        ),
        _divider(),
        _Metric(
          label: AppLang.tr(isEn, 'Paid', 'भुगतान'),
          value: paidTotal,
          color: AppColors.success,
        ),
        _divider(),
        _Metric(
          label: AppLang.tr(isEn, 'Pending', 'बाकी'),
          value: customer.totalDue,
          color: AppColors.error,
        ),
      ]),
    );
  }

  Widget _divider() => Container(
        height: 44,
        width: 1,
        color: AppColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Rs ${value.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ]),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final UdharEntryModel entry;
  final UdharCustomerModel customer;
  final bool isEn;

  const _EntryCard({
    required this.entry,
    required this.customer,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = SavedCreditSale.tryParseNote(
      entry.note,
      customerId: customer.id,
    );
    final isCredit = entry.entryType == 'credit';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.error : AppColors.success)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit
                  ? Icons.shopping_bag_outlined
                  : Icons.payments_outlined,
              color: isCredit ? AppColors.error : AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isCredit
                    ? AppLang.tr(isEn, 'Credit Sale', 'उधार बिक्री')
                    : AppLang.tr(isEn, 'Payment Received', 'भुगतान मिला'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(entry.entryDate),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          Text(
            '${isCredit ? '+' : '-'} Rs ${entry.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: isCredit ? AppColors.error : AppColors.success,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ]),
        if (parsed != null && isCredit) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              _DetailLine(
                label: AppLang.tr(isEn, 'Total amount', 'कुल रकम'),
                value: 'Rs ${parsed.totalAmount.toStringAsFixed(0)}',
              ),
              _DetailLine(
                label: AppLang.tr(isEn, 'Cash paid', 'नकद दिया'),
                value: 'Rs ${parsed.advancePaid.toStringAsFixed(0)}',
              ),
              _DetailLine(
                label: AppLang.tr(isEn, 'Remaining', 'बाकी'),
                value: 'Rs ${parsed.creditAmount.toStringAsFixed(0)}',
                strong: true,
              ),
              if (parsed.dueDate != null)
                _DetailLine(
                  label: AppLang.tr(isEn, 'Due date', 'देय तारीख'),
                  value: _formatDate(parsed.dueDate!),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          ...parsed.items.map((item) => _ItemLine(item: item)),
          if (parsed.note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              parsed.note.trim(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ] else if (entry.note.trim().isNotEmpty &&
            !entry.note.contains(SavedCreditSale.noteMarker)) ...[
          const SizedBox(height: 8),
          Text(
            entry.note,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ]),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _DetailLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
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
        Text(
          value,
          style: TextStyle(
            color: strong ? AppColors.error : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ]),
    );
  }
}

class _ItemLine extends StatelessWidget {
  final CreditSaleItem item;

  const _ItemLine({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            item.itemName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.unit}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Rs ${item.amount.toStringAsFixed(0)}',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ]),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final bool isEn;

  const _EmptyHistory({required this.isEn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        const Icon(Icons.receipt_long_outlined,
            size: 46, color: AppColors.textHint),
        const SizedBox(height: 10),
        Text(
          AppLang.tr(isEn, 'No entries yet', 'अभी कोई एंट्री नहीं है'),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }
}
