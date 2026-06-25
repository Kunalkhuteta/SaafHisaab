import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../models/item_master_model.dart';
import '../../models/sale_model.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import 'package:saafhisaab/utils/indian_date_time.dart';


class PurchaseReturnScreen extends ConsumerStatefulWidget {
  final BillModel? initialBill;

  const PurchaseReturnScreen({super.key, this.initialBill});

  @override
  ConsumerState<PurchaseReturnScreen> createState() => _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends ConsumerState<PurchaseReturnScreen> {
  final _partyCtrl = TextEditingController();
  final _manualItemCtrl = TextEditingController();
  final _manualQtyCtrl = TextEditingController(text: '1');
  final _manualPriceCtrl = TextEditingController(text: '0');
  final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);
  final _dateTimeFmt = DateFormat('dd MMM yyyy, h:mm a');

  bool _loadingParties = false;
  bool _loadingBills = false;
  bool _saving = false;
  String _filter = 'today';
  _ReturnParty? _selectedParty;
  List<_ReturnParty> _parties = [];
  List<_PurchaseBundle> _purchases = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBill;
    if (initial != null) {
      _partyCtrl.text = initial.vendorName;
      _selectedParty = _ReturnParty(name: initial.vendorName);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _searchParties(_partyCtrl.text);
      if (_selectedParty != null) await _loadPurchases();
    });
  }

  @override
  void dispose() {
    _partyCtrl.dispose();
    _manualItemCtrl.dispose();
    _manualQtyCtrl.dispose();
    _manualPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchParties(String query) async {
    setState(() => _loadingParties = true);
    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) return;
      
      final dbParties = await SupabaseService.searchPurchaseParties(shop.id, query);

      final merged = <String, _ReturnParty>{};
      for (final party in dbParties) {
        final name = party['name'] as String? ?? '';
        final phone = party['phone_number'] as String? ?? '';
        final pending = (party['pending_amount'] as num?)?.toDouble() ?? 0.0;
        final key = '${name.toLowerCase()}|$phone';
        merged[key] = _ReturnParty(
          name: name,
          phone: phone,
          pendingAmount: pending,
          dbParty: party,
          source: _PartySource.db,
        );
      }
      
      if (mounted) setState(() => _parties = merged.values.toList());
    } catch (e) {
      final isEn = ref.read(appLanguageProvider);
      _showError(AppLang.tr(
        isEn,
        'Party search failed: $e',
        'पार्टी खोजने में समस्या हुई: $e',
      ));
    } finally {
      if (mounted) setState(() => _loadingParties = false);
    }
  }

  Future<void> _loadPurchases() async {
    final partyName = (_selectedParty?.name ?? _partyCtrl.text).trim();
    if (partyName.isEmpty) return;
    setState(() => _loadingBills = true);
    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) return;
      
      // Get purchase bills for party
      final bills = await SupabaseService.getPurchaseBillsForParty(
        shop.id,
        partyName,
      );
      
      // Filter bills by date range if applicable
      final range = _dateRangeForFilter(_filter);
      final filteredBills = bills.where((b) {
        if (range == null) return true;
        return b.billDate.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
            b.billDate.isBefore(range.end.add(const Duration(seconds: 1)));
      }).toList();

      final bundles = <_PurchaseBundle>[];
      for (final bill in filteredBills) {
        final sales = await SupabaseService.getSalesByBillId(bill.id);
        final returns = await SupabaseService.getReturnSalesForBill(bill.id);
        bundles.add(_PurchaseBundle(
          bill: bill,
          sales: sales,
          returnedSales: returns,
          isHighlighted: bill.id == widget.initialBill?.id,
        ));
      }
      if (mounted) setState(() => _purchases = bundles);
    } catch (e) {
      final isEn = ref.read(appLanguageProvider);
      _showError(AppLang.tr(
        isEn,
        'Purchase history failed: $e',
        'खरीद इतिहास लोड नहीं हुआ: $e',
      ));
    } finally {
      if (mounted) setState(() => _loadingBills = false);
    }
  }

  DateTimeRange? _dateRangeForFilter(String filter) {
    final now = IndianDateTime.now();
    final today = IndianDateTime.date(now.year, now.month, now.day);
    switch (filter) {
      case 'today':
        return DateTimeRange(start: today, end: now);
      case 'yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: yesterday,
          end: IndianDateTime.date(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
        );
      case 'week':
        return DateTimeRange(
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: now,
        );
      case 'month':
        return DateTimeRange(start: IndianDateTime.date(now.year, now.month, 1), end: now);
      case 'prev_month':
        final start = IndianDateTime.date(now.year, now.month - 1, 1);
        return DateTimeRange(
          start: start,
          end: IndianDateTime.date(now.year, now.month, 0, 23, 59, 59),
        );
      case 'year':
        return DateTimeRange(start: IndianDateTime.date(now.year, 1, 1), end: now);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'Purchase Return', 'खरीद वापसी')),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.purple,
        onRefresh: _loadPurchases,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _partySearchCard(isEn),
            const SizedBox(height: 14),
            if (_selectedParty != null || _partyCtrl.text.trim().isNotEmpty) ...[
              _filterStrip(isEn),
              const SizedBox(height: 12),
              _historyHeader(isEn),
              const SizedBox(height: 10),
              if (_loadingBills)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.purple),
                  ),
                )
              else if (_purchases.isEmpty)
                _emptyPurchaseState(isEn)
              else
                ..._purchases.map((bundle) => _purchaseCard(bundle, isEn)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _partySearchCard(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          AppLang.tr(isEn, 'Supplier / Party', 'आपूर्तिकर्ता / पार्टी'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _partyCtrl,
          onChanged: (value) {
            _selectedParty = null;
            _searchParties(value);
          },
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isEmpty) return;
            setState(() => _selectedParty = _ReturnParty(name: name));
            _loadPurchases();
          },
          decoration: InputDecoration(
            hintText: AppLang.tr(
              isEn,
              'Search party name',
              'पार्टी का नाम खोजें',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _loadingParties
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: () {
                      final name = _partyCtrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() => _selectedParty = _ReturnParty(name: name));
                      _loadPurchases();
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderBlue),
            ),
          ),
        ),
        if (_parties.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._parties.take(5).map((party) => _partyOption(party, isEn)),
        ],
      ]),
    );
  }

  Widget _partyOption(_ReturnParty party, bool isEn) {
    return InkWell(
      onTap: () {
        _partyCtrl.text = party.name;
        setState(() => _selectedParty = party);
        _loadPurchases();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.purple.withOpacity(0.1),
            child: Icon(
              Icons.business_rounded,
              size: 17,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                party.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                party.phone.isNotEmpty
                    ? '${party.phone}  |  ${_currency.format(party.pendingAmount)} ${AppLang.tr(isEn, 'pending', 'बकाया')}'
                    : '${_currency.format(party.pendingAmount)} ${AppLang.tr(isEn, 'pending', 'बकाया')}',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ]),
      ),
    );
  }

  Widget _filterStrip(bool isEn) {
    final filters = [
      ('today', AppLang.tr(isEn, 'Today', 'आज')),
      ('yesterday', AppLang.tr(isEn, 'Yesterday', 'कल')),
      ('week', AppLang.tr(isEn, 'This Week', 'यह सप्ताह')),
      ('month', AppLang.tr(isEn, 'Month', 'महीना')),
      ('prev_month', AppLang.tr(isEn, 'Prev Month', 'पिछला महीना')),
      ('year', AppLang.tr(isEn, 'Year', 'साल')),
      ('all', AppLang.tr(isEn, 'All Time', 'सभी')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final selected = _filter == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text(item.$2),
              selectedColor: AppColors.purple.withOpacity(0.16),
              labelStyle: TextStyle(
                color: selected ? AppColors.purple : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selected ? AppColors.purple : AppColors.border,
              ),
              onSelected: (_) {
                setState(() => _filter = item.$1);
                _loadPurchases();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _historyHeader(bool isEn) {
    return Row(children: [
      Expanded(
        child: Text(
          AppLang.tr(
            isEn,
            '${_purchases.length} purchases found',
            '${_purchases.length} खरीद मिली',
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      TextButton.icon(
        onPressed: () => _showFreshReturnSheet(isEn),
        icon: const Icon(Icons.edit_note_rounded, size: 18),
        label: Text(AppLang.tr(isEn, 'Without bill', 'बिना बिल')),
        style: TextButton.styleFrom(foregroundColor: AppColors.purple),
      ),
    ]);
  }

  Widget _emptyPurchaseState(bool isEn) {
    final partyName = (_selectedParty?.name ?? _partyCtrl.text).trim();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        const Icon(Icons.receipt_long_rounded, color: AppColors.textHint, size: 42),
        const SizedBox(height: 10),
        Text(
          AppLang.tr(
            isEn,
            'No purchase found for $partyName in this date range.',
            'इस तारीख में $partyName की कोई खरीद नहीं मिली।',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _showFreshReturnSheet(isEn),
          icon: const Icon(Icons.assignment_return_rounded),
          label: Text(AppLang.tr(isEn, 'Return without bill', 'बिना बिल वापसी')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purple,
            foregroundColor: Colors.white,
          ),
        ),
      ]),
    );
  }

  Widget _purchaseCard(_PurchaseBundle bundle, bool isEn) {
    final bill = bundle.bill;
    final fullyReturned = bundle.remainingTotal <= 0 && bundle.sales.isNotEmpty;
    final adjustmentRecorded = bundle.hasAdjustmentReturn;
    final partial = bundle.returnedSales.isNotEmpty && !fullyReturned;
    final paymentMode = bundle.paymentMode;
    final color = fullyReturned
        ? AppColors.textHint
        : partial
            ? AppColors.purple
            : AppColors.primary;

    return InkWell(
      onTap: (fullyReturned || adjustmentRecorded)
          ? null
          : () => _showReturnSheet(bundle, isEn),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fullyReturned ? AppColors.background : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: bundle.isHighlighted ? AppColors.purple : AppColors.border,
            width: bundle.isHighlighted ? 1.4 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                _dateTimeFmt.format(bill.billDate),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _badge(_paymentLabel(paymentMode, isEn), color),
          ]),
          const SizedBox(height: 4),
          Text(
            '#${bill.id.length > 8 ? bill.id.substring(bill.id.length - 8).toUpperCase() : bill.id}',
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...bundle.sales.take(3).map((sale) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _saleLineText(sale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )),
          if (bundle.sales.length > 3)
            Text(
              AppLang.tr(
                isEn,
                '+${bundle.sales.length - 3} more items',
                '+${bundle.sales.length - 3} और आइटम',
              ),
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          const Divider(height: 18, color: AppColors.border),
          Row(children: [
            Expanded(
              child: Text(
                '${AppLang.tr(isEn, 'Total', 'कुल')}: ${_currency.format(bill.amount)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (adjustmentRecorded)
              _badge(AppLang.tr(isEn, 'Adjusted for next bill', 'अगले बिल में समायोजन'), AppColors.primary)
            else if (fullyReturned)
              _badge(AppLang.tr(isEn, 'Fully returned', 'पूरी वापसी हो चुकी'), color)
            else if (partial)
              _badge(AppLang.tr(isEn, 'Partial return', 'आंशिक वापसी'), color)
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  AppLang.tr(isEn, 'Return', 'वापसी'),
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.purple),
              ]),
          ]),
          if (paymentMode == 'credit' || paymentMode == 'split') ...[
            const SizedBox(height: 8),
            Text(
              '${AppLang.tr(isEn, 'Supplier pending', 'आपूर्तिकर्ता बकाया')}: ${_currency.format(bundle.remainingCreditAmount)}',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ]),
      ),
    );
  }

  String _saleLineText(SaleModel sale) {
    final qty = _formatQty(sale.quantity);
    return '${sale.itemName} x $qty ${sale.unit} @ ${_currency.format(sale.sellingPrice)} = ${_currency.format(sale.totalAmount)}';
  }

  String _formatQty(double qty) =>
      qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2);

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _showReturnSheet(_PurchaseBundle bundle, bool isEn) async {
    final items = bundle.returnableLines
        .map((line) => _ReturnLineDraft(line: line))
        .toList();

    double currentPending = 0.0;
    if (_selectedParty != null) {
      currentPending = _selectedParty!.pendingAmount;
    } else {
      final dbParty = await SupabaseService.findPurchasePartyByName(bundle.bill.shopId, bundle.bill.vendorName);
      if (dbParty != null) {
        currentPending = (dbParty['pending_amount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final total = items.fold<double>(0, (sum, item) => sum + item.amount);

        final billCreditLeft = bundle.remainingCreditAmount;
        final pendingAvailableForThisBill =
            billCreditLeft.clamp(0.0, currentPending).toDouble();
        final udharReduction = total.clamp(0.0, pendingAvailableForThisBill);
        final paidReturnAmount = (total - udharReduction).clamp(0.0, double.infinity);

        final showSaveSalesReturnOnly = (bundle.paymentMode == 'credit' || bundle.paymentMode == 'split') && paidReturnAmount <= 0;

        final origMode = bundle.paymentMode.toLowerCase();
        final isUpi = origMode == 'upi';
        final isCard = origMode == 'card';
        final refundMode = isUpi ? 'upi' : (isCard ? 'card' : 'cash');
        final refundLabel = isUpi
            ? AppLang.tr(isEn, 'Refund ${_currency.format(paidReturnAmount)} UPI', '${_currency.format(paidReturnAmount)} UPI वापस करें')
            : (isCard
                ? AppLang.tr(isEn, 'Refund ${_currency.format(paidReturnAmount)} Card', '${_currency.format(paidReturnAmount)} कार्ड वापस करें')
                : AppLang.tr(isEn, 'Refund ${_currency.format(paidReturnAmount)} Cash', '${_currency.format(paidReturnAmount)} नकद वापस करें'));

        return _sheetFrame(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(),
            _sheetTitle(
              '${bundle.bill.vendorName}  |  ${_currency.format(bundle.bill.amount)}',
              _dateTimeFmt.format(bundle.bill.billDate),
            ),
            const SizedBox(height: 12),
            ...items.map((draft) => _returnQtyRow(
                  draft,
                  isEn,
                  onChanged: () => setSheetState(() {}),
                )),
            const Divider(height: 22, color: AppColors.border),
            _totalRow(AppLang.tr(isEn, 'Return Amount', 'वापसी राशि'), total),
            const SizedBox(height: 14),
            if (showSaveSalesReturnOnly) ...[
              if (udharReduction > 0) ...[
                _infoBox(
                  AppLang.tr(
                    isEn,
                    'Outstanding balance will reduce by ${_currency.format(udharReduction)}.',
                    'बकाया राशि ${_currency.format(udharReduction)} कम हो जाएगी।',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: total <= 0 || _saving
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _saveReturn(
                            sourceBill: bundle.bill,
                            drafts: items,
                            settlement: _ReturnSettlement.reduceUdhar,
                            paymentMode: 'credit',
                            isEn: isEn,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    AppLang.tr(isEn, 'Save Purchase Return', 'खरीद वापसी सहेजें'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              _infoBox(
                AppLang.tr(
                  isEn,
                  udharReduction > 0
                      ? 'Supplier pending ${_currency.format(udharReduction)} will be reduced. Cash refund: ${_currency.format(paidReturnAmount)}.'
                      : 'Cash refund: ${_currency.format(paidReturnAmount)}.',
                  udharReduction > 0
                      ? 'बकाया ${_currency.format(udharReduction)} कम होगा। नकद वापसी: ${_currency.format(paidReturnAmount)}।'
                      : 'नकद वापसी: ${_currency.format(paidReturnAmount)}।',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: total <= 0 || _saving
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _saveReturn(
                            sourceBill: bundle.bill,
                            drafts: items,
                            settlement: _ReturnSettlement.cashRefund,
                            paymentMode: refundMode,
                            isEn: isEn,
                          );
                        },
                  icon: const Icon(Icons.currency_rupee_rounded),
                  label: Text(refundLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: total <= 0 || _saving
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _saveReturn(
                            sourceBill: bundle.bill,
                            drafts: items,
                            settlement: _ReturnSettlement.adjustment,
                            paymentMode: 'adjustment',
                            isEn: isEn,
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(AppLang.tr(isEn, 'Adjust in Next Bill', 'अगले बिल में समायोजित')),
                ),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLang.tr(isEn, 'Cancel', 'रद्द करें')),
            ),
          ]),
        );
      }),
    );
  }

  Widget _returnQtyRow(
    _ReturnLineDraft draft,
    bool isEn, {
    required VoidCallback onChanged,
  }) {
    final line = draft.line;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              line.sale.itemName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${AppLang.tr(isEn, 'Left', 'बाकी')}: ${_formatQty(line.remainingQty)} ${line.sale.unit} @ ${_currency.format(line.sale.sellingPrice)}',
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 88,
          child: TextField(
            controller: draft.qtyCtrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) {
              final value = draft.qty;
              if (value > line.remainingQty) {
                draft.qtyCtrl.text = _formatQty(line.remainingQty);
                draft.qtyCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: draft.qtyCtrl.text.length),
                );
              }
              onChanged();
            },
            decoration: InputDecoration(
              hintText: '0',
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderBlue),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _showFreshReturnSheet(bool isEn) async {
    _manualItemCtrl.clear();
    _manualQtyCtrl.text = '1';
    _manualPriceCtrl.text = '0';
    
    double currentPending = 0.0;
    if (_selectedParty != null) {
      currentPending = _selectedParty!.pendingAmount;
    } else {
      final shop = await ref.read(shopProvider.future);
      if (shop != null) {
        final dbParty = await SupabaseService.findPurchasePartyByName(
          shop.id,
          _partyCtrl.text.trim(),
        );
        if (dbParty != null) {
          currentPending = (dbParty['pending_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final qty = double.tryParse(_manualQtyCtrl.text) ?? 0;
        final price = double.tryParse(_manualPriceCtrl.text) ?? 0;
        final total = qty * price;
        
        final udharReduction = total.clamp(0.0, currentPending);
        final paidReturnAmount = (total - udharReduction).clamp(0.0, double.infinity);

        return _sheetFrame(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(),
            _sheetTitle(
              AppLang.tr(isEn, 'Return without bill', 'बिना बिल वापसी'),
              (_selectedParty?.name ?? _partyCtrl.text).trim(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualItemCtrl,
              decoration: _inputDecoration(AppLang.tr(isEn, 'Item name', 'आइटम का नाम')),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _manualQtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => setSheetState(() {}),
                  decoration: _inputDecoration(AppLang.tr(isEn, 'Qty', 'मात्रा')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _manualPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => setSheetState(() {}),
                  decoration: _inputDecoration(AppLang.tr(isEn, 'Price', 'मूल्य')),
                ),
              ),
            ]),
            const Divider(height: 24, color: AppColors.border),
            _totalRow(AppLang.tr(isEn, 'Return Amount', 'वापसी राशि'), total),
            const SizedBox(height: 14),
            _infoBox(
              AppLang.tr(
                isEn,
                currentPending > 0
                    ? 'Supplier pending ${_currency.format(udharReduction)} will be reduced. Cash refund: ${_currency.format(paidReturnAmount)}.'
                    : 'Cash refund: ${_currency.format(paidReturnAmount)}.',
                currentPending > 0
                    ? 'बकाया ${_currency.format(udharReduction)} कम होगा। नकद वापसी: ${_currency.format(paidReturnAmount)}।'
                    : 'नकद वापसी: ${_currency.format(paidReturnAmount)}।',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: total <= 0 || _manualItemCtrl.text.trim().isEmpty || _saving
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _saveReturn(
                          sourceBill: null,
                          drafts: [
                            _ReturnLineDraft(
                              line: _ReturnableLine(
                                SaleModel(
                                  id: '',
                                  shopId: '',
                                  userId: '',
                                  itemName: _manualItemCtrl.text.trim(),
                                  quantity: qty,
                                  unit: 'piece',
                                  sellingPrice: price,
                                  totalAmount: total,
                                  paymentMode: 'cash',
                                  saleDate: IndianDateTime.now(),
                                  notes: '',
                                  createdAt: IndianDateTime.now(),
                                ),
                                qty,
                              ),
                            )..qtyCtrl.text = qty.toString()
                          ],
                          settlement: _ReturnSettlement.cashRefund,
                          paymentMode: 'cash',
                          isEn: isEn,
                        );
                      },
                icon: const Icon(Icons.currency_rupee_rounded),
                label: Text(
                  AppLang.tr(
                    isEn,
                    'Refund ${_currency.format(paidReturnAmount)} Cash',
                    '${_currency.format(paidReturnAmount)} नकद वापस करें',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: total <= 0 || _manualItemCtrl.text.trim().isEmpty || _saving
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _saveReturn(
                          sourceBill: null,
                          drafts: [
                            _ReturnLineDraft(
                              line: _ReturnableLine(
                                SaleModel(
                                  id: '',
                                  shopId: '',
                                  userId: '',
                                  itemName: _manualItemCtrl.text.trim(),
                                  quantity: qty,
                                  unit: 'piece',
                                  sellingPrice: price,
                                  totalAmount: total,
                                  paymentMode: 'adjustment',
                                  saleDate: IndianDateTime.now(),
                                  notes: '',
                                  createdAt: IndianDateTime.now(),
                                ),
                                qty,
                              ),
                            )..qtyCtrl.text = qty.toString()
                          ],
                          settlement: _ReturnSettlement.adjustment,
                          paymentMode: 'adjustment',
                          isEn: isEn,
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(AppLang.tr(isEn, 'Adjust in Next Bill', 'अगले बिल में समायोजित')),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLang.tr(isEn, 'Cancel', 'रद्द करें')),
            ),
          ]),
        );
      }),
    );
  }

  Future<void> _saveReturn({
    required BillModel? sourceBill,
    required List<_ReturnLineDraft> drafts,
    required _ReturnSettlement settlement,
    required String paymentMode,
    required bool isEn,
  }) async {
    if (_saving) return;
    final selected = drafts.where((d) => d.qty > 0).toList();
    if (selected.isEmpty) return;

    setState(() => _saving = true);
    String? billId;
    final List<_StockRollback> stockAddedIds = [];

    try {
      final shop = await ref.read(shopProvider.future);
      final userId = AuthService.currentUserId;
      if (shop == null || userId == null) throw Exception('Auth / Shop context missing');

      final partyName = (_selectedParty?.name ?? _partyCtrl.text).trim();
      final total = selected.fold<double>(0, (sum, d) => sum + d.amount);

      // Calculate how much of this bill's unpaid amount is being reversed vs refunded.
      double currentPending = 0.0;
      if (settlement == _ReturnSettlement.cashRefund ||
          settlement == _ReturnSettlement.reduceUdhar) {
        if (_selectedParty != null) {
          currentPending = _selectedParty!.pendingAmount;
        } else {
          final dbParty = await SupabaseService.findPurchasePartyByName(shop.id, partyName);
          if (dbParty != null) {
            currentPending = (dbParty['pending_amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
      final billCreditLeft = await _remainingCreditForSourceBill(
        sourceBill: sourceBill,
        selectedDrafts: selected,
      );
      final pendingAvailableForThisBill =
          billCreditLeft.clamp(0.0, currentPending).toDouble();
      final udharReduction =
          (settlement == _ReturnSettlement.cashRefund ||
                  settlement == _ReturnSettlement.reduceUdhar)
              ? total.clamp(0.0, pendingAvailableForThisBill)
              : 0.0;
      final paidReturnAmount = (total - udharReduction).clamp(0.0, double.infinity);

      // Determine effective payment mode for daily balance accuracy
      String effectivePaymentMode;
      if (settlement == _ReturnSettlement.cashRefund && udharReduction > 0 && paidReturnAmount > 0) {
        effectivePaymentMode = 'split';
      } else if (settlement == _ReturnSettlement.cashRefund && udharReduction > 0 && paidReturnAmount <= 0) {
        effectivePaymentMode = 'credit';
      } else {
        effectivePaymentMode = paymentMode;
      }

      final noteLines = [
        '__saafhisaab_return_ref:${sourceBill?.id ?? 'none'}__',
        'settlement: ${settlement.name}',
        if (settlement == _ReturnSettlement.adjustment)
          SupabaseService.saleAdjustmentNote(
            adjustedAmount: total,
            grossAmount: total,
            paidAmount: 0,
            remainingAdjustment: total,
          ),
        // Embed credit_advance marker so daily balance sync can parse the split correctly
        if (effectivePaymentMode == 'split')
          '__saafhisaab_credit_advance:${paidReturnAmount.toStringAsFixed(2)};credit:${udharReduction.toStringAsFixed(2)}__',
      ];
      final note = noteLines.join('\n');

      billId = await SupabaseService.saveBillGetId(BillModel(
        id: '',
        shopId: shop.id,
        userId: userId,
        amount: total,
        billDate: IndianDateTime.now(),
        vendorName: partyName,
        billType: 'purchase_return',
        notes: note,
        createdAt: IndianDateTime.now(),
      ));

      for (final draft in selected) {
        final sale = draft.line.sale;
        String? stockItemId = sale.stockItemId;
        if (stockItemId == null || stockItemId.isEmpty) {
          // Find or create item master
          final items = await SupabaseService.getMasterItems(shop.id);
          final existing = items.firstWhere(
            (i) => i.itemName.toLowerCase() == sale.itemName.toLowerCase(),
            orElse: () => ItemMasterModel(
              id: '',
              shopId: '',
              userId: '',
              itemName: '',
              currentStock: 0,
              createdAt: IndianDateTime.now(),
            ),
          );
          if (existing.id.isNotEmpty) {
            stockItemId = existing.id;
          }
        }

        if (stockItemId != null && stockItemId.isNotEmpty) {
          final ok = await SupabaseService.deductMasterStockById(stockItemId, draft.qty);
          if (!ok) {
            throw Exception(AppLang.tr(
              isEn,
              'Stock update failed for ${sale.itemName}. Insufficient stock.',
              '${sale.itemName} का स्टॉक कम करने में विफल। पर्याप्त स्टॉक नहीं है।',
            ));
          }
          stockAddedIds.add(_StockRollback(stockItemId, draft.qty));
        }

        await SupabaseService.saveSale(SaleModel(
          id: '',
          shopId: shop.id,
          userId: userId,
          itemName: sale.itemName,
          quantity: -draft.qty,
          unit: sale.unit,
          sellingPrice: sale.sellingPrice,
          totalAmount: -draft.amount,
          paymentMode: effectivePaymentMode,
          billId: billId,
          stockItemId: stockItemId,
          saleDate: IndianDateTime.now(),
          notes: note,
          createdAt: IndianDateTime.now(),
        ));
      }

      await _applyReturnSettlement(
        shopId: shop.id,
        userId: userId,
        partyName: partyName,
        amount: total,
        udharReduction: udharReduction,
        settlement: settlement,
        sourceBill: sourceBill,
      );

      try {
        await SupabaseService.syncAndGetDailyBalances(
          shop.id,
          IndianDateTime.now().month,
          IndianDateTime.now().year,
        );
      } catch (e) {
        debugPrint('Daily balance sync failed: $e');
      }

      ref.invalidate(todayBillsProvider);
      ref.invalidate(filteredBillsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(itemMasterProvider);
      ref.invalidate(stockItemsProvider);
      ref.invalidate(purchasePartiesProvider);

      await _searchParties(partyName);
      await _loadPurchases();

      if (mounted) {
        String snackMessage;
        if (settlement == _ReturnSettlement.adjustment) {
          snackMessage = AppLang.tr(
            isEn,
            'Return noted. ${_currency.format(total)} will adjust in the next purchase.',
            'वापसी दर्ज हो गई। ${_currency.format(total)} अगली खरीद में समायोजित होगा।',
          );
        } else if (settlement == _ReturnSettlement.reduceUdhar) {
          snackMessage = AppLang.tr(
            isEn,
            'Supplier pending balance reduced by ${_currency.format(total)}. Stock updated.',
            'आपूर्तिकर्ता की बकाया राशि ${_currency.format(total)} कम हुई। स्टॉक अपडेट हो गया।',
          );
        } else {
          snackMessage = AppLang.tr(
            isEn,
            '${_currency.format(total)} refunded from supplier. Stock updated.',
            'आपूर्तिकर्ता से ${_currency.format(total)} वापस मिले। स्टॉक अपडेट हो गया।',
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackMessage),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (billId != null && billId.isNotEmpty) {
        await SupabaseService.deleteSalesByBillId(billId);
        await SupabaseService.deleteBill(billId);
      }
      for (final rollback in stockAddedIds.reversed) {
        await SupabaseService.addMasterStockById(
          rollback.stockItemId,
          rollback.quantity,
        );
      }
      _showError(AppLang.tr(
        isEn,
        'Return save failed: $e',
        'वापसी सेव नहीं हुई: $e',
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyReturnSettlement({
    required String shopId,
    required String userId,
    required String partyName,
    required double amount,
    required double udharReduction,
    required _ReturnSettlement settlement,
    required BillModel? sourceBill,
  }) async {
    var party = _selectedParty?.dbParty ??
        await SupabaseService.findPurchasePartyByName(shopId, partyName);
    
    if (party == null) {
      party = await SupabaseService.createPurchaseParty(
        shopId: shopId,
        userId: userId,
        name: partyName,
      );
    }
    
    final partyId = party['id'] as String;

    if (settlement == _ReturnSettlement.reduceUdhar ||
        settlement == _ReturnSettlement.cashRefund) {
      final currentPending = await SupabaseService.getPurchasePartyPendingAmount(partyId);
      final reduceBy = udharReduction.clamp(0, currentPending).toDouble();
      if (reduceBy > 0) {
        await SupabaseService.updatePurchasePartyPendingAmount(partyId, currentPending - reduceBy);
      }
    } else if (settlement == _ReturnSettlement.adjustment) {
      await SupabaseService.addPurchasePartyAdjustmentAmount(partyId, amount);
    }
  }

  Future<double> _remainingCreditForSourceBill({
    required BillModel? sourceBill,
    required List<_ReturnLineDraft> selectedDrafts,
  }) async {
    if (selectedDrafts.isEmpty) return 0.0;
    if (sourceBill == null) return double.infinity;

    final paymentMode = selectedDrafts.first.line.sale.paymentMode.toLowerCase();
    if (paymentMode != 'credit' && paymentMode != 'split') return 0.0;

    final originalCredit = _PurchaseBundle.creditAmountFromSales(
      selectedDrafts.map((draft) => draft.line.sale).toList(),
      sourceBill.amount,
    );
    if (originalCredit <= 0) return 0.0;

    final returnedSales = await SupabaseService.getReturnSalesForBill(sourceBill.id);
    final alreadyReduced =
        _PurchaseBundle.creditReducedByReturns(returnedSales);
    return (originalCredit - alreadyReduced)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  String _paymentLabel(String paymentMode, bool isEn) {
    switch (paymentMode) {
      case 'upi':
        return 'UPI';
      case 'card':
        return AppLang.tr(isEn, 'Card', 'कार्ड');
      case 'credit':
        return AppLang.tr(isEn, 'Credit', 'उधार');
      case 'split':
        return AppLang.tr(isEn, 'Split', 'स्प्लिट');
      default:
        return AppLang.tr(isEn, 'Cash', 'नकद');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  // ── Sheet Components ──

  Widget _sheetFrame({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: child,
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sheetTitle(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textHint,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]);
  }

  Widget _totalRow(String label, double val) {
    return Row(children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Text(
        _currency.format(val),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    ]);
  }

  Widget _infoBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        msg,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
    );
  }
}

// ── Helpers ──

enum _PartySource { db, typed }

class _ReturnParty {
  final String name;
  final String phone;
  final double pendingAmount;
  final _PartySource source;
  final Map<String, dynamic>? dbParty;

  const _ReturnParty({
    required this.name,
    this.phone = '',
    this.pendingAmount = 0,
    this.source = _PartySource.typed,
    this.dbParty,
  });
}

class _PurchaseBundle {
  final BillModel bill;
  final List<SaleModel> sales;
  final List<SaleModel> returnedSales;
  final bool isHighlighted;

  const _PurchaseBundle({
    required this.bill,
    required this.sales,
    required this.returnedSales,
    this.isHighlighted = false,
  });

  String get paymentMode => sales.isEmpty ? 'cash' : sales.first.paymentMode;

  double get originalCreditAmount => creditAmountFromSales(sales, bill.amount);

  double get remainingCreditAmount {
    final remaining = originalCreditAmount - creditReducedByReturns(returnedSales);
    return remaining.clamp(0.0, double.infinity).toDouble();
  }

  bool get hasAdjustmentReturn => returnedSales.any(
        (sale) => sale.notes.toLowerCase().contains('settlement: adjustment'),
      );

  List<_ReturnableLine> get returnableLines {
    return sales.map((sale) {
      final returned = returnedSales
          .where((r) =>
              r.itemName.toLowerCase() == sale.itemName.toLowerCase() &&
              (r.stockItemId == sale.stockItemId || r.stockItemId == null))
          .fold<double>(0, (sum, item) => sum + item.quantity.abs());
      return _ReturnableLine(
        sale,
        (sale.quantity - returned).clamp(0, double.infinity).toDouble(),
      );
    }).where((line) => line.remainingQty > 0).toList();
  }

  double get remainingTotal {
    return returnableLines.fold<double>(
      0,
      (sum, line) => sum + (line.remainingQty * line.sale.sellingPrice),
    );
  }

  static double creditAmountFromSales(List<SaleModel> sales, double billAmount) {
    if (sales.isEmpty) return 0.0;

    for (final sale in sales) {
      final credit = _creditFromAdvanceMarker(sale.notes);
      if (credit > 0) return credit;
    }

    final paymentMode = sales.first.paymentMode.toLowerCase();
    if (paymentMode == 'credit') return billAmount;
    return 0.0;
  }

  static double creditReducedByReturns(List<SaleModel> returnedSales) {
    return returnedSales.fold<double>(0.0, (sum, sale) {
      final markerCredit = _creditFromAdvanceMarker(sale.notes);
      if (markerCredit > 0) return sum + markerCredit;

      final paymentMode = sale.paymentMode.toLowerCase();
      if (paymentMode == 'credit') return sum + sale.totalAmount.abs();
      return sum;
    });
  }

  static double _creditFromAdvanceMarker(String notes) {
    final startMarker = '__saafhisaab_credit_advance:';
    final startIndex = notes.indexOf(startMarker);
    if (startIndex < 0) return 0.0;

    final endIndex = notes.indexOf('__', startIndex + startMarker.length);
    if (endIndex < 0) return 0.0;

    final raw = notes.substring(startIndex + startMarker.length, endIndex);
    final parts = raw.split(';credit:');
    if (parts.length != 2) return 0.0;

    return double.tryParse(parts[1]) ?? 0.0;
  }
}

class _ReturnableLine {
  final SaleModel sale;
  final double remainingQty;

  const _ReturnableLine(this.sale, this.remainingQty);
}

class _ReturnLineDraft {
  final _ReturnableLine line;
  final TextEditingController qtyCtrl = TextEditingController(text: '0');

  _ReturnLineDraft({required this.line});

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get amount => qty * line.sale.sellingPrice;
}

class _StockRollback {
  final String stockItemId;
  final double quantity;

  const _StockRollback(this.stockItemId, this.quantity);
}

enum _ReturnSettlement { adjustment, cashRefund, reduceUdhar }

