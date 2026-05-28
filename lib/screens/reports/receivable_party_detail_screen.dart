import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../widgets/credit_entry_sheet.dart';
import 'bill_image_viewer_screen.dart';

class ReceivablePartyDetailScreen extends ConsumerStatefulWidget {
  final UdharCustomerModel customer;

  const ReceivablePartyDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  ConsumerState<ReceivablePartyDetailScreen> createState() =>
      _ReceivablePartyDetailScreenState();
}

class _ReceivablePartyDetailScreenState
    extends ConsumerState<ReceivablePartyDetailScreen> {
  bool _loading = true;
  List<UdharEntryModel> _entries = [];
  Map<String, BillModel> _billsById = {};
  double _totalCredit = 0;
  double _totalReceived = 0;
  DateTime? _lastPaymentDate;
  DateTime? _oldestDueDate;

  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  final DateFormat _timeFmt = DateFormat('hh:mm a');
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final entries =
          await SupabaseService.getUdharEntriesForCustomer(widget.customer.id);

      double totalCredit = 0;
      double totalReceived = 0;
      DateTime? lastPaymentDate;
      DateTime? oldestDueDate;

      for (final entry in entries) {
        if (entry.entryType == 'credit') {
          totalCredit += entry.amount;
          if (oldestDueDate == null || entry.entryDate.isBefore(oldestDueDate)) {
            oldestDueDate = entry.entryDate;
          }
        } else {
          totalReceived += entry.amount;
          if (lastPaymentDate == null ||
              entry.entryDate.isAfter(lastPaymentDate)) {
            lastPaymentDate = entry.entryDate;
          }
        }
      }

      final billIds = entries
          .where((entry) => entry.entryType == 'credit')
          .map((entry) => SavedCreditSale.tryParseNote(entry.note)?.billId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final billsById = <String, BillModel>{};
      for (final billId in billIds) {
        final bill = await SupabaseService.getBillById(billId);
        if (bill != null) billsById[billId] = bill;
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _billsById = billsById;
          _totalCredit = totalCredit;
          _totalReceived = totalReceived;
          _lastPaymentDate = lastPaymentDate;
          _oldestDueDate = oldestDueDate;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.customer.customerName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadEntries,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCustomerHeader(isEn),
                  const SizedBox(height: 12),
                  _buildSummaryGrid(isEn),
                  const SizedBox(height: 18),
                  _buildDateStrip(isEn),
                  const SizedBox(height: 20),
                  _sectionTitle(isEn),
                  const SizedBox(height: 12),
                  if (_entries.isEmpty)
                    _buildEmptyState(isEn)
                  else
                    ..._buildTimeline(isEn),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomerHeader(bool isEn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning,
            AppColors.warning.withOpacity(0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              widget.customer.customerName.isNotEmpty
                  ? widget.customer.customerName[0].toUpperCase()
                  : '?',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.customer.customerName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.customer.customerPhone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(children: [
                    Icon(Icons.phone_rounded,
                        size: 13, color: Colors.white.withOpacity(0.75)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.customer.customerPhone,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            _currency.format(widget.customer.totalDue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            AppLang.tr(isEn, 'Receivable', 'प्राप्तव्य'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildSummaryGrid(bool isEn) {
    return Row(children: [
      Expanded(
        child: _summaryTile(
          AppLang.tr(isEn, 'Credit Given', 'उधार दिया'),
          _currency.format(_totalCredit),
          Icons.trending_up_rounded,
          AppColors.warning,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _summaryTile(
          AppLang.tr(isEn, 'Received', 'प्राप्त'),
          _currency.format(_totalReceived),
          Icons.check_circle_rounded,
          AppColors.success,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _summaryTile(
          AppLang.tr(isEn, 'Balance', 'बाकी'),
          _currency.format(widget.customer.totalDue),
          Icons.account_balance_wallet_rounded,
          AppColors.error,
        ),
      ),
    ]);
  }

  Widget _summaryTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: _dateInfo(
            AppLang.tr(isEn, 'Oldest Due', 'सबसे पुराना बाकी'),
            _oldestDueDate == null ? '-' : _dateFmt.format(_oldestDueDate!),
            Icons.event_note_rounded,
            AppColors.warning,
          ),
        ),
        Container(width: 1, height: 42, color: AppColors.border),
        Expanded(
          child: _dateInfo(
            AppLang.tr(isEn, 'Last Payment', 'आखिरी भुगतान'),
            _lastPaymentDate == null ? '-' : _dateFmt.format(_lastPaymentDate!),
            Icons.payments_rounded,
            AppColors.success,
          ),
        ),
      ]),
    );
  }

  Widget _dateInfo(String label, String value, IconData icon, Color color) {
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _sectionTitle(bool isEn) {
    return Row(children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        AppLang.tr(isEn, 'Payment Timeline', 'भुगतान टाइमलाइन'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_entries.length}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.warning,
          ),
        ),
      ),
    ]);
  }

  Widget _buildEmptyState(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        Icon(Icons.receipt_long_rounded,
            size: 56, color: AppColors.textHint.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text(
          AppLang.tr(isEn, 'No receivable entries found',
              'कोई प्राप्तव्य एंट्री नहीं मिली'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildTimeline(bool isEn) {
    double runningBalance = 0;
    final ascending = _entries.toList()
      ..sort((a, b) {
        final dateCompare = a.entryDate.compareTo(b.entryDate);
        if (dateCompare != 0) return dateCompare;
        return a.createdAt.compareTo(b.createdAt);
      });
    final balancesById = <String, double>{};
    for (final entry in ascending) {
      runningBalance +=
          entry.entryType == 'credit' ? entry.amount : -entry.amount;
      runningBalance = runningBalance.clamp(0, double.infinity).toDouble();
      balancesById[entry.id] = runningBalance;
    }

    return _entries
        .asMap()
        .entries
        .map((item) => _buildEntryCard(
              item.value,
              item.key,
              balancesById[item.value.id] ?? 0,
              isEn,
            ))
        .toList();
  }

  Widget _buildEntryCard(
    UdharEntryModel entry,
    int index,
    double balanceAfter,
    bool isEn,
  ) {
    final isCredit = entry.entryType == 'credit';
    final meta = UdharPaymentMeta.tryParseNote(entry.note);
    final creditMeta = SavedCreditSale.tryParseNote(entry.note);
    final bill = creditMeta?.billId == null ? null : _billsById[creditMeta!.billId!];
    final color = isCredit ? AppColors.warning : AppColors.success;
    final title = isCredit
        ? AppLang.tr(isEn, 'Credit Sale', 'उधार बिक्री')
        : AppLang.tr(isEn, 'Payment Received', 'भुगतान प्राप्त');
    final subtitle = isCredit
        ? AppLang.tr(isEn, 'Amount added to balance', 'राशि बाकी में जोड़ी गई')
        : _paymentMethodLabel(meta?.paymentMethod ?? 'cash', isEn);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCredit
                    ? Icons.shopping_bag_rounded
                    : Icons.payments_rounded,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${isCredit ? '+' : '-'}${_currency.format(entry.amount)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                _dateFmt.format(entry.entryDate),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 11),
          child: Row(children: [
            _smallBadge(
              _timeFmt.format(entry.createdAt),
              Icons.schedule_rounded,
              AppColors.primary,
            ),
            if (!isCredit) ...[
              const SizedBox(width: 7),
              _smallBadge(
                meta?.isPartial == true
                    ? AppLang.tr(isEn, 'Partial', 'आंशिक')
                    : AppLang.tr(isEn, 'Payment', 'भुगतान'),
                Icons.done_rounded,
                AppColors.success,
              ),
            ],
            const Spacer(),
            if (bill?.imageUrl.isNotEmpty == true) ...[
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BillImageViewerScreen(
                      imageUrl: bill!.imageUrl,
                      title: AppLang.tr(isEn, 'Bill Image', 'Bill Image'),
                      isEn: isEn,
                    ),
                  ),
                ),
                icon: const Icon(Icons.image_rounded, size: 14),
                label: Text(AppLang.tr(isEn, 'Show Bill', 'Show Bill')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primaryBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '${AppLang.tr(isEn, 'Balance', 'बाकी')}: ${_currency.format(balanceAfter)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ]),
        ),
        if (entry.note.isNotEmpty && meta == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _smallBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }

  String _paymentMethodLabel(String method, bool isEn) {
    switch (method.toLowerCase()) {
      case 'upi':
        return 'UPI';
      case 'bank':
        return AppLang.tr(isEn, 'Bank transfer', 'बैंक ट्रांसफर');
      case 'card':
        return AppLang.tr(isEn, 'Card payment', 'कार्ड भुगतान');
      default:
        return AppLang.tr(isEn, 'Cash payment', 'नकद भुगतान');
    }
  }
}
