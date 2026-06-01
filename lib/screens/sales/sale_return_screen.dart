import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../models/item_master_model.dart';
import '../../models/sale_model.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/credit_entry_sheet.dart';

class SaleReturnScreen extends ConsumerStatefulWidget {
  final BillModel? initialBill;

  const SaleReturnScreen({super.key, this.initialBill});

  @override
  ConsumerState<SaleReturnScreen> createState() => _SaleReturnScreenState();
}

class _SaleReturnScreenState extends ConsumerState<SaleReturnScreen> {
  final _customerCtrl = TextEditingController();
  final _manualItemCtrl = TextEditingController();
  final _manualQtyCtrl = TextEditingController(text: '1');
  final _manualPriceCtrl = TextEditingController(text: '0');
  final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);
  final _dateTimeFmt = DateFormat('dd MMM yyyy, h:mm a');

  bool _loadingCustomers = false;
  bool _loadingBills = false;
  bool _saving = false;
  String _filter = 'today';
  _ReturnCustomer? _selectedCustomer;
  List<_ReturnCustomer> _customers = [];
  List<_PurchaseBundle> _purchases = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBill;
    if (initial != null) {
      _customerCtrl.text = initial.vendorName;
      _selectedCustomer = _ReturnCustomer(name: initial.vendorName);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _searchCustomers(_customerCtrl.text);
      if (_selectedCustomer != null) await _loadPurchases();
    });
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _manualItemCtrl.dispose();
    _manualQtyCtrl.dispose();
    _manualPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchCustomers(String query) async {
    setState(() => _loadingCustomers = true);
    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) return;
      final udhar = await SupabaseService.searchUdharCustomers(shop.id, query);
      final cash = await SupabaseService.searchSaleCustomers(shop.id, query);

      final merged = <String, _ReturnCustomer>{};
      for (final customer in udhar) {
        final key = '${customer.customerName.toLowerCase()}|${customer.customerPhone}';
        merged[key] = _ReturnCustomer(
          name: customer.customerName,
          phone: customer.customerPhone,
          totalDue: customer.totalDue,
          udharCustomer: customer,
          source: _CustomerSource.udhar,
        );
      }
      for (final row in cash) {
        final name = (row['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final alreadyExists = merged.values.any(
          (c) => c.name.toLowerCase() == name.toLowerCase(),
        );
        if (!alreadyExists) {
          merged['$name|cash'] = _ReturnCustomer(
            name: name,
            source: _CustomerSource.cash,
          );
        }
      }
      if (mounted) setState(() => _customers = merged.values.toList());
    } catch (e) {
      final isEn = ref.read(appLanguageProvider);
      _showError(AppLang.tr(
        isEn,
        'Customer search failed: $e',
        'ग्राहक खोजने में समस्या हुई: $e',
      ));
    } finally {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  Future<void> _loadPurchases() async {
    final customerName = (_selectedCustomer?.name ?? _customerCtrl.text).trim();
    if (customerName.isEmpty) return;
    setState(() => _loadingBills = true);
    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) return;
      final range = _dateRangeForFilter(_filter);
      final bills = await SupabaseService.getSaleBillsForCustomer(
        shop.id,
        customerName,
        from: range?.start,
        to: range?.end,
      );
      final bundles = <_PurchaseBundle>[];
      for (final bill in bills) {
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case 'today':
        return DateTimeRange(start: today, end: now);
      case 'yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: yesterday,
          end: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
        );
      case 'week':
        return DateTimeRange(
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: now,
        );
      case 'month':
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case 'prev_month':
        final start = DateTime(now.year, now.month - 1, 1);
        return DateTimeRange(
          start: start,
          end: DateTime(now.year, now.month, 0, 23, 59, 59),
        );
      case 'year':
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
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
        title: Text(AppLang.tr(isEn, 'Sale Return', 'बिक्री वापसी')),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.warning,
        onRefresh: _loadPurchases,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _customerSearchCard(isEn),
            const SizedBox(height: 14),
            if (_selectedCustomer != null || _customerCtrl.text.trim().isNotEmpty) ...[
              _filterStrip(isEn),
              const SizedBox(height: 12),
              _historyHeader(isEn),
              const SizedBox(height: 10),
              if (_loadingBills)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.warning),
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

  Widget _customerSearchCard(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          AppLang.tr(isEn, 'Customer', 'ग्राहक'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _customerCtrl,
          onChanged: (value) {
            _selectedCustomer = null;
            _searchCustomers(value);
          },
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isEmpty) return;
            setState(() => _selectedCustomer = _ReturnCustomer(name: name));
            _loadPurchases();
          },
          decoration: InputDecoration(
            hintText: AppLang.tr(
              isEn,
              'Search customer name',
              'ग्राहक का नाम खोजें',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _loadingCustomers
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
                      final name = _customerCtrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() => _selectedCustomer = _ReturnCustomer(name: name));
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
        if (_customers.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._customers.take(5).map((customer) => _customerOption(customer, isEn)),
        ],
      ]),
    );
  }

  Widget _customerOption(_ReturnCustomer customer, bool isEn) {
    final isUdhar = customer.source == _CustomerSource.udhar;
    return InkWell(
      onTap: () {
        _customerCtrl.text = customer.name;
        setState(() => _selectedCustomer = customer);
        _loadPurchases();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          CircleAvatar(
            radius: 17,
            backgroundColor:
                (isUdhar ? AppColors.warning : AppColors.primary).withOpacity(0.1),
            child: Icon(
              isUdhar ? Icons.account_balance_wallet_rounded : Icons.person_rounded,
              size: 17,
              color: isUdhar ? AppColors.warning : AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                customer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                customer.phone.isNotEmpty
                    ? '${customer.phone}  |  ${_currency.format(customer.totalDue)} ${AppLang.tr(isEn, 'pending', 'बकाया')}'
                    : isUdhar
                        ? '${_currency.format(customer.totalDue)} ${AppLang.tr(isEn, 'pending', 'बकाया')}'
                        : AppLang.tr(isEn, 'Cash customer', 'नकद ग्राहक'),
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
              selectedColor: AppColors.warning.withOpacity(0.16),
              labelStyle: TextStyle(
                color: selected ? AppColors.warning : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selected ? AppColors.warning : AppColors.border,
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
        style: TextButton.styleFrom(foregroundColor: AppColors.warning),
      ),
    ]);
  }

  Widget _emptyPurchaseState(bool isEn) {
    final customer = (_selectedCustomer?.name ?? _customerCtrl.text).trim();
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
            'No purchase found for $customer in this date range.',
            'इस तारीख में $customer की कोई खरीद नहीं मिली।',
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
            backgroundColor: AppColors.warning,
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
            ? AppColors.warning
            : AppColors.success;

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
            color: bundle.isHighlighted ? AppColors.warning : AppColors.border,
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
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.warning),
              ]),
          ]),
          if (paymentMode == 'credit' || paymentMode == 'split') ...[
            const SizedBox(height: 8),
            Text(
              '${AppLang.tr(isEn, 'Current pending', 'अभी बकाया')}: ${_currency.format(_selectedCustomer?.totalDue ?? 0)}',
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

    // Fetch customer and credit information to calculate the reactive plan
    final customer = _selectedCustomer?.udharCustomer ??
        await SupabaseService.findCustomerByName(bundle.bill.shopId, bundle.bill.vendorName);

    double paidAfterSale = 0.0;
    double originalCreditAmount = 0.0;
    double originalPaidAmount = bundle.bill.amount;

    if (customer != null && (bundle.paymentMode == 'credit' || bundle.paymentMode == 'split')) {
      paidAfterSale = await _paidAfterSaleForBill(
        customerId: customer.id,
        billId: bundle.bill.id,
      );
      final creditMeta = _creditMetaForBill(items, bundle.bill.id);
      originalCreditAmount = creditMeta?.creditAmount ??
          (bundle.paymentMode == 'credit' ? bundle.bill.amount : 0.0);
      originalPaidAmount =
          (bundle.bill.amount - originalCreditAmount).clamp(0, bundle.bill.amount).toDouble();
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final total = items.fold<double>(0, (sum, item) => sum + item.amount);

        final currentCreditForBill = (originalCreditAmount - paidAfterSale).clamp(0.0, double.infinity);
        final udharReduction = total.clamp(0.0, currentCreditForBill);
        final paidReturnAmount = (total - udharReduction).clamp(0.0, double.infinity);

        final showSaveSalesReturnOnly = (bundle.paymentMode == 'credit' || bundle.paymentMode == 'split') && paidReturnAmount <= 0;

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
                    'Outstanding credit will reduce by ${_currency.format(udharReduction)}.',
                    'बकाया उधार ${_currency.format(udharReduction)} कम हो जाएगा।',
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
                    AppLang.tr(isEn, 'Save Sales Return', 'बिक्री वापसी सहेजें'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              if (udharReduction > 0) ...[
                _infoBox(
                  AppLang.tr(
                    isEn,
                    'Outstanding credit will reduce by ${_currency.format(udharReduction)}. Refund to customer: ${_currency.format(paidReturnAmount)}.',
                    'बकाया उधार ${_currency.format(udharReduction)} कम होगा। ग्राहक को वापसी: ${_currency.format(paidReturnAmount)}।',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(children: [
                Expanded(
                  child: ElevatedButton(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(AppLang.tr(isEn, 'Adjust Next', 'अगली बार समायोजित')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: total <= 0 || _saving
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _showRefundSheet(bundle, items, isEn);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(AppLang.tr(isEn, 'Return Money', 'पैसे वापस करें')),
                  ),
                ),
              ]),
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

  Future<void> _showRefundSheet(
    _PurchaseBundle bundle,
    List<_ReturnLineDraft> drafts,
    bool isEn,
  ) async {
    var method = _defaultRefundMethod(bundle.paymentMode);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final total = drafts.fold<double>(0, (sum, item) => sum + item.amount);
        final options = _refundOptions(bundle.paymentMode, isEn);
        return _sheetFrame(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(),
            _sheetTitle(
              AppLang.tr(isEn, 'Refund Method', 'भुगतान वापसी तरीका'),
              _currency.format(total),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final selected = method == option.value;
                return ChoiceChip(
                  selected: selected,
                  label: Text(option.label),
                  selectedColor: AppColors.warning.withOpacity(0.16),
                  side: BorderSide(
                    color: selected ? AppColors.warning : AppColors.border,
                  ),
                  onSelected: (_) => setSheetState(() => method = option.value),
                );
              }).toList(),
            ),
            if (method == 'reduce_udhar') ...[
              const SizedBox(height: 12),
              _infoBox(
                AppLang.tr(
                  isEn,
                  '${_selectedCustomer?.name ?? bundle.bill.vendorName} credit will change from ${_currency.format(_selectedCustomer?.totalDue ?? 0)} to ${_currency.format(((_selectedCustomer?.totalDue ?? 0) - total).clamp(0, double.infinity))}.',
                  '${_selectedCustomer?.name ?? bundle.bill.vendorName} का उधार ${_currency.format(_selectedCustomer?.totalDue ?? 0)} से ${_currency.format(((_selectedCustomer?.totalDue ?? 0) - total).clamp(0, double.infinity))} हो जाएगा।',
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _saveReturn(
                          sourceBill: bundle.bill,
                          drafts: drafts,
                          settlement: method == 'reduce_udhar'
                              ? _ReturnSettlement.reduceUdhar
                              : _ReturnSettlement.cashRefund,
                          paymentMode: method,
                          isEn: isEn,
                        );
                      },
                icon: const Icon(Icons.check_rounded),
                label: Text(AppLang.tr(isEn, 'Refund Done', 'वापसी पूरी')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  List<_RefundOption> _refundOptions(String paymentMode, bool isEn) {
    switch (paymentMode) {
      case 'upi':
        return [
          _RefundOption('upi', 'UPI'),
          _RefundOption('cash', AppLang.tr(isEn, 'Cash', 'नकद')),
        ];
      case 'card':
        return [
          _RefundOption('cash', AppLang.tr(isEn, 'Cash', 'नकद')),
          _RefundOption('card_note', AppLang.tr(isEn, 'Card note', 'कार्ड नोट')),
        ];
      case 'credit':
        return [
          _RefundOption('reduce_udhar', AppLang.tr(isEn, 'Reduce Credit', 'उधार कम करें')),
          _RefundOption('cash', AppLang.tr(isEn, 'Cash Refund', 'नकद वापसी')),
        ];
      case 'split':
        return [
          _RefundOption('reduce_udhar', AppLang.tr(isEn, 'Reduce Credit', 'उधार कम करें')),
          _RefundOption('cash', AppLang.tr(isEn, 'Cash', 'नकद')),
        ];
      default:
        return [_RefundOption('cash', AppLang.tr(isEn, 'Cash', 'नकद'))];
    }
  }

  String _defaultRefundMethod(String paymentMode) {
    if (paymentMode == 'upi') return 'upi';
    if (paymentMode == 'credit' || paymentMode == 'split') return 'reduce_udhar';
    return 'cash';
  }

  Future<void> _showFreshReturnSheet(bool isEn) async {
    _manualItemCtrl.clear();
    _manualQtyCtrl.text = '1';
    _manualPriceCtrl.text = '0';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final qty = double.tryParse(_manualQtyCtrl.text) ?? 0;
        final price = double.tryParse(_manualPriceCtrl.text) ?? 0;
        final total = qty * price;
        return _sheetFrame(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(),
            _sheetTitle(
              AppLang.tr(isEn, 'Return without bill', 'बिना बिल वापसी'),
              (_selectedCustomer?.name ?? _customerCtrl.text).trim(),
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
            const SizedBox(height: 12),
            _totalRow(AppLang.tr(isEn, 'Return Amount', 'वापसी राशि'), total),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: total <= 0
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _saveFreshReturn(
                            settlement: _ReturnSettlement.adjustment,
                            paymentMode: 'adjustment',
                            isEn: isEn,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(AppLang.tr(isEn, 'Adjust Next', 'अगली बार समायोजित')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: total <= 0
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _saveFreshReturn(
                            settlement: _ReturnSettlement.cashRefund,
                            paymentMode: 'cash',
                            isEn: isEn,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(AppLang.tr(isEn, 'Cash Refund', 'नकद वापसी')),
                ),
              ),
            ]),
          ]),
        );
      }),
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

  Widget _sheetFrame({required Widget child}) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sheetTitle(String title, String subtitle) {
    return Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.assignment_return_rounded, color: AppColors.warning),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _totalRow(String label, double total) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          _currency.format(total),
          style: const TextStyle(
            color: AppColors.warning,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ]),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _saveFreshReturn({
    required _ReturnSettlement settlement,
    required String paymentMode,
    required bool isEn,
  }) async {
    final qty = double.tryParse(_manualQtyCtrl.text) ?? 0;
    final price = double.tryParse(_manualPriceCtrl.text) ?? 0;
    final itemName = _manualItemCtrl.text.trim();
    if (itemName.isEmpty || qty <= 0 || price <= 0) {
      _showError(AppLang.tr(isEn, 'Enter item, quantity and price.', 'आइटम, मात्रा और मूल्य भरें।'));
      return;
    }
    final fakeSale = SaleModel(
      id: '',
      shopId: '',
      userId: '',
      itemName: itemName,
      quantity: qty,
      unit: 'piece',
      sellingPrice: price,
      totalAmount: qty * price,
      paymentMode: paymentMode,
      saleDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _saveReturn(
      sourceBill: null,
      drafts: [_ReturnLineDraft(line: _ReturnableLine(fakeSale, qty))..qtyCtrl.text = _formatQty(qty)],
      settlement: settlement,
      paymentMode: paymentMode,
      isEn: isEn,
    );
  }

  Future<void> _saveReturn({
    required BillModel? sourceBill,
    required List<_ReturnLineDraft> drafts,
    required _ReturnSettlement settlement,
    required String paymentMode,
    required bool isEn,
  }) async {
    final selected = drafts.where((d) => d.qty > 0).toList();
    if (selected.isEmpty) {
      _showError(AppLang.tr(isEn, 'Enter return quantity.', 'वापसी मात्रा भरें।'));
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    String? billId;
    final stockAddedIds = <_StockRollback>[];
    try {
      final userId = AuthService.currentUserId;
      final shop = await ref.read(shopProvider.future);
      if (userId == null || shop == null) {
        throw Exception(AppLang.tr(isEn, 'Shop not found', 'दुकान नहीं मिली'));
      }
      final customerName = (_selectedCustomer?.name ?? _customerCtrl.text).trim();
      if (customerName.isEmpty) {
        throw Exception(AppLang.tr(isEn, 'Customer name required', 'ग्राहक का नाम जरूरी है'));
      }

      final total = selected.fold<double>(0, (sum, draft) => sum + draft.amount);
      final existingCustomer = _selectedCustomer?.udharCustomer ??
          await SupabaseService.findCustomerByName(shop.id, customerName);
      final creditPlan = await _creditReturnPlan(
        shopId: shop.id,
        customer: existingCustomer,
        sourceBill: sourceBill,
        returnAmount: total,
        selectedDrafts: selected,
      );
      final refMarker = sourceBill == null
          ? '__saafhisaab_return_ref:none__'
          : '__saafhisaab_return_ref:${sourceBill.id}__';
      final note = [
        refMarker,
        if (sourceBill == null) 'Fresh return - no reference bill',
        if (sourceBill != null) 'Sale return from bill ${sourceBill.id}',
        'Settlement: $paymentMode',
        if (paymentMode != 'adjustment' && creditPlan.reduceUdharAmount > 0)
          SupabaseService.saleAdjustmentNote(
            adjustedAmount: creditPlan.reduceUdharAmount,
            grossAmount: total,
            paidAmount: creditPlan.customerPaidReturnAmount,
            remainingAdjustment: 0,
          ),
      ].join('\n');

      billId = await SupabaseService.saveBillGetId(BillModel(
        id: '',
        shopId: shop.id,
        userId: userId,
        amount: total,
        billDate: DateTime.now(),
        vendorName: customerName,
        billType: 'sale_return',
        notes: note,
        createdAt: DateTime.now(),
      ));

      for (final draft in selected) {
        final sale = draft.line.sale;
        String? stockItemId = sale.stockItemId;
        if (stockItemId == null || stockItemId.isEmpty) {
          final created = await SupabaseService.saveMasterItem(ItemMasterModel(
            id: '',
            shopId: shop.id,
            userId: userId,
            itemName: sale.itemName,
            currentStock: draft.qty,
            createdAt: DateTime.now(),
          ));
          stockItemId = created.id;
          stockAddedIds.add(_StockRollback(stockItemId, draft.qty, created: true));
        } else {
          final ok = await SupabaseService.addMasterStockById(stockItemId, draft.qty);
          if (!ok) {
            throw Exception(AppLang.tr(
              isEn,
              'Stock update failed for ${sale.itemName}',
              '${sale.itemName} का स्टॉक अपडेट नहीं हुआ',
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
          paymentMode: paymentMode,
          billId: billId,
          stockItemId: stockItemId,
          saleDate: DateTime.now(),
          notes: note,
          createdAt: DateTime.now(),
        ));
      }

      await _applyReturnSettlement(
        shopId: shop.id,
        userId: userId,
        customerName: customerName,
        amount: total,
        settlement: settlement,
        sourceBill: sourceBill,
        selectedDrafts: selected,
      );

      ref.invalidate(todayBillsProvider);
      ref.invalidate(filteredBillsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(itemMasterProvider);
      ref.invalidate(stockItemsProvider);
      ref.invalidate(udharCustomersProvider);

      await _searchCustomers(customerName);
      await _loadPurchases();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settlement == _ReturnSettlement.adjustment
                  ? AppLang.tr(
                      isEn,
                      'Return noted. ${_currency.format(total)} will adjust in the next purchase.',
                      'वापसी दर्ज हो गई। ${_currency.format(total)} अगली खरीद में समायोजित होगा।',
                    )
                  : AppLang.tr(
                      isEn,
                      '${_currency.format(total)} returned to $customerName. Stock updated.',
                      '$customerName को ${_currency.format(total)} वापस किए। स्टॉक अपडेट हो गया।',
                    ),
            ),
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
        if (!rollback.created) {
          await SupabaseService.deductMasterStockById(
            rollback.stockItemId,
            rollback.quantity,
          );
        }
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
    required String customerName,
    required double amount,
    required _ReturnSettlement settlement,
    required BillModel? sourceBill,
    required List<_ReturnLineDraft> selectedDrafts,
  }) async {
    var customer = _selectedCustomer?.udharCustomer ??
        await SupabaseService.findCustomerByName(shopId, customerName);
    final creditPlan = await _creditReturnPlan(
      shopId: shopId,
      customer: customer,
      sourceBill: sourceBill,
      returnAmount: amount,
      selectedDrafts: selectedDrafts,
    );

    if (creditPlan.reduceUdharAmount > 0 && customer != null) {
      final currentDue = await SupabaseService.getCustomerTotalDue(customer.id);
      final reduceBy = creditPlan.reduceUdharAmount.clamp(0, currentDue).toDouble();
      if (reduceBy > 0) {
        await SupabaseService.addDebitEntry(
          shopId: shopId,
          userId: userId,
          customerId: customer.id,
          amount: reduceBy,
          note:
              '${SupabaseService.saleReturnUdharReductionNote}. Bill ref: ${sourceBill?.id ?? 'none'}',
        );
        await SupabaseService.updateCustomerTotalDue(customer.id, currentDue - reduceBy);
      }
    }

    final settleAmount = creditPlan.customerPaidReturnAmount;
    if (settlement == _ReturnSettlement.cashRefund || settleAmount <= 0) {
      if (customer != null) {
        await SupabaseService.syncCustomerCreditEntriesPaidStatus(customer.id);
      }
      return;
    }

    customer ??= await SupabaseService.createUdharCustomer(
      shopId: shopId,
      userId: userId,
      customerName: customerName,
    );

    if (settlement == _ReturnSettlement.adjustment) {
      await SupabaseService.addCustomerAdjustmentAmount(customer.id, settleAmount);
      await SupabaseService.addAdjustmentCreditEntry(
        shopId: shopId,
        userId: userId,
        customerId: customer.id,
        amount: settleAmount,
        note: 'Return adjustment - credit for next purchase. Bill ref: ${sourceBill?.id ?? 'none'}',
      );
      await SupabaseService.syncCustomerCreditEntriesPaidStatus(customer.id);
      return;
    }

    if (settlement == _ReturnSettlement.reduceUdhar) {
      final currentDue = await SupabaseService.getCustomerTotalDue(customer.id);
      final reducedBy = settleAmount.clamp(0, currentDue).toDouble();
      if (reducedBy > 0) {
        await SupabaseService.addDebitEntry(
          shopId: shopId,
          userId: userId,
          customerId: customer.id,
          amount: reducedBy,
          note:
              '${SupabaseService.saleReturnUdharReductionNote}. Bill ref: ${sourceBill?.id ?? 'none'}',
        );
      }
      await SupabaseService.updateCustomerTotalDue(customer.id, currentDue - reducedBy);
    }
    await SupabaseService.syncCustomerCreditEntriesPaidStatus(customer.id);
  }

  Future<_CreditReturnPlan> _creditReturnPlan({
    required String shopId,
    required UdharCustomerModel? customer,
    required BillModel? sourceBill,
    required double returnAmount,
    required List<_ReturnLineDraft> selectedDrafts,
  }) async {
    if (sourceBill == null || customer == null) {
      return _CreditReturnPlan(
        customerPaidReturnAmount: returnAmount,
        reduceUdharAmount: 0,
      );
    }

    final paymentMode = selectedDrafts.isEmpty
        ? 'cash'
        : selectedDrafts.first.line.sale.paymentMode.toLowerCase();
    if (paymentMode != 'credit' && paymentMode != 'split') {
      return _CreditReturnPlan(
        customerPaidReturnAmount: returnAmount,
        reduceUdharAmount: 0,
      );
    }

    final creditMeta = _creditMetaForBill(selectedDrafts, sourceBill.id);
    final originalCreditAmount = creditMeta?.creditAmount ??
        (paymentMode == 'credit' ? sourceBill.amount : 0.0);
    final originalPaidAmount =
        (sourceBill.amount - originalCreditAmount).clamp(0, sourceBill.amount).toDouble();
    final paidAfterSale = await _paidAfterSaleForBill(
      customerId: customer.id,
      billId: sourceBill.id,
    );

    final currentCreditForBill = (originalCreditAmount - paidAfterSale).clamp(0.0, double.infinity);
    final udharReduction = returnAmount.clamp(0.0, currentCreditForBill);
    final paidReturnAmount = (returnAmount - udharReduction).clamp(0.0, double.infinity);

    return _CreditReturnPlan(
      customerPaidReturnAmount: paidReturnAmount,
      reduceUdharAmount: udharReduction,
    );
  }

  SavedCreditSale? _creditMetaForBill(
    List<_ReturnLineDraft> selectedDrafts,
    String billId,
  ) {
    for (final draft in selectedDrafts) {
      final parsed = SavedCreditSale.tryParseNote(draft.line.sale.notes);
      if (parsed == null) continue;
      if (parsed.billId == null || parsed.billId == billId) return parsed;
    }
    return null;
  }

  Future<double> _paidAfterSaleForBill({
    required String customerId,
    required String billId,
  }) async {
    try {
      final entries = await SupabaseService.getUdharEntriesForCustomer(customerId);
      String? creditEntryId;
      for (final entry in entries.where((entry) => entry.entryType == 'credit')) {
        final credit = SavedCreditSale.tryParseNote(entry.note);
        if (credit?.billId == billId) {
          creditEntryId = entry.id;
          break;
        }
      }
      return entries.where((entry) {
        if (entry.entryType != 'debit') return false;
        final meta = UdharPaymentMeta.tryParseNote(entry.note);
        return meta?.billId == billId ||
            (creditEntryId != null && meta?.appliedCreditEntryId == creditEntryId);
      }).fold<double>(0, (sum, entry) => sum + entry.amount);
    } catch (_) {
      return 0;
    }
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
}

enum _CustomerSource { udhar, cash, typed }

class _ReturnCustomer {
  final String name;
  final String phone;
  final double totalDue;
  final _CustomerSource source;
  final UdharCustomerModel? udharCustomer;

  const _ReturnCustomer({
    required this.name,
    this.phone = '',
    this.totalDue = 0,
    this.source = _CustomerSource.typed,
    this.udharCustomer,
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

class _RefundOption {
  final String value;
  final String label;

  const _RefundOption(this.value, this.label);
}

class _StockRollback {
  final String stockItemId;
  final double quantity;
  final bool created;

  const _StockRollback(this.stockItemId, this.quantity, {this.created = false});
}

class _CreditReturnPlan {
  final double customerPaidReturnAmount;
  final double reduceUdharAmount;

  const _CreditReturnPlan({
    required this.customerPaidReturnAmount,
    required this.reduceUdharAmount,
  });
}

enum _ReturnSettlement { adjustment, cashRefund, reduceUdhar }
