import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../widgets/credit_entry_sheet.dart';

class LedgerParticularMonthPage extends ConsumerStatefulWidget {
  final String accountId;
  final String partyName;
  final bool isReceivable;
  final DateTime fromDate;
  final DateTime toDate;
  final String monthLabel;

  const LedgerParticularMonthPage({
    super.key,
    required this.accountId,
    required this.partyName,
    required this.isReceivable,
    required this.fromDate,
    required this.toDate,
    required this.monthLabel,
  });

  @override
  ConsumerState<LedgerParticularMonthPage> createState() => _LedgerParticularMonthPageState();
}

class _LedgerParticularMonthPageState extends ConsumerState<LedgerParticularMonthPage> {
  bool _loading = true;
  double _openingBalance = 0;
  List<_LedgerDetailEntry> _entries = [];

  final _fmt = NumberFormat('#,##,##0.00', 'en_IN');
  final _df = DateFormat('dd-MM-yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shop = ref.read(shopProvider).value;
      if (shop == null) return;

      double opening = 0.0;
      final List<_LedgerDetailEntry> detailEntries = [];

      if (widget.isReceivable) {
        // Fetch customer udhar entries
        final entries = await SupabaseService.getUdharEntriesForCustomer(widget.accountId);
        // Sort chronologically (oldest first)
        entries.sort((a, b) => a.entryDate.compareTo(b.entryDate));

        double debitsBefore = 0.0;
        double creditsBefore = 0.0;

        for (final entry in entries) {
          final isCredit = entry.entryType == 'credit'; // udhar given = debit (owing us)
          final amt = entry.amount;

          if (entry.entryDate.isBefore(widget.fromDate)) {
            if (isCredit) {
              debitsBefore += amt;
            } else {
              creditsBefore += amt;
            }
          } else if (!entry.entryDate.isAfter(widget.toDate)) {
            detailEntries.add(_LedgerDetailEntry(
              date: entry.entryDate,
              particular: entry.note.isNotEmpty ? entry.note : 'Udhar Entry',
              debit: isCredit ? amt : 0.0,
              credit: isCredit ? 0.0 : amt,
            ));
          }
        }
        opening = -debitsBefore + creditsBefore;

      } else {
        // Fetch supplier bills
        final partyName = await SupabaseService.getPurchasePartyName(widget.accountId);

        final bills = await SupabaseService.getPurchaseBillsForParty(shop.id, partyName);
        // Sort chronologically (oldest first)
        bills.sort((a, b) => a.billDate.compareTo(b.billDate));

        double debitsBefore = 0.0;
        double creditsBefore = 0.0;

        for (final bill in bills) {
          final isPayment = bill.notes == 'Payment to Supplier';
          final amt = bill.amount;

          if (bill.billDate.isBefore(widget.fromDate)) {
            if (isPayment) {
              debitsBefore += amt;
            } else {
              creditsBefore += amt;
            }
          } else if (!bill.billDate.isAfter(widget.toDate)) {
            detailEntries.add(_LedgerDetailEntry(
              date: bill.billDate,
              particular: bill.notes.isNotEmpty ? bill.notes : 'Purchase Bill',
              debit: isPayment ? amt : 0.0,
              credit: isPayment ? 0.0 : amt,
            ));
          }
        }
        opening = -debitsBefore + creditsBefore;
      }

      // Calculate running balances
      double running = opening;
      for (final entry in detailEntries) {
        running = running - entry.debit + entry.credit;
        entry.balanceAfter = running;
      }

      if (!mounted) return;
      setState(() {
        _openingBalance = opening;
        _entries = detailEntries;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load month details: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  double get _totalDebit => _entries.fold(0.0, (s, r) => s + r.debit);
  double get _totalCredit => _entries.fold(0.0, (s, r) => s + r.credit);
  double get _closingBalance => _entries.isEmpty ? _openingBalance : _entries.last.balanceAfter;

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partyName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${AppLang.tr(isEn, 'Ledger for', 'लेजर')} ${widget.monthLabel}',
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildSummaryHeader(),
                Expanded(
                  child: _entries.isEmpty
                      ? Center(child: Text(AppLang.tr(isEn, 'No transactions this month', 'इस महीने कोई लेन-देन नहीं')))
                      : _buildEntriesList(isEn),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerItem('Opening Balance', _openingBalance),
              _headerItem('Total Debit (Dr)', _totalDebit, color: AppColors.error),
              _headerItem('Total Credit (Cr)', _totalCredit, color: AppColors.success),
              _headerItem('Closing Balance', _closingBalance),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _headerItem(String label, double value, {Color? color}) {
    final isBal = label.contains('Balance');
    final suffix = isBal ? (value >= 0 ? ' Cr' : ' Dr') : '';
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '₹${_fmt.format(value.abs())}$suffix',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(bool isEn) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final entry = _entries[i];
        final isDr = entry.debit > 0;
        final val = isDr ? entry.debit : entry.credit;
        final balVal = entry.balanceAfter;

        // Clean up raw notes or JSON text markers if present
        String cleanPart = _formatParticular(entry.particular, isEn);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanPart,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _df.format(entry.date),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${_fmt.format(val)} ${isDr ? 'Dr' : 'Cr'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDr ? AppColors.error : AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bal: ₹${_fmt.format(balVal.abs())} ${balVal >= 0 ? 'Cr' : 'Dr'}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatParticular(String particular, bool isEn) {
    // 1. Try to parse credit sale meta (__saafhisaab_credit_sale_v1__)
    if (particular.contains(SavedCreditSale.noteMarker)) {
      final sale = SavedCreditSale.tryParseNote(particular);
      if (sale != null) {
        final itemsText = sale.items
            .map((item) =>
                '${item.itemName} (${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unit})')
            .join(', ');
        final prefix = AppLang.tr(isEn, 'Credit Sale: ', 'उधार बिक्री: ');
        String result = itemsText.isNotEmpty
            ? '$prefix$itemsText'
            : AppLang.tr(isEn, 'Credit Sale', 'उधार बिक्री');
        if (sale.note.isNotEmpty) {
          result += ' (${sale.note})';
        }
        return result;
      }
    }

    // 2. Try to parse payment meta (__saafhisaab_credit_payment_v1__)
    if (particular.contains(UdharPaymentMeta.noteMarker)) {
      final payment = UdharPaymentMeta.tryParseNote(particular);
      if (payment != null) {
        final method = payment.paymentMethod.toLowerCase();
        String methodText = '';
        if (method == 'upi') {
          methodText = 'UPI';
        } else if (method == 'cash') {
          methodText = AppLang.tr(isEn, 'Cash', 'नकद');
        } else if (method == 'card') {
          methodText = AppLang.tr(isEn, 'Card', 'कार्ड');
        } else if (method == 'bank') {
          methodText = AppLang.tr(isEn, 'Bank Transfer', 'बैंक ट्रांसफर');
        } else if (method == 'adjustment') {
          methodText = AppLang.tr(isEn, 'Adjustment', 'समायोजन');
        } else {
          methodText = payment.paymentMethod;
        }
        return AppLang.tr(isEn, 'Payment ($methodText)', 'भुगतान ($methodText)');
      }
    }

    // 3. Clean other internal markers
    String clean = particular;

    // Remove sale adjustment metadata: __saafhisaab_sale_adjustment_v1__ followed by JSON object
    clean = clean.replaceAll(RegExp(r'__saafhisaab_sale_adjustment_v1__\{[^}]*\}'), '');

    // Remove credit advance metadata: __saafhisaab_credit_advance:...__
    clean = clean.replaceAll(RegExp(r'__saafhisaab_credit_advance:[^_]+__'), '');

    // Remove return reference metadata: __saafhisaab_return_ref:...__
    clean = clean.replaceAll(RegExp(r'__saafhisaab_return_ref:[^_]+__'), '');

    // Split into lines, translate system parts, and join
    final lines = clean.split('\n');
    final cleanedLines = <String>[];

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Translate system texts
      String translated = trimmedLine;
      if (trimmedLine == 'Payment to Supplier') {
        translated = AppLang.tr(isEn, 'Payment to Supplier', 'आपूर्तिकर्ता को भुगतान');
      } else if (trimmedLine == 'Purchase Bill') {
        translated = AppLang.tr(isEn, 'Purchase Bill', 'खरीद बिल');
      } else if (trimmedLine == 'Udhar Entry') {
        translated = AppLang.tr(isEn, 'Udhar Entry', 'उधार प्रविष्टि');
      } else if (trimmedLine == 'Fresh return - no reference bill') {
        translated = AppLang.tr(isEn, 'Fresh Return (No Bill)', 'नई वापसी (बिना बिल)');
      } else if (trimmedLine == 'Sale return - udhar reduced') {
        translated = AppLang.tr(isEn, 'Sale Return (Udhar Reduced)', 'बिक्री वापसी (उधार कम हुआ)');
      } else if (trimmedLine == 'Advance payment on credit sale') {
        translated = AppLang.tr(isEn, 'Advance Payment on Credit Sale', 'उधार बिक्री पर अग्रिम भुगतान');
      } else if (trimmedLine.contains('Return adjustment - credit for next purchase')) {
        final billMatch = RegExp(r'Bill ref:\s*(\S+)').firstMatch(trimmedLine);
        final billRef = billMatch != null ? ' (Ref: ${billMatch.group(1)})' : '';
        translated = AppLang.tr(isEn, 'Return Adjustment$billRef', 'वापसी समायोजन$billRef');
      } else {
        // Sale return from bill X
        final saleReturnMatch = RegExp(r'Sale return from bill (\S+)').firstMatch(trimmedLine);
        if (saleReturnMatch != null) {
          final billId = saleReturnMatch.group(1);
          translated = AppLang.tr(isEn, 'Sale Return (Bill: $billId)', 'बिक्री वापसी (बिल: $billId)');
        } else {
          // Settlement: X
          final settlementMatch = RegExp(r'Settlement:\s*(\S+)').firstMatch(trimmedLine);
          if (settlementMatch != null) {
            final mode = settlementMatch.group(1)!.toLowerCase();
            String modeText = mode;
            if (mode == 'cash') {
              modeText = AppLang.tr(isEn, 'Cash', 'नकद');
            } else if (mode == 'upi') {
              modeText = 'UPI';
            } else if (mode == 'card') {
              modeText = AppLang.tr(isEn, 'Card', 'कार्ड');
            } else if (mode == 'adjustment') {
              modeText = AppLang.tr(isEn, 'Adjustment', 'समायोजन');
            }
            translated = AppLang.tr(isEn, 'Settlement: $modeText', 'निपटान: $modeText');
          }
        }
      }

      if (translated.isNotEmpty) {
        cleanedLines.add(translated);
      }
    }

    clean = cleanedLines.join(' | ');

    if (clean.isEmpty) {
      return AppLang.tr(isEn, 'Transaction', 'लेन-देन');
    }

    return clean;
  }
}

class _LedgerDetailEntry {
  final DateTime date;
  final String particular;
  final double debit;
  final double credit;
  double balanceAfter;

  _LedgerDetailEntry({
    required this.date,
    required this.particular,
    required this.debit,
    required this.credit,
    this.balanceAfter = 0,
  });
}
