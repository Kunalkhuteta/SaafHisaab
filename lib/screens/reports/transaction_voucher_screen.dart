import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../utils/indian_date_time.dart';

enum VoucherDateFilter {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  prevMonth,
  allTime,
  custom,
}

enum VoucherTypeFilter {
  all,
  sale,
  purchase,
  receipt,
  payment,
  expense,
}

class VoucherItem {
  final String id;
  final String voucherNo;
  final String voucherType; // 'Sale', 'Purchase', 'Receipt', 'Payment', 'Expense'
  final DateTime date;
  final String partyName;
  final double amount;
  final String paymentMode; // 'Cash', 'Online', 'Bank', 'Credit'
  final String notes;
  final bool isInflow; // true if debit/inflow, false if outflow

  const VoucherItem({
    required this.id,
    required this.voucherNo,
    required this.voucherType,
    required this.date,
    required this.partyName,
    required this.amount,
    required this.paymentMode,
    required this.notes,
    required this.isInflow,
  });
}

class TransactionVoucherScreen extends ConsumerStatefulWidget {
  const TransactionVoucherScreen({super.key});

  @override
  ConsumerState<TransactionVoucherScreen> createState() => _TransactionVoucherScreenState();
}

class _TransactionVoucherScreenState extends ConsumerState<TransactionVoucherScreen> {
  VoucherDateFilter _dateFilter = VoucherDateFilter.thisMonth;
  VoucherTypeFilter _typeFilter = VoucherTypeFilter.all;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  bool _isLoading = true;
  String? _errorMessage;

  List<VoucherItem> _allVouchers = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _applyDateFilter(VoucherDateFilter.thisMonth);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyDateFilter(VoucherDateFilter filter) {
    final now = IndianDateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (filter) {
      case VoucherDateFilter.today:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case VoucherDateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day, 0, 0, 0);
        end = DateTime(y.year, y.month, y.day, 23, 59, 59);
        break;
      case VoucherDateFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
        break;
      case VoucherDateFilter.thisMonth:
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        break;
      case VoucherDateFilter.prevMonth:
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        start = DateTime(prevYear, prevMonth, 1, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month, 0).day;
        end = DateTime(prevYear, prevMonth, lastDay, 23, 59, 59);
        break;
      case VoucherDateFilter.allTime:
        start = DateTime(2020, 1, 1, 0, 0, 0);
        break;
      case VoucherDateFilter.custom:
        start = _fromDate;
        end = _toDate;
        break;
    }

    setState(() {
      _dateFilter = filter;
      _fromDate = start;
      _toDate = end;
    });

    _loadVouchers();
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
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
      setState(() {
        _dateFilter = VoucherDateFilter.custom;
        _fromDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadVouchers();
    }
  }

  Future<void> _loadVouchers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) throw Exception('Shop not loaded');

      final client = Supabase.instance.client;
      final fromStr = _fromDate.toIso8601String().split('T')[0];
      final toStr = _toDate.toIso8601String().split('T')[0];

      // 1. Fetch customer lookup
      final customerMap = <String, String>{};
      try {
        final custData = await client
            .from('udhar_customers')
            .select('id, customer_name')
            .eq('shop_id', shop.id);
        for (final c in custData) {
          final id = c['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            customerMap[id] = (c['customer_name'] ?? 'Customer').toString().trim();
          }
        }
      } catch (e) {
        debugPrint('Customer lookup error: $e');
      }

      final List<VoucherItem> vouchers = [];

      // 2. Fetch bills (Sales, Purchases, Expenses)
      try {
        final billsData = await client
            .from('bills')
            .select()
            .eq('shop_id', shop.id)
            .gte('bill_date', fromStr)
            .lte('bill_date', toStr)
            .order('bill_date', ascending: false);

        for (final b in billsData) {
          final id = b['id']?.toString() ?? '';
          final billType = (b['bill_type'] ?? 'purchase').toString().toLowerCase();
          final category = (b['category'] ?? 'General').toString();
          final amount = (b['amount'] as num?)?.toDouble() ?? 0.0;
          final date = IndianDateTime.parse(b['bill_date']);
          final notes = (b['notes'] ?? '').toString();
          final vendor = (b['vendor_name'] ?? '').toString().trim();

          String vType;
          bool isInflow;
          String party;

          if (billType == 'sale') {
            vType = 'Sale';
            isInflow = true;
            party = vendor.isNotEmpty ? vendor : 'Counter Customer';
          } else if (category.toLowerCase().contains('expense') || billType == 'expense') {
            vType = 'Expense';
            isInflow = false;
            party = vendor.isNotEmpty ? vendor : 'Shop Expense';
          } else {
            vType = 'Purchase';
            isInflow = false;
            party = vendor.isNotEmpty ? vendor : 'Supplier';
          }

          String payMode = 'Cash';
          final notesLower = notes.toLowerCase();
          if (notesLower.contains('online') || notesLower.contains('upi')) {
            payMode = 'Online';
          } else if (notesLower.contains('bank') || notesLower.contains('cheque')) {
            payMode = 'Bank';
          } else if (notesLower.contains('credit') || notesLower.contains('__credit_party__')) {
            payMode = 'Credit';
          }

          final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
          vouchers.add(VoucherItem(
            id: id,
            voucherNo: 'VCH-$shortId',
            voucherType: vType,
            date: date,
            partyName: party,
            amount: amount,
            paymentMode: payMode,
            notes: notes,
            isInflow: isInflow,
          ));
        }
      } catch (e) {
        debugPrint('Bills load error: $e');
      }

      // 3. Fetch udhar entries (Receipts & Credit Payments)
      try {
        final udharData = await client
            .from('udhar_entries')
            .select()
            .eq('shop_id', shop.id)
            .gte('entry_date', fromStr)
            .lte('entry_date', toStr)
            .order('entry_date', ascending: false);

        for (final u in udharData) {
          final id = u['id']?.toString() ?? '';
          final cId = u['customer_id']?.toString() ?? '';
          final party = customerMap[cId] ?? 'Customer';
          final entryType = (u['entry_type'] ?? 'credit').toString().toLowerCase();
          final amount = (u['amount'] as num?)?.toDouble() ?? 0.0;
          final date = IndianDateTime.parse(u['entry_date']);
          final notes = (u['note'] ?? '').toString();

          final bool isReceipt = entryType == 'debit'; // payment received
          final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;

          vouchers.add(VoucherItem(
            id: id,
            voucherNo: isReceipt ? 'RCP-$shortId' : 'PMT-$shortId',
            voucherType: isReceipt ? 'Receipt' : 'Payment',
            date: date,
            partyName: party,
            amount: amount,
            paymentMode: 'Cash',
            notes: notes,
            isInflow: isReceipt,
          ));
        }
      } catch (e) {
        debugPrint('Udhar entries load error: $e');
      }

      // Sort newest first
      vouchers.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _allVouchers = vouchers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<VoucherItem> get _filteredVouchers {
    return _allVouchers.where((v) {
      if (_typeFilter != VoucherTypeFilter.all) {
        switch (_typeFilter) {
          case VoucherTypeFilter.sale:
            if (v.voucherType != 'Sale') return false;
            break;
          case VoucherTypeFilter.purchase:
            if (v.voucherType != 'Purchase') return false;
            break;
          case VoucherTypeFilter.receipt:
            if (v.voucherType != 'Receipt') return false;
            break;
          case VoucherTypeFilter.payment:
            if (v.voucherType != 'Payment') return false;
            break;
          case VoucherTypeFilter.expense:
            if (v.voucherType != 'Expense') return false;
            break;
          case VoucherTypeFilter.all:
            break;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchParty = v.partyName.toLowerCase().contains(q);
        final matchVoucher = v.voucherNo.toLowerCase().contains(q);
        final matchNotes = v.notes.toLowerCase().contains(q);
        final matchAmount = v.amount.toString().contains(q);
        if (!matchParty && !matchVoucher && !matchNotes && !matchAmount) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _shareVoucherSummary() {
    final list = _filteredVouchers;
    final totalInflow = list.where((v) => v.isInflow).fold(0.0, (sum, v) => sum + v.amount);
    final totalOutflow = list.where((v) => !v.isInflow).fold(0.0, (sum, v) => sum + v.amount);
    final net = totalInflow - totalOutflow;

    final fromStr = DateFormat('dd MMM yyyy').format(_fromDate);
    final toStr = DateFormat('dd MMM yyyy').format(_toDate);

    final sb = StringBuffer();
    sb.writeln('📑 TRANSACTION VOUCHER REPORT');
    sb.writeln('Period: $fromStr to $toStr');
    sb.writeln('Total Vouchers: ${list.length}');
    sb.writeln('Total Inflow (Receipts/Sales): ${_currencyFmt.format(totalInflow)}');
    sb.writeln('Total Outflow (Purchases/Expenses): ${_currencyFmt.format(totalOutflow)}');
    sb.writeln('Net Flow: ${_currencyFmt.format(net)}');
    sb.writeln('-----------------------------------');
    for (int i = 0; i < (list.length > 25 ? 25 : list.length); i++) {
      final v = list[i];
      final dateStr = DateFormat('dd/MM/yy').format(v.date);
      final sign = v.isInflow ? '+' : '-';
      sb.writeln('${v.voucherNo} | $dateStr | ${v.partyName} | [${v.voucherType}] | $sign${_currencyFmt.format(v.amount)}');
    }
    if (list.length > 25) {
      sb.writeln('... and ${list.length - 25} more vouchers.');
    }
    sb.writeln('Generated via SaafHisaab App');

    Share.share(sb.toString(), subject: 'Transaction Voucher Report ($fromStr - $toStr)');
  }

  void _showVoucherDetails(VoucherItem v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final dateStr = DateFormat('dd MMMM yyyy, hh:mm a').format(v.date);
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    v.voucherNo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  _buildVoucherBadge(v.voucherType),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow('Date & Time', dateStr),
              _buildDetailRow('Party / Name', v.partyName),
              _buildDetailRow('Payment Mode', v.paymentMode),
              _buildDetailRow(
                'Amount',
                _currencyFmt.format(v.amount),
                valueColor: v.isInflow ? AppColors.success : AppColors.error,
                isBold: true,
              ),
              _buildDetailRow('Flow Type', v.isInflow ? 'Inflow (Credit to Shop)' : 'Outflow (Debit from Shop)'),
              if (v.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Notes / Remarks:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    v.notes,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Share.share(
                      '🧾 Voucher: ${v.voucherNo}\n'
                      'Type: ${v.voucherType}\n'
                      'Party: ${v.partyName}\n'
                      'Date: $dateStr\n'
                      'Amount: ${_currencyFmt.format(v.amount)}\n'
                      'Mode: ${v.paymentMode}\n'
                      '${v.notes.isNotEmpty ? 'Note: ${v.notes}\n' : ''}'
                      'Generated via SaafHisaab',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share Voucher Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherBadge(String type) {
    Color bg;
    Color fg;
    switch (type) {
      case 'Sale':
        bg = AppColors.success.withOpacity(0.12);
        fg = AppColors.success;
        break;
      case 'Receipt':
        bg = Colors.teal.withOpacity(0.12);
        fg = Colors.teal.shade800;
        break;
      case 'Purchase':
        bg = Colors.blue.withOpacity(0.12);
        fg = AppColors.primary;
        break;
      case 'Payment':
        bg = Colors.orange.withOpacity(0.12);
        fg = Colors.orange.shade800;
        break;
      case 'Expense':
        bg = AppColors.error.withOpacity(0.12);
        fg = AppColors.error;
        break;
      default:
        bg = Colors.grey.withOpacity(0.12);
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final vouchers = _filteredVouchers;

    final double totalInflow = vouchers.where((v) => v.isInflow).fold(0.0, (sum, v) => sum + v.amount);
    final double totalOutflow = vouchers.where((v) => !v.isInflow).fold(0.0, (sum, v) => sum + v.amount);
    final double netBalance = totalInflow - totalOutflow;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'Transaction Voucher', 'लेन-देन वाउचर')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: AppLang.tr(isEn, 'Share Report', 'रिपोर्ट साझा करें'),
            onPressed: vouchers.isEmpty ? null : _shareVoucherSummary,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Filter Bar
          _buildDateFilterBar(isEn),

          // Search and Voucher Type Filter chips
          _buildFilterChips(isEn),

          // Summary KPI Header
          _buildSummaryCards(isEn, vouchers.length, totalInflow, totalOutflow, netBalance),

          // Voucher List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadVouchers,
                                child: Text(AppLang.tr(isEn, 'Retry', 'पुनः प्रयास करें')),
                              ),
                            ],
                          ),
                        ),
                      )
                    : vouchers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 60, color: AppColors.textHint.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  AppLang.tr(isEn, 'No vouchers found for period', 'इस अवधि के लिए कोई वाउचर नहीं मिला'),
                                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _loadVouchers,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: vouchers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final v = vouchers[index];
                                return _buildVoucherCard(v);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterBar(bool isEn) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildDateChip(VoucherDateFilter.today, AppLang.tr(isEn, 'Today', 'आज')),
            _buildDateChip(VoucherDateFilter.yesterday, AppLang.tr(isEn, 'Yesterday', 'कल')),
            _buildDateChip(VoucherDateFilter.thisWeek, AppLang.tr(isEn, 'This Week', 'इस हफ्ते')),
            _buildDateChip(VoucherDateFilter.thisMonth, AppLang.tr(isEn, 'This Month', 'इस महीने')),
            _buildDateChip(VoucherDateFilter.prevMonth, AppLang.tr(isEn, 'Last Month', 'पिछला महीना')),
            _buildDateChip(VoucherDateFilter.allTime, AppLang.tr(isEn, 'All Time', 'कुल अवधि')),
            _buildDateChip(VoucherDateFilter.custom, AppLang.tr(isEn, 'Custom', 'कस्टम'), isCustom: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(VoucherDateFilter filter, String label, {bool isCustom = false}) {
    final isSelected = _dateFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          if (isCustom) {
            _selectCustomDateRange();
          } else {
            _applyDateFilter(filter);
          }
        },
        backgroundColor: Colors.white.withOpacity(0.15),
        selectedColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : Colors.white,
        ),
        checkmarkColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildFilterChips(bool isEn) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Search box
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: AppLang.tr(isEn, 'Search party, voucher no, or amount...', 'पार्टी, वाउचर या राशि खोजें...'),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeChip(VoucherTypeFilter.all, AppLang.tr(isEn, 'All Types', 'सभी प्रकार')),
                _buildTypeChip(VoucherTypeFilter.sale, AppLang.tr(isEn, 'Sales', 'बिक्री')),
                _buildTypeChip(VoucherTypeFilter.receipt, AppLang.tr(isEn, 'Receipts', 'रसीद')),
                _buildTypeChip(VoucherTypeFilter.purchase, AppLang.tr(isEn, 'Purchases', 'खरीद')),
                _buildTypeChip(VoucherTypeFilter.payment, AppLang.tr(isEn, 'Payments', 'भुगतान')),
                _buildTypeChip(VoucherTypeFilter.expense, AppLang.tr(isEn, 'Expenses', 'खर्चे')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(VoucherTypeFilter type, String label) {
    final isSelected = _typeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _typeFilter = type),
        backgroundColor: AppColors.background,
        selectedColor: AppColors.primary.withOpacity(0.12),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isEn, int count, double inflow, double outflow, double net) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppLang.tr(isEn, 'Total Vouchers', 'कुल वाउचर')}: $count',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (net >= 0 ? AppColors.success : AppColors.error).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${AppLang.tr(isEn, 'Net', 'शुद्ध')}: ${_currencyFmt.format(net)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: net >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLang.tr(isEn, 'Total Inflow (Cr)', 'कुल आवक'),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${_currencyFmt.format(inflow)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ],
                ),
              ),
              Container(height: 28, width: 1, color: AppColors.border),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLang.tr(isEn, 'Total Outflow (Dr)', 'कुल जावक'),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '-${_currencyFmt.format(outflow)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(VoucherItem v) {
    final dateStr = DateFormat('dd MMM yyyy').format(v.date);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showVoucherDetails(v),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (v.isInflow ? AppColors.success : AppColors.error).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  v.isInflow ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: v.isInflow ? AppColors.success : AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          v.partyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildVoucherBadge(v.voucherType),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${v.voucherNo} • $dateStr • ${v.paymentMode}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${v.isInflow ? '+' : '-'}${_currencyFmt.format(v.amount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: v.isInflow ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textHint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
