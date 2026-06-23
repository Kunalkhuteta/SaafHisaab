import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/ledger_row_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import 'ledger_particular_month_page.dart';
import 'package:saafhisaab/utils/indian_date_time.dart';


class LedgerMonthlyViewPage extends ConsumerStatefulWidget {
  final String accountId;
  final String partyName;
  final bool isReceivable;

  const LedgerMonthlyViewPage({
    super.key,
    required this.accountId,
    required this.partyName,
    required this.isReceivable,
  });

  @override
  ConsumerState<LedgerMonthlyViewPage> createState() => _LedgerMonthlyViewPageState();
}

class _LedgerMonthlyViewPageState extends ConsumerState<LedgerMonthlyViewPage> {
  static const Color _debitCol = AppColors.error;
  static const Color _creditCol = AppColors.success;

  bool _loading = true;
  List<LedgerRow> _rows = [];

  final _fmt = NumberFormat('#,##,##0.00', 'en_IN');
  final _fmtFull = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  final Map<String, int> _monthMap = {
    'January': 1,
    'February': 2,
    'March': 3,
    'April': 4,
    'May': 5,
    'June': 6,
    'July': 7,
    'August': 8,
    'September': 9,
    'October': 10,
    'November': 11,
    'December': 12,
  };

  int _yearForMonth(int month, int coFinYear) =>
      month >= 4 ? coFinYear : coFinYear + 1;

  DateTime _monthStart(String monthName, int coFinYear) {
    final month = _monthMap[monthName.trim()]!;
    return IndianDateTime.date(_yearForMonth(month, coFinYear), month, 1);
  }

  DateTime _monthEnd(String monthName, int coFinYear) {
    final month = _monthMap[monthName.trim()]!;
    final year = _yearForMonth(month, coFinYear);
    return IndianDateTime.date(year, month + 1, 0);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shop = ref.read(shopProvider).value;
      if (shop == null) return;

      final data = await SupabaseService.fetchLedgerMonthly(
        accountId: widget.accountId,
        isReceivable: widget.isReceivable,
        shopId: shop.id,
      );

      if (!mounted) return;
      setState(() {
        _rows = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ledger: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  LedgerRow? get _opening => _rows.isNotEmpty ? _rows.first : null;
  LedgerRow? get _closing => _rows.isNotEmpty ? _rows.last : null;
  List<LedgerRow> get _monthRows =>
      _rows.length > 2 ? _rows.sublist(1, _rows.length - 1) : [];

  double get _totalDebit => _monthRows.fold(0.0, (s, r) => s + r.debit);
  double get _totalCredit => _monthRows.fold(0.0, (s, r) => s + r.credit);

  void _onMonthTap(LedgerRow e) {
    final now = IndianDateTime.now();
    final fy = now.month >= 4 ? now.year : now.year - 1;
    DateTime from, to;

    if (e.particular == '***** ALL MONTHS *****') {
      from = IndianDateTime.date(fy, 4, 1);
      to = IndianDateTime.date(fy + 1, 3, 31);
    } else {
      from = _monthStart(e.particular, fy);
      to = _monthEnd(e.particular, fy);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => LedgerParticularMonthPage(
              accountId: widget.accountId,
              partyName: widget.partyName,
              isReceivable: widget.isReceivable,
              fromDate: from,
              toDate: to,
              monthLabel: e.particular,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partyName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              AppLang.tr(isEn, 'Monthly Ledger', 'मासिक खाता लेजर'),
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _rows.isEmpty
              ? Center(child: Text(AppLang.tr(isEn, 'No ledger data available', 'कोई लेजर डेटा उपलब्ध नहीं')))
              : _buildBody(),
    );
  }

  Widget _summaryCard() {
    final openingBal = _opening?.balance ?? 0.0;
    final closingBal = _closing?.balance ?? 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          children: [
            Row(
              children: [
                _summaryCol(
                  'OPENING BALANCE',
                  '${_fmtFull.format(openingBal.abs())} ${openingBal >= 0 ? "Cr" : "Dr"}',
                  Colors.white,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _summaryCol(
                  'CLOSING BALANCE',
                  '${_fmtFull.format(closingBal.abs())} ${closingBal >= 0 ? "Cr" : "Dr"}',
                  Colors.white,
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.15), height: 1),
            const SizedBox(height: 16),

            Row(
              children: [
                _summaryCol(
                  'TOTAL DEBIT',
                  _totalDebit > 0 ? _fmt.format(_totalDebit) : '—',
                  const Color(0xFFEF9A9A),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _summaryCol(
                  'TOTAL CREDIT',
                  _totalCredit > 0 ? _fmt.format(_totalCredit) : '—',
                  const Color(0xFF81C784),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _summaryCol('MONTHS', '${_monthRows.length}', Colors.white70),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCol(String label, String value, Color valueColor) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 0.9,
            color: Colors.white.withOpacity(0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _buildBody() => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      _summaryCard(),

      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Text(
          '${_monthRows.length} month${_monthRows.length == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      ..._monthRows.map(
        (e) => _MonthTile(
          row: e,
          fmt: _fmt,
          debitCol: _debitCol,
          creditCol: _creditCol,
          onTap: () => _onMonthTap(e),
        ),
      ),
    ],
  );
}

class _MonthTile extends StatelessWidget {
  final LedgerRow row;
  final NumberFormat fmt;
  final Color debitCol, creditCol;
  final VoidCallback onTap;

  const _MonthTile({
    required this.row,
    required this.fmt,
    required this.debitCol,
    required this.creditCol,
    required this.onTap,
  });

  String get _monthShort {
    final p = row.particular.trim();
    if (p.length >= 3) return p.substring(0, 3).toUpperCase();
    return p.toUpperCase();
  }

  Color get _avatarColor {
    const quarters = {
      'APR': Color(0xFF1565C0),
      'MAY': Color(0xFF1565C0),
      'JUN': Color(0xFF1565C0),
      'JUL': Color(0xFF6A1B9A),
      'AUG': Color(0xFF6A1B9A),
      'SEP': Color(0xFF6A1B9A),
      'OCT': Color(0xFF2E7D32),
      'NOV': Color(0xFF2E7D32),
      'DEC': Color(0xFF2E7D32),
      'JAN': Color(0xFFE65100),
      'FEB': Color(0xFFE65100),
      'MAR': Color(0xFFE65100),
    };
    return quarters[_monthShort] ?? const Color(0xFF37474F);
  }

  @override
  Widget build(BuildContext context) {
    final hasDebit = row.debit > 0;
    final hasCredit = row.credit > 0;
    final balPositive = row.balance >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _avatarColor,
                  child: Text(
                    _monthShort,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.particular,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (hasDebit) ...[
                            Text(
                              'Dr: ${fmt.format(row.debit)}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: debitCol,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (hasCredit) const SizedBox(width: 8),
                          ],
                          if (hasCredit)
                            Text(
                              'Cr: ${fmt.format(row.credit)}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: creditCol,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (!hasDebit && !hasCredit)
                            const Text(
                              'No transactions',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt.format(row.balance.abs()),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (balPositive ? creditCol : debitCol).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        balPositive ? 'Cr' : 'Dr',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: balPositive ? creditCol : debitCol,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
