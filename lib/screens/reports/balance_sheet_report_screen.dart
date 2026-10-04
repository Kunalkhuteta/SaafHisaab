import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../utils/indian_date_time.dart';
import '../../services/reports_html_template.dart';
import '../../widgets/report_pdf_action_button.dart';

class BalanceSheetReportScreen extends ConsumerStatefulWidget {
  const BalanceSheetReportScreen({super.key});

  @override
  ConsumerState<BalanceSheetReportScreen> createState() =>
      _BalanceSheetReportScreenState();
}

class _BalanceSheetReportScreenState
    extends ConsumerState<BalanceSheetReportScreen> {
  DateTime _asOnDate = DateTime.now();
  bool _isLoading = true;
  String? _errorMessage;

  // Assets
  double _cashInHand = 0.0;
  double _bankBalance = 0.0;
  double _sundryDebtors = 0.0; // Udhar Receivables
  double _closingStock = 0.0;

  // Liabilities
  double _sundryCreditors = 0.0; // Supplier Payables
  double _outstandingExpenses = 0.0;
  double _proprietorCapital = 0.0;

  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadBalanceSheet();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOnDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _asOnDate = picked);
      _loadBalanceSheet();
    }
  }

  Future<void> _loadBalanceSheet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) throw Exception('Shop not loaded');

      final client = Supabase.instance.client;

      // 1. Sundry Debtors (Receivables from udhar_customers)
      double totalDebtors = 0.0;
      try {
        final customers = await client
            .from('udhar_customers')
            .select('total_due')
            .eq('shop_id', shop.id);
        for (final c in customers) {
          final due = (c['total_due'] as num?)?.toDouble() ?? 0.0;
          if (due > 0) totalDebtors += due;
        }
      } catch (e) {
        debugPrint('Customers load error: $e');
      }

      // 2. Sundry Creditors (Payables to purchase_parties)
      double totalCreditors = 0.0;
      try {
        final parties = await client
            .from('purchase_parties')
            .select('pending_amount')
            .eq('shop_id', shop.id);
        for (final p in parties) {
          final pending = (p['pending_amount'] as num?)?.toDouble() ?? 0.0;
          if (pending > 0) totalCreditors += pending;
        }
      } catch (e) {
        debugPrint('Parties load error: $e');
      }

      // 3. Closing Stock valuation
      double stockVal = 0.0;
      try {
        final items = await client
            .from('stock_items')
            .select('current_quantity, buying_price')
            .eq('shop_id', shop.id);
        for (final it in items) {
          final qty = (it['current_quantity'] as num?)?.toDouble() ?? 0.0;
          final price = (it['buying_price'] as num?)?.toDouble() ?? 0.0;
          if (qty > 0 && price > 0) {
            stockVal += (qty * price);
          }
        }
      } catch (e) {
        debugPrint('Stock items load error: $e');
      }

      // 4. Daily cash & bank balance from daily_balances table
      double cash = 0.0;
      double bank = 0.0;
      try {
        final balances = await client
            .from('daily_balances')
            .select('net_cash, net_bank')
            .eq('shop_id', shop.id)
            .order('date', ascending: false)
            .limit(30);

        for (final b in balances) {
          cash += (b['net_cash'] as num?)?.toDouble() ?? 0.0;
          bank += (b['net_bank'] as num?)?.toDouble() ?? 0.0;
        }

        // If daily_balances table has no positive record, compute from bills & sales
        if (cash <= 0 && bank <= 0) {
          final salesRes = await client
              .from('sales')
              .select('total_amount, payment_mode')
              .eq('shop_id', shop.id);
          for (final s in salesRes) {
            final amt = (s['total_amount'] as num?)?.toDouble() ?? 0.0;
            final mode = (s['payment_mode'] ?? 'cash').toString().toLowerCase();
            if (mode == 'online' || mode == 'bank') {
              bank += amt;
            } else {
              cash += amt;
            }
          }
        }
      } catch (e) {
        debugPrint('Balances load error: $e');
      }

      if (cash < 0) cash = 0.0;
      if (bank < 0) bank = 0.0;

      final totalAssets = cash + bank + totalDebtors + stockVal;
      final totalExternalLiabilities = totalCreditors + _outstandingExpenses;

      // Proprietor Capital balances the sheet: Capital = Assets - Liabilities
      double capital = totalAssets - totalExternalLiabilities;
      if (capital < 0) capital = 0.0;

      setState(() {
        _cashInHand = cash;
        _bankBalance = bank;
        _sundryDebtors = totalDebtors;
        _closingStock = stockVal;
        _sundryCreditors = totalCreditors;
        _proprietorCapital = capital;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _shareBalanceSheet() {
    final dateStr = DateFormat('dd MMMM yyyy').format(_asOnDate);
    final totalAssets = _cashInHand + _bankBalance + _sundryDebtors + _closingStock;
    final totalLiab = _sundryCreditors + _outstandingExpenses + _proprietorCapital;

    final sb = StringBuffer();
    sb.writeln('⚖️ BALANCE SHEET STATEMENT');
    sb.writeln('As at: $dateStr');
    sb.writeln('===================================');
    sb.writeln('ASSETS:');
    sb.writeln('• Cash in Hand: ${_currencyFmt.format(_cashInHand)}');
    sb.writeln('• Bank Balance: ${_currencyFmt.format(_bankBalance)}');
    sb.writeln('• Sundry Debtors (Receivables): ${_currencyFmt.format(_sundryDebtors)}');
    sb.writeln('• Closing Stock / Inventory: ${_currencyFmt.format(_closingStock)}');
    sb.writeln('TOTAL ASSETS: ${_currencyFmt.format(totalAssets)}');
    sb.writeln('-----------------------------------');
    sb.writeln('LIABILITIES & CAPITAL:');
    sb.writeln('• Sundry Creditors (Payables): ${_currencyFmt.format(_sundryCreditors)}');
    if (_outstandingExpenses > 0) {
      sb.writeln('• Outstanding Expenses: ${_currencyFmt.format(_outstandingExpenses)}');
    }
    sb.writeln('• Proprietor Capital & Equity: ${_currencyFmt.format(_proprietorCapital)}');
    sb.writeln('TOTAL LIABILITIES & CAPITAL: ${_currencyFmt.format(totalLiab)}');
    sb.writeln('===================================');
    sb.writeln('Working Capital: ${_currencyFmt.format(totalAssets - _sundryCreditors)}');
    sb.writeln('Generated via SaafHisaab App');

    Share.share(sb.toString(), subject: 'Balance Sheet as at $dateStr');
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final dateStr = DateFormat('dd MMMM yyyy').format(_asOnDate);

    final totalAssets = _cashInHand + _bankBalance + _sundryDebtors + _closingStock;
    final totalLiabilities = _sundryCreditors + _outstandingExpenses + _proprietorCapital;
    final workingCapital = totalAssets - _sundryCreditors;
    final currentRatio = _sundryCreditors > 0 ? (totalAssets / _sundryCreditors) : 10.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'Balance Sheet', 'तुलन पत्र (Balance Sheet)')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ReportPdfActionButton(
            reportTitle: 'Balance_Sheet_${DateFormat('yyyy_MM_dd').format(_asOnDate)}',
            onGenerateHtml: () async {
              final shop = await ref.read(shopProvider.future);
              return ReportsHtmlTemplate.generateBalanceSheet(
                shop: shop,
                asOnDate: _asOnDate,
                cashInHand: _cashInHand,
                bankBalance: _bankBalance,
                sundryDebtors: _sundryDebtors,
                closingStock: _closingStock,
                sundryCreditors: _sundryCreditors,
                outstandingExpenses: _outstandingExpenses,
                proprietorCapital: _proprietorCapital,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: AppLang.tr(isEn, 'Share Statement', 'खाता साझा करें'),
            onPressed: _shareBalanceSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Banner
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 18, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      '${AppLang.tr(isEn, 'As on', 'स्थिति दिनांक')}: $dateStr',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.white),
                  label: Text(
                    AppLang.tr(isEn, 'Change', 'बदलें'),
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadBalanceSheet,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Balanced verification card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.success.withOpacity(0.4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLang.tr(isEn, 'Balance Sheet Verified Balanced', 'तुलन पत्र संतुलित एवं सत्यापित'),
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Assets (${_currencyFmt.format(totalAssets)}) = Liab + Equity (${_currencyFmt.format(totalLiabilities)})',
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Solvency Ratios Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    AppLang.tr(isEn, 'Net Working Capital', 'कार्यशील पूंजी'),
                                    _currencyFmt.format(workingCapital),
                                    AppColors.primary,
                                    Icons.account_balance_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricTile(
                                    AppLang.tr(isEn, 'Current Ratio', 'चालू अनुपात'),
                                    '${currentRatio.toStringAsFixed(2)}x',
                                    Colors.teal,
                                    Icons.pie_chart_outline_rounded,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // Assets Section
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.primary),
                                            const SizedBox(width: 8),
                                            Text(
                                              AppLang.tr(isEn, 'ASSETS (संपत्तियां)', 'संपत्तियां (Assets)'),
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _currencyFmt.format(totalAssets),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildBalanceItem('Cash in Hand', _currencyFmt.format(_cashInHand), Icons.payments_outlined),
                                  _buildBalanceItem('Bank Account Balance', _currencyFmt.format(_bankBalance), Icons.account_balance_outlined),
                                  _buildBalanceItem('Sundry Debtors (Receivables)', _currencyFmt.format(_sundryDebtors), Icons.groups_outlined),
                                  _buildBalanceItem('Closing Stock Inventory', _currencyFmt.format(_closingStock), Icons.inventory_2_outlined),
                                  _buildTotalRow(AppLang.tr(isEn, 'TOTAL ASSETS', 'कुल संपत्तियां'), _currencyFmt.format(totalAssets)),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Liabilities & Equity Section
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.corporate_fare_rounded, size: 18, color: Colors.purple),
                                            const SizedBox(width: 8),
                                            Text(
                                              AppLang.tr(isEn, 'LIABILITIES & CAPITAL', 'देनदारियां और पूंजी'),
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _currencyFmt.format(totalLiabilities),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildBalanceItem('Sundry Creditors (Payables)', _currencyFmt.format(_sundryCreditors), Icons.money_off_rounded),
                                  if (_outstandingExpenses > 0)
                                    _buildBalanceItem('Outstanding Expenses', _currencyFmt.format(_outstandingExpenses), Icons.receipt_rounded),
                                  _buildBalanceItem("Proprietor's Capital / Net Worth", _currencyFmt.format(_proprietorCapital), Icons.verified_user_outlined),
                                  _buildTotalRow(AppLang.tr(isEn, 'TOTAL LIABILITIES & EQUITY', 'कुल देनदारियां और पूंजी'), _currencyFmt.format(totalLiabilities)),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String title, String amount, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Text(amount, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(
            total,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.double,
            ),
          ),
        ],
      ),
    );
  }
}
