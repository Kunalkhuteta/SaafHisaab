import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../utils/indian_date_time.dart';

class DailyItemSale {
  final int rank;
  final String itemName;
  final String category;
  final double quantity;
  final String unit;
  final double totalAmount;
  final double avgRate;
  final int billCount;
  final double sharePercent;

  const DailyItemSale({
    required this.rank,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.totalAmount,
    required this.avgRate,
    required this.billCount,
    required this.sharePercent,
  });
}

class DailyItemWiseSaleScreen extends ConsumerStatefulWidget {
  const DailyItemWiseSaleScreen({super.key});

  @override
  ConsumerState<DailyItemWiseSaleScreen> createState() => _DailyItemWiseSaleScreenState();
}

class _DailyItemWiseSaleScreenState extends ConsumerState<DailyItemWiseSaleScreen> {
  DateTime _selectedDate = IndianDateTime.now();
  bool _isLoading = true;
  String? _errorMessage;

  List<DailyItemSale> _items = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortMode = 'amount_desc'; // 'amount_desc', 'qty_desc', 'name_asc'

  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadDailySales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadDailySales();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
      setState(() => _selectedDate = picked);
      _loadDailySales();
    }
  }

  Future<void> _loadDailySales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) throw Exception('Shop not loaded');

      final client = Supabase.instance.client;
      final dateStr = _selectedDate.toIso8601String().split('T')[0];

      // 1. Fetch sales line items for this exact date
      final salesData = await client
          .from('sales')
          .select()
          .eq('shop_id', shop.id)
          .eq('sale_date', dateStr);

      final salesList = List<Map<String, dynamic>>.from(salesData);

      // If no direct sales found by sale_date, try checking bills on that date
      List<Map<String, dynamic>> allRows = salesList;
      if (allRows.isEmpty) {
        final billsOnDate = await client
            .from('bills')
            .select('id')
            .eq('shop_id', shop.id)
            .eq('bill_type', 'sale')
            .eq('bill_date', dateStr);
        final billIds = (billsOnDate as List).map((b) => b['id'].toString()).toList();
        if (billIds.isNotEmpty) {
          final linkedSales = await client
              .from('sales')
              .select()
              .eq('shop_id', shop.id)
              .inFilter('bill_id', billIds);
          allRows = List<Map<String, dynamic>>.from(linkedSales);
        }
      }

      // 2. Aggregate by item name
      final Map<String, _DailyItemAcc> map = {};
      double totalDaySales = 0;

      for (final s in allRows) {
        final name = (s['item_name'] ?? 'Unnamed Item').toString().trim();
        if (name.isEmpty) continue;

        final qty = (s['quantity'] as num?)?.toDouble() ?? 1.0;
        final amt = (s['total_amount'] as num?)?.toDouble() ?? 0.0;
        final unit = (s['unit'] ?? 'pcs').toString();
        final cat = (s['category'] ?? 'General').toString();

        final acc = map.putIfAbsent(name, () => _DailyItemAcc(name: name, category: cat, unit: unit));
        acc.quantity += qty;
        acc.amount += amt;
        acc.count += 1;
        totalDaySales += amt;
      }

      final list = map.values.toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

      _items = list.asMap().entries.map((entry) {
        final acc = entry.value;
        final share = totalDaySales > 0 ? (acc.amount / totalDaySales) * 100 : 0.0;
        final rate = acc.quantity > 0 ? acc.amount / acc.quantity : 0.0;

        return DailyItemSale(
          rank: entry.key + 1,
          itemName: acc.name,
          category: acc.category,
          quantity: acc.quantity,
          unit: acc.unit,
          totalAmount: acc.amount,
          avgRate: rate,
          billCount: acc.count,
          sharePercent: share,
        );
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _shareDailyReport() {
    final dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);
    final total = _items.fold(0.0, (sum, i) => sum + i.totalAmount);
    final totalUnits = _items.fold(0.0, (sum, i) => sum + i.quantity);

    String msg = '📊 *SaafHisaab — Daily Item Wise Sales*\n';
    msg += '📅 Date: $dateStr\n';
    msg += '💰 Total Sales: ${_currencyFmt.format(total)}\n';
    msg += '📦 Total Units Sold: ${totalUnits.toStringAsFixed(0)}\n';
    msg += '────────────────────\n\n';

    for (final item in _items) {
      msg += '#${item.rank} *${item.itemName}*: ${item.quantity.toStringAsFixed(0)} ${item.unit} = ${_currencyFmt.format(item.totalAmount)} (Avg ₹${item.avgRate.toStringAsFixed(0)})\n';
    }

    msg += '\n_Generated via SaafHisaab — Aapki dukaan ka saaf hisaab_';
    Share.share(msg, subject: 'Daily Item Wise Sale - $dateStr');
  }

  List<DailyItemSale> _getFilteredItems() {
    var list = _items;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((i) => i.itemName.toLowerCase().contains(q) || i.category.toLowerCase().contains(q)).toList();
    }

    if (_sortMode == 'amount_desc') {
      list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    } else if (_sortMode == 'qty_desc') {
      list.sort((a, b) => b.quantity.compareTo(a.quantity));
    } else if (_sortMode == 'name_asc') {
      list.sort((a, b) => a.itemName.compareTo(b.itemName));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final filtered = _getFilteredItems();
    final totalSales = _items.fold(0.0, (sum, i) => sum + i.totalAmount);
    final totalQty = _items.fold(0.0, (sum, i) => sum + i.quantity);
    final uniqueItems = _items.length;

    final isToday = IndianDateTime.now().year == _selectedDate.year &&
        IndianDateTime.now().month == _selectedDate.month &&
        IndianDateTime.now().day == _selectedDate.day;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppLang.tr(isEn, 'Daily Item Wise Sale', 'दैनिक आइटम-वार बिक्री'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: AppLang.tr(isEn, 'Share Report', 'शेयर करें'),
            onPressed: _shareDailyReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: AppLang.tr(isEn, 'Refresh', 'ताज़ा करें'),
            onPressed: _loadDailySales,
          ),
        ],
      ),
      body: Column(
        children: [
          // Day Navigator Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _changeDate(-1),
                ),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          isToday
                              ? '${AppLang.tr(isEn, 'Today', 'आज')} (${DateFormat('dd MMM').format(_selectedDate)})'
                              : DateFormat('dd MMMM yyyy').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),

          // Slim KPI Banner
          Container(
            margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLang.tr(isEn, 'Day\'s Total Sales', 'आज की कुल बिक्री'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _currencyFmt.format(totalSales),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${totalQty.toStringAsFixed(0)} ${AppLang.tr(isEn, 'Units', 'यूनिट')}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$uniqueItems ${AppLang.tr(isEn, 'Items', 'आइटम')}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search & Sort Bar
          _buildSearchAndSortBar(isEn),

          // Item Sales List with Minimum Padding
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? _buildErrorView(isEn)
                    : filtered.isEmpty
                        ? _buildEmptyView(isEn)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildCompactDailyItemCard(item);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortBar(bool isEn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: AppLang.tr(isEn, 'Search item name...', 'आइटम का नाम खोजें...'),
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sort_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    _sortMode == 'amount_desc'
                        ? AppLang.tr(isEn, 'Amount', 'राशि')
                        : _sortMode == 'qty_desc'
                            ? AppLang.tr(isEn, 'Quantity', 'मात्रा')
                            : AppLang.tr(isEn, 'A-Z', 'A-Z'),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'amount_desc',
                child: Text(AppLang.tr(isEn, 'Highest Amount', 'ज़्यादा राशि'), style: const TextStyle(fontSize: 12.5)),
              ),
              PopupMenuItem(
                value: 'qty_desc',
                child: Text(AppLang.tr(isEn, 'Highest Quantity', 'ज़्यादा मात्रा'), style: const TextStyle(fontSize: 12.5)),
              ),
              PopupMenuItem(
                value: 'name_asc',
                child: Text(AppLang.tr(isEn, 'Name (A to Z)', 'नाम (A से Z)'), style: const TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Compact Daily Item Card ──
  Widget _buildCompactDailyItemCard(DailyItemSale item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: item.rank == 1 ? const Color(0xFFFEF3C7) : AppColors.primaryBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${item.rank}',
                  style: TextStyle(
                    color: item.rank == 1 ? const Color(0xFFD97706) : AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.unit} sold • Avg ₹${item.avgRate.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFmt.format(item.totalAmount),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${item.sharePercent.toStringAsFixed(1)}% of day',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 5),

          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (item.sharePercent / 100).clamp(0.02, 1.0),
              minHeight: 3,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(
                item.rank == 1 ? Colors.amber.shade600 : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(bool isEn) {
    final dateStr = DateFormat('dd MMMM yyyy').format(_selectedDate);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.remove_shopping_cart_outlined, size: 40, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              AppLang.tr(isEn, 'No Sales Recorded on $dateStr', '$dateStr को कोई बिक्री नहीं हुई'),
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              AppLang.tr(isEn, 'Use the navigation arrows above to view other days.', 'अन्य दिनों की बिक्री देखने के लिए ऊपर दिए गए तीरों का उपयोग करें।'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(bool isEn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
            const SizedBox(height: 10),
            Text(
              AppLang.tr(isEn, 'Failed to load daily sales', 'डेटा लोड करने में त्रुटि'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(_errorMessage ?? '', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadDailySales,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text(AppLang.tr(isEn, 'Retry', 'पुनः प्रयास करें')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyItemAcc {
  final String name;
  final String category;
  final String unit;
  double amount = 0;
  double quantity = 0;
  int count = 0;
  _DailyItemAcc({required this.name, required this.category, required this.unit});
}
