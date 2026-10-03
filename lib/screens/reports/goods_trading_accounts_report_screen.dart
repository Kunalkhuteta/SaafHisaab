import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../utils/indian_date_time.dart';

enum GoodsDateFilter {
  thisMonth,
  prevMonth,
  thisQuarter,
  thisYear,
  allTime,
  custom,
}

enum GoodsSortBy {
  highestProfit,
  mostSold,
  highestRevenue,
  highestStockValue,
  lowestStock,
}

class ItemTradingSummary {
  final String id;
  final String itemName;
  final String category;
  final String unit;
  final double buyingPrice;
  final double sellingPrice;
  final double currentStock;
  final double stockValue;
  final double unitsSold;
  final double salesRevenue;
  final double costOfUnitsSold;
  final double grossProfit;
  final double profitMargin;

  const ItemTradingSummary({
    required this.id,
    required this.itemName,
    required this.category,
    required this.unit,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.stockValue,
    required this.unitsSold,
    required this.salesRevenue,
    required this.costOfUnitsSold,
    required this.grossProfit,
    required this.profitMargin,
  });
}

class GoodsTradingAccountsReportScreen extends ConsumerStatefulWidget {
  const GoodsTradingAccountsReportScreen({super.key});

  @override
  ConsumerState<GoodsTradingAccountsReportScreen> createState() =>
      _GoodsTradingAccountsReportScreenState();
}

class _GoodsTradingAccountsReportScreenState
    extends ConsumerState<GoodsTradingAccountsReportScreen> {
  GoodsDateFilter _dateFilter = GoodsDateFilter.thisMonth;
  GoodsSortBy _sortBy = GoodsSortBy.highestProfit;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  bool _isLoading = true;
  String? _errorMessage;

  List<ItemTradingSummary> _items = [];
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
    _applyDateFilter(GoodsDateFilter.thisMonth);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyDateFilter(GoodsDateFilter filter) {
    final now = IndianDateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (filter) {
      case GoodsDateFilter.thisMonth:
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        break;
      case GoodsDateFilter.prevMonth:
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        start = DateTime(prevYear, prevMonth, 1, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month, 0).day;
        end = DateTime(prevYear, prevMonth, lastDay, 23, 59, 59);
        break;
      case GoodsDateFilter.thisQuarter:
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        start = DateTime(now.year, quarterStartMonth, 1, 0, 0, 0);
        break;
      case GoodsDateFilter.thisYear:
        // Indian Financial Year April 1 to March 31
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        start = DateTime(fyStartYear, 4, 1, 0, 0, 0);
        break;
      case GoodsDateFilter.allTime:
        start = DateTime(2020, 1, 1, 0, 0, 0);
        break;
      case GoodsDateFilter.custom:
        start = _fromDate;
        end = _toDate;
        break;
    }

    setState(() {
      _dateFilter = filter;
      _fromDate = start;
      _toDate = end;
    });

    _loadData();
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
        _dateFilter = GoodsDateFilter.custom;
        _fromDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
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

      // 1. Fetch stock items
      final stockData = await client
          .from('stock_items')
          .select()
          .eq('shop_id', shop.id);

      // 2. Fetch sales in the chosen date range
      final salesData = await client
          .from('sales')
          .select()
          .eq('shop_id', shop.id)
          .gte('sale_date', fromStr)
          .lte('sale_date', toStr);

      // Aggregate sales by lowercase item name and stock_item_id
      final salesMap = <String, _ItemSaleStat>{};
      for (final s in salesData) {
        final name = (s['item_name'] ?? '').toString().trim().toLowerCase();
        final stockId = (s['stock_item_id'] ?? '').toString();
        final qty = (s['quantity'] as num?)?.toDouble() ?? 1.0;
        final amt = (s['total_amount'] as num?)?.toDouble() ?? 0.0;

        final key = stockId.isNotEmpty ? stockId : name;
        final stat = salesMap.putIfAbsent(key, () => _ItemSaleStat());
        stat.qtySold += qty;
        stat.totalRevenue += amt;
      }

      final List<ItemTradingSummary> items = [];

      for (final s in stockData) {
        final id = s['id']?.toString() ?? '';
        final name = (s['item_name'] ?? '').toString().trim();
        final category = (s['category'] ?? 'General').toString();
        final unit = (s['unit'] ?? 'piece').toString();
        final currentQty = (s['current_quantity'] as num?)?.toDouble() ?? 0.0;
        final buyPrice = (s['buying_price'] as num?)?.toDouble() ?? 0.0;
        final sellPrice = (s['selling_price'] as num?)?.toDouble() ?? 0.0;

        final stat = salesMap[id] ?? salesMap[name.toLowerCase()] ?? _ItemSaleStat();
        final unitsSold = stat.qtySold;
        final revenue = stat.totalRevenue;
        final costOfSold = unitsSold * buyPrice;
        final profit = revenue - costOfSold;
        final margin = revenue > 0 ? (profit / revenue) * 100 : 0.0;
        final stockVal = currentQty * buyPrice;

        items.add(ItemTradingSummary(
          id: id,
          itemName: name,
          category: category,
          unit: unit,
          buyingPrice: buyPrice,
          sellingPrice: sellPrice,
          currentStock: currentQty,
          stockValue: stockVal,
          unitsSold: unitsSold,
          salesRevenue: revenue,
          costOfUnitsSold: costOfSold,
          grossProfit: profit,
          profitMargin: margin,
        ));
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<ItemTradingSummary> get _filteredAndSortedItems {
    final list = _items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.itemName.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
    }).toList();

    switch (_sortBy) {
      case GoodsSortBy.highestProfit:
        list.sort((a, b) => b.grossProfit.compareTo(a.grossProfit));
        break;
      case GoodsSortBy.mostSold:
        list.sort((a, b) => b.unitsSold.compareTo(a.unitsSold));
        break;
      case GoodsSortBy.highestRevenue:
        list.sort((a, b) => b.salesRevenue.compareTo(a.salesRevenue));
        break;
      case GoodsSortBy.highestStockValue:
        list.sort((a, b) => b.stockValue.compareTo(a.stockValue));
        break;
      case GoodsSortBy.lowestStock:
        list.sort((a, b) => a.currentStock.compareTo(b.currentStock));
        break;
    }

    return list;
  }

  void _shareSummary() {
    final list = _filteredAndSortedItems;
    final totalStockVal = _items.fold(0.0, (sum, i) => sum + i.stockValue);
    final totalRev = _items.fold(0.0, (sum, i) => sum + i.salesRevenue);
    final totalProfit = _items.fold(0.0, (sum, i) => sum + i.grossProfit);
    final overallMargin = totalRev > 0 ? (totalProfit / totalRev) * 100 : 0.0;

    final fromStr = DateFormat('dd MMM yyyy').format(_fromDate);
    final toStr = DateFormat('dd MMM yyyy').format(_toDate);

    final sb = StringBuffer();
    sb.writeln('📦 GOODS TRADING ACCOUNT / ITEM WISE STOCK REPORT');
    sb.writeln('Period: $fromStr to $toStr');
    sb.writeln('Total Items Tracked: ${_items.length}');
    sb.writeln('Total Stock Valuation: ${_currencyFmt.format(totalStockVal)}');
    sb.writeln('Total Sales Revenue: ${_currencyFmt.format(totalRev)}');
    sb.writeln('Total Gross Profit: ${_currencyFmt.format(totalProfit)} (${overallMargin.toStringAsFixed(1)}%)');
    sb.writeln('-----------------------------------');
    for (int i = 0; i < (list.length > 20 ? 20 : list.length); i++) {
      final item = list[i];
      sb.writeln(
        '${i + 1}. ${item.itemName} [${item.category}]\n'
        '   Stock: ${item.currentStock} ${item.unit} (${_currencyFmt.format(item.stockValue)})\n'
        '   Sold: ${item.unitsSold} units | Rev: ${_currencyFmt.format(item.salesRevenue)} | Profit: ${_currencyFmt.format(item.grossProfit)} (${item.profitMargin.toStringAsFixed(1)}%)\n',
      );
    }
    sb.writeln('Generated via SaafHisaab');

    Share.share(sb.toString(), subject: 'Goods Trading Accounts Report');
  }

  void _showItemModal(ItemTradingSummary item, bool isEn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.itemName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(item.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow(AppLang.tr(isEn, 'Buying Price', 'खरीद मूल्य'), _currencyFmt.format(item.buyingPrice)),
              _buildDetailRow(AppLang.tr(isEn, 'Selling Price', 'बिक्री मूल्य'), _currencyFmt.format(item.sellingPrice)),
              _buildDetailRow(
                AppLang.tr(isEn, 'Current Stock in Hand', 'वर्तमान स्टॉक'),
                '${item.currentStock} ${item.unit}',
                isBold: true,
              ),
              _buildDetailRow(
                AppLang.tr(isEn, 'Stock Asset Valuation', 'स्टॉक संपत्ति मूल्य'),
                _currencyFmt.format(item.stockValue),
                isBold: true,
              ),
              const Divider(height: 20),
              _buildDetailRow(
                AppLang.tr(isEn, 'Units Sold in Period', 'अवधि में बिके यूनिट्स'),
                '${item.unitsSold} ${item.unit}',
              ),
              _buildDetailRow(
                AppLang.tr(isEn, 'Sales Revenue Generated', 'प्राप्त कुल बिक्री'),
                _currencyFmt.format(item.salesRevenue),
              ),
              _buildDetailRow(
                AppLang.tr(isEn, 'Cost of Goods Sold (COGS)', 'माल की लागत'),
                _currencyFmt.format(item.costOfUnitsSold),
              ),
              _buildDetailRow(
                AppLang.tr(isEn, 'Gross Trading Profit', 'कुल सकल लाभ'),
                _currencyFmt.format(item.grossProfit),
                valueColor: item.grossProfit >= 0 ? AppColors.success : AppColors.error,
                isBold: true,
              ),
              _buildDetailRow(
                AppLang.tr(isEn, 'Gross Margin %', 'मार्जिन %'),
                '${item.profitMargin.toStringAsFixed(1)}%',
                valueColor: item.grossProfit >= 0 ? AppColors.success : AppColors.error,
                isBold: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Share.share(
                      '📦 Item: ${item.itemName} (${item.category})\n'
                      'Stock: ${item.currentStock} ${item.unit} (${_currencyFmt.format(item.stockValue)})\n'
                      'Sold: ${item.unitsSold} ${item.unit}\n'
                      'Revenue: ${_currencyFmt.format(item.salesRevenue)}\n'
                      'Profit: ${_currencyFmt.format(item.grossProfit)} (${item.profitMargin.toStringAsFixed(1)}%)\n'
                      'Generated via SaafHisaab',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(AppLang.tr(isEn, 'Share Item Report', 'आइटम रिपोर्ट साझा करें')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final items = _filteredAndSortedItems;

    final totalStockVal = _items.fold(0.0, (sum, i) => sum + i.stockValue);
    final totalRev = _items.fold(0.0, (sum, i) => sum + i.salesRevenue);
    final totalProfit = _items.fold(0.0, (sum, i) => sum + i.grossProfit);
    final overallMargin = totalRev > 0 ? (totalProfit / totalRev) * 100 : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'Goods Trading Accounts', 'माल व्यापार खाता')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: AppLang.tr(isEn, 'Share Report', 'रिपोर्ट साझा करें'),
            onPressed: items.isEmpty ? null : _shareSummary,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Filter Row
          _buildDateFilterBar(isEn),

          // Search and Sort Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: AppLang.tr(isEn, 'Search item or category...', 'सामान या श्रेणी खोजें...'),
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
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${items.length} ${AppLang.tr(isEn, 'items', 'सामान')}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    DropdownButton<GoodsSortBy>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.sort_rounded, size: 18, color: AppColors.primary),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                      items: [
                        DropdownMenuItem(value: GoodsSortBy.highestProfit, child: Text(AppLang.tr(isEn, 'Highest Profit', 'सर्वाधिक लाभ'))),
                        DropdownMenuItem(value: GoodsSortBy.mostSold, child: Text(AppLang.tr(isEn, 'Most Sold Units', 'सबसे ज्यादा बिक्री'))),
                        DropdownMenuItem(value: GoodsSortBy.highestRevenue, child: Text(AppLang.tr(isEn, 'Highest Revenue', 'सर्वाधिक आय'))),
                        DropdownMenuItem(value: GoodsSortBy.highestStockValue, child: Text(AppLang.tr(isEn, 'Highest Stock Value', 'अधिकतम स्टॉक मूल्य'))),
                        DropdownMenuItem(value: GoodsSortBy.lowestStock, child: Text(AppLang.tr(isEn, 'Lowest Stock', 'न्यूनतम स्टॉक'))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _sortBy = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // KPI Cards
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLang.tr(isEn, 'Stock Valuation', 'स्टॉक संपत्ति मूल्य'),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(_currencyFmt.format(totalStockVal),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
                Container(height: 32, width: 1, color: AppColors.border),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLang.tr(isEn, 'Period Revenue', 'अवधि बिक्री'),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(_currencyFmt.format(totalRev),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                Container(height: 32, width: 1, color: AppColors.border),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLang.tr(isEn, 'Gross Profit', 'सकल लाभ'),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFmt.format(totalProfit),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: totalProfit >= 0 ? AppColors.success : AppColors.error,
                        ),
                      ),
                      Text(
                        '${overallMargin.toStringAsFixed(1)}% margin',
                        style: const TextStyle(fontSize: 9.5, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.store_rounded, size: 54, color: AppColors.textHint.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  AppLang.tr(isEn, 'No stock items found', 'कोई स्टॉक आइटम नहीं मिला'),
                                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _loadData,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _buildItemCard(item, isEn);
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
            _buildDateChip(GoodsDateFilter.thisMonth, AppLang.tr(isEn, 'This Month', 'इस महीने')),
            _buildDateChip(GoodsDateFilter.prevMonth, AppLang.tr(isEn, 'Last Month', 'पिछला महीना')),
            _buildDateChip(GoodsDateFilter.thisQuarter, AppLang.tr(isEn, 'This Quarter', 'यह तिमाही')),
            _buildDateChip(GoodsDateFilter.thisYear, AppLang.tr(isEn, 'Financial Year', 'वित्तीय वर्ष')),
            _buildDateChip(GoodsDateFilter.allTime, AppLang.tr(isEn, 'All Time', 'कुल अवधि')),
            _buildDateChip(GoodsDateFilter.custom, AppLang.tr(isEn, 'Custom', 'कस्टम'), isCustom: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(GoodsDateFilter filter, String label, {bool isCustom = false}) {
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

  Widget _buildItemCard(ItemTradingSummary item, bool isEn) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showItemModal(item, isEn),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (item.grossProfit >= 0 ? AppColors.success : AppColors.error).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.grossProfit >= 0 ? '+' : ''}${_currencyFmt.format(item.grossProfit)} (${item.profitMargin.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: item.grossProfit >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${AppLang.tr(isEn, 'Stock', 'स्टॉक')}: ${item.currentStock} ${item.unit} (${_currencyFmt.format(item.stockValue)})',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: AppColors.border)),
                  const SizedBox(width: 8),
                  Text(
                    '${AppLang.tr(isEn, 'Sold', 'बिका')}: ${item.unitsSold} ${item.unit}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Buy: ${_currencyFmt.format(item.buyingPrice)} | Sell: ${_currencyFmt.format(item.sellingPrice)}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textHint),
                  ),
                  Row(
                    children: [
                      Text(
                        'Rev: ${_currencyFmt.format(item.salesRevenue)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textHint),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemSaleStat {
  double qtySold = 0.0;
  double totalRevenue = 0.0;
}
