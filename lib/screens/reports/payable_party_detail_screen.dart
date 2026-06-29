import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import 'bill_image_viewer_screen.dart';

/// Detail screen showing all purchase entries for a specific supplier party.
class PayablePartyDetailScreen extends ConsumerStatefulWidget {
  final String partyId;
  final String partyName;
  final String partyPhone;
  final String partyStation;
  final double pendingAmount;

  const PayablePartyDetailScreen({
    super.key,
    required this.partyId,
    required this.partyName,
    required this.partyPhone,
    required this.partyStation,
    required this.pendingAmount,
  });

  @override
  ConsumerState<PayablePartyDetailScreen> createState() =>
      _PayablePartyDetailScreenState();
}

class _PayablePartyDetailScreenState
    extends ConsumerState<PayablePartyDetailScreen> {
  bool _loading = true;
  List<_PurchaseEntry> _entries = [];
  double _totalPurchased = 0;
  double _totalPaid = 0;
  double _pendingAmount = 0;

  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _pendingAmount = widget.pendingAmount;
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final shop = ref.read(shopProvider).value;
      if (shop == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final latestPending = widget.partyId.isEmpty
          ? widget.pendingAmount
          : await SupabaseService.getPurchasePartyPendingAmount(widget.partyId);
      final bills = await SupabaseService.getPurchaseBillsForParty(
          shop.id, widget.partyName);
      final salesByBillId = await SupabaseService.getSalesGroupedByBillIds(
        bills.map((bill) => bill.id),
      );

      final entries = <_PurchaseEntry>[];
      double totalPurchased = 0;
      double totalPaid = 0;

      for (final bill in bills) {
        if (bill.notes == 'Payment to Supplier') {
          totalPaid += bill.amount;
          entries.add(_PurchaseEntry(
            bill: bill,
            paymentMode: 'payment',
            cashPaid: bill.amount,
            creditAmount: 0,
          ));
          continue;
        }

        String paymentMode = 'cash';
        double cashPaid = 0;
        double creditAmount = 0;
        bool hasCreditDetails = false;

        try {
          final sales = salesByBillId[bill.id] ?? const [];
          if (sales.isNotEmpty) {
            paymentMode = sales.first.paymentMode;
            
            // Look for __saafhisaab_credit_advance:advance;credit:credit__ marker in notes
            for (final s in sales) {
              final notesStr = s.notes;
              final startMarker = '__saafhisaab_credit_advance:';
              final startIndex = notesStr.indexOf(startMarker);
              if (startIndex >= 0) {
                final endMarker = '__';
                final endIndex = notesStr.indexOf(endMarker, startIndex + startMarker.length);
                if (endIndex >= 0) {
                  final sub = notesStr.substring(startIndex + startMarker.length, endIndex);
                  final parts = sub.split(';credit:');
                  if (parts.length == 2) {
                    cashPaid = double.tryParse(parts[0]) ?? 0.0;
                    creditAmount = double.tryParse(parts[1]) ?? 0.0;
                    hasCreditDetails = true;
                    break;
                  }
                }
              }
            }

            if (!hasCreditDetails) {
              if (paymentMode == 'credit') {
                creditAmount = bill.amount;
                cashPaid = 0;
              } else if (paymentMode == 'split') {
                creditAmount = bill.amount;
                cashPaid = 0;
              } else {
                cashPaid = bill.amount;
                creditAmount = 0;
              }
            }
          } else {
            cashPaid = bill.amount;
          }
        } catch (_) {
          cashPaid = bill.amount;
        }

        totalPurchased += bill.amount;
        totalPaid += cashPaid;

        entries.add(_PurchaseEntry(
          bill: bill,
          paymentMode: paymentMode,
          cashPaid: cashPaid,
          creditAmount: creditAmount,
        ));
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _totalPurchased = totalPurchased;
          _totalPaid = totalPaid;
          _pendingAmount = latestPending;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
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
        title: Text(widget.partyName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadEntries,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Party Info Header ──
                  _buildPartyHeader(isEn),
                  const SizedBox(height: 12),

                  // ── Summary Stats ──
                  _buildSummaryRow(isEn),
                  const SizedBox(height: 20),

                  // ── Section Title ──
                  Row(children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLang.tr(isEn, 'Purchase Entries', 'खरीद प्रविष्टियाँ'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_entries.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Entry List ──
                  if (_entries.isEmpty)
                    _buildEmptyState(isEn)
                  else
                    ..._entries
                        .asMap()
                        .entries
                        .map((e) => _buildEntryCard(e.value, e.key, isEn)),
                ],
              ),
            ),
    );
  }

  Widget _buildPartyHeader(bool isEn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              widget.partyName.isNotEmpty
                  ? widget.partyName[0].toUpperCase()
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.partyName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.partyPhone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(children: [
                  Icon(Icons.phone_rounded,
                      size: 13, color: Colors.white.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    widget.partyPhone,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ),
            if (widget.partyStation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  Icon(Icons.location_on_rounded,
                      size: 13, color: Colors.white.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    widget.partyStation,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        // Pending amount
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            _currency.format(_pendingAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            AppLang.tr(isEn, 'Payable', 'देय'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildSummaryRow(bool isEn) {
    return Row(children: [
      Expanded(child: _summaryTile(
        AppLang.tr(isEn, 'Total Purchase', 'कुल खरीद'),
        _currency.format(_totalPurchased),
        Icons.shopping_bag_rounded,
        AppColors.primary,
      )),
      const SizedBox(width: 10),
      Expanded(child: _summaryTile(
        AppLang.tr(isEn, 'Total Paid', 'कुल भुगतान'),
        _currency.format(_totalPaid),
        Icons.check_circle_rounded,
        AppColors.success,
      )),
      const SizedBox(width: 10),
      Expanded(child: _summaryTile(
        AppLang.tr(isEn, 'Pending', 'बकाया'),
        _currency.format(_pendingAmount),
        Icons.warning_rounded,
        AppColors.error,
      )),
    ]);
  }

  Widget _summaryTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildEmptyState(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        Icon(Icons.receipt_long_rounded,
            size: 56, color: AppColors.textHint.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text(
          AppLang.tr(isEn, 'No purchase entries found',
              'कोई खरीद प्रविष्टि नहीं मिली'),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    );
  }

  Widget _buildEntryCard(_PurchaseEntry entry, int index, bool isEn) {
    final bill = entry.bill;
    final isCredit = entry.paymentMode == 'credit';
    final isSplit = entry.paymentMode == 'split';
    final isPayment = entry.paymentMode == 'payment';

    // Payment mode display
    String modeLabel;
    IconData modeIcon;
    Color modeColor;
    if (isPayment) {
      modeLabel = AppLang.tr(isEn, 'Payment', 'भुगतान');
      modeIcon = Icons.payments_rounded;
      modeColor = AppColors.success;
    } else if (isCredit) {
      modeLabel = AppLang.tr(isEn, 'Credit', 'उधार');
      modeIcon = Icons.access_time_rounded;
      modeColor = AppColors.error;
    } else if (isSplit) {
      modeLabel = AppLang.tr(isEn, 'Split', 'विभाजित');
      modeIcon = Icons.call_split_rounded;
      modeColor = Colors.orange;
    } else {
      modeLabel = AppLang.tr(isEn, 'Cash', 'नकद');
      modeIcon = Icons.money_rounded;
      modeColor = AppColors.success;
    }

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
        // ── Top Row: Date + Amount ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            // Serial Number
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Date & Category
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateFmt.format(bill.billDate),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (bill.category.isNotEmpty && bill.category != 'General')
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [
                          const Icon(Icons.category_rounded,
                              size: 11, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Text(
                            bill.category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]),
                      ),
                  ]),
            ),
            // Amount
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                isPayment
                    ? '-${_currency.format(bill.amount)}'
                    : _currency.format(bill.amount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                AppLang.tr(isEn, 'Bill Amount', 'बिल राशि'),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ]),
        ),

        // ── Divider ──
        const Divider(height: 1, color: AppColors.border),

        // ── Bottom Row: Payment Info ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(children: [
            // Payment Mode chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: modeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: modeColor.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(modeIcon, size: 13, color: modeColor),
                const SizedBox(width: 4),
                Text(
                  modeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: modeColor,
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),

            // Split details
            if (isSplit) ...[
              Text(
                '${AppLang.tr(isEn, 'Paid', 'भुगतान')}: ${_currency.format(entry.cashPaid)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${AppLang.tr(isEn, 'Due', 'बाकी')}: ${_currency.format(entry.creditAmount)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],

            if (isCredit)
              Text(
                '${AppLang.tr(isEn, 'Due', 'बाकी')}: ${_currency.format(entry.creditAmount)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),

            const Spacer(),

            // Notes icon
            if (bill.notes.isNotEmpty)
              Tooltip(
                message: bill.notes,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.notes_rounded,
                      size: 14, color: AppColors.textHint),
                ),
              ),

            if (bill.imageUrl.isNotEmpty) ...[
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BillImageViewerScreen(
                      imageUrl: bill.imageUrl,
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
            ],

            // GST badge
            if (bill.isGstBill) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'GST',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _PurchaseEntry {
  final BillModel bill;
  final String paymentMode;
  final double cashPaid;
  final double creditAmount;

  _PurchaseEntry({
    required this.bill,
    required this.paymentMode,
    required this.cashPaid,
    required this.creditAmount,
  });
}
