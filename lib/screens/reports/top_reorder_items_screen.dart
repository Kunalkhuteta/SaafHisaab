import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../utils/indian_date_time.dart';

enum ReorderFilter {
  all,
  outOfStock,
  lowStock,
  highDemand,
}

class ReorderItem {
  final int rank;
  final String id;
  final String name;
  final String category;
  final String unit;
  final double currentStock;
  final double totalSoldQty;
  final int ordersCount;
  final double sellingPrice;
  final DateTime? lastSoldDate;
  final int inactiveDays;
  final double suggestedReorderQty;

  const ReorderItem({
    required this.rank,
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.currentStock,
    required this.totalSoldQty,
    required this.ordersCount,
    required this.sellingPrice,
    this.lastSoldDate,
    this.inactiveDays = 0,
    required this.suggestedReorderQty,
  });

  bool get isOutOfStock => currentStock <= 0;
  bool get isLowStock => currentStock > 0 && currentStock <= 5;

  String get lastSoldDateFormatted {
    if (lastSoldDate == null) return 'Never sold';
    return DateFormat('dd MMM yyyy').format(lastSoldDate!);
  }

  String get inactiveStatusText {
    if (lastSoldDate == null) return 'No sales';
    if (inactiveDays <= 0) return 'Sold Today';
    if (inactiveDays == 1) return '1d ago';
    return '${inactiveDays}d ago';
  }
}

class TopReorderItemsScreen extends ConsumerStatefulWidget {
  const TopReorderItemsScreen({super.key});

  @override
  ConsumerState<TopReorderItemsScreen> createState() => _TopReorderItemsScreenState();
}

class _TopReorderItemsScreenState extends ConsumerState<TopReorderItemsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<ReorderItem> _allItems = [];
  ReorderFilter _selectedFilter = ReorderFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortMode = 'urgency'; // 'urgency', 'stock_asc', 'sales_desc', 'name_asc'

  @override
  void initState() {
    super.initState();
    _loadReorderData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReorderData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) throw Exception('Shop not loaded');

      final client = Supabase.instance.client;
      final now = IndianDateTime.now();

      // 1. Fetch Item Master items with current stock
      final itemsResponse = await client
          .from('item_master')
          .select()
          .eq('shop_id', shop.id);
      final rawItems = List<Map<String, dynamic>>.from(itemsResponse);

      // 2. Fetch sales activity history for sales velocity & reorder frequency
      final salesResponse = await client
          .from('sales')
          .select('item_name, quantity, selling_price, total_amount, sale_date')
          .eq('shop_id', shop.id)
          .order('sale_date', ascending: false)
          .limit(2000);
      final rawSales = List<Map<String, dynamic>>.from(salesResponse);

      // Aggregate sales by item name
      final Map<String, _ItemSaleStats> statsMap = {};
      for (final s in rawSales) {
        final name = (s['item_name'] ?? '').toString().trim().toLowerCase();
        if (name.isEmpty) continue;

        final qty = (s['quantity'] as num?)?.toDouble() ?? 1.0;
        final price = (s['selling_price'] as num?)?.toDouble() ?? 0.0;
        final date = IndianDateTime.parse(s['sale_date']);

        final stat = statsMap.putIfAbsent(name, () => _ItemSaleStats());
        stat.totalSold += qty.abs();
        stat.ordersCount += 1;
        if (stat.lastSoldDate == null || date.isAfter(stat.lastSoldDate!)) {
          stat.lastSoldDate = date;
        }
        if (price > 0 && stat.lastPrice == 0) {
          stat.lastPrice = price;
        }
      }

      // Build unified list of items with stock and demand metrics
      final List<ReorderItem> processed = [];
      for (int i = 0; i < rawItems.length; i++) {
        final it = rawItems[i];
        final id = it['id']?.toString() ?? '';
        final name = (it['item_name'] ?? 'Unnamed Item').toString().trim();
        final cat = (it['item_category'] ?? it['item_group'] ?? 'General').toString();
        final stock = (it['current_stock'] as num?)?.toDouble() ?? 0.0;

        final key = name.toLowerCase();
        final stat = statsMap[key];
        final soldQty = stat?.totalSold ?? 0.0;
        final orders = stat?.ordersCount ?? 0;
        final lastDate = stat?.lastSoldDate;
        final price = stat?.lastPrice ?? 0.0;
        final inactiveDays = lastDate != null ? now.difference(lastDate).inDays : 999;

        // Suggested reorder = target 2x weekly velocity or minimum 10 pcs
        double suggested = (soldQty > 0 ? (soldQty / 2).ceilToDouble() : 10.0);
        if (suggested < 5) suggested = 5.0;

        processed.add(ReorderItem(
          rank: i + 1,
          id: id,
          name: name,
          category: cat,
          unit: 'pcs',
          currentStock: stock,
          totalSoldQty: soldQty,
          ordersCount: orders,
          sellingPrice: price,
          lastSoldDate: lastDate,
          inactiveDays: inactiveDays,
          suggestedReorderQty: suggested,
        ));
      }

      // Default sort by Urgency (Out of stock first, then low stock, then high demand)
      processed.sort((a, b) {
        if (a.isOutOfStock && !b.isOutOfStock) return -1;
        if (!a.isOutOfStock && b.isOutOfStock) return 1;
        if (a.isLowStock && !b.isLowStock) return -1;
        if (!a.isLowStock && b.isLowStock) return 1;
        return b.totalSoldQty.compareTo(a.totalSoldQty);
      });

      _allItems = processed.asMap().entries.map((e) => ReorderItem(
        rank: e.key + 1,
        id: e.value.id,
        name: e.value.name,
        category: e.value.category,
        unit: e.value.unit,
        currentStock: e.value.currentStock,
        totalSoldQty: e.value.totalSoldQty,
        ordersCount: e.value.ordersCount,
        sellingPrice: e.value.sellingPrice,
        lastSoldDate: e.value.lastSoldDate,
        inactiveDays: e.value.inactiveDays,
        suggestedReorderQty: e.value.suggestedReorderQty,
      )).toList();

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

  List<ReorderItem> _getFilteredItems() {
    var list = _allItems;

    switch (_selectedFilter) {
      case ReorderFilter.outOfStock:
        list = list.where((i) => i.isOutOfStock).toList();
        break;
      case ReorderFilter.lowStock:
        list = list.where((i) => i.isLowStock).toList();
        break;
      case ReorderFilter.highDemand:
        list = list.where((i) => i.totalSoldQty > 0).toList();
        break;
      case ReorderFilter.all:
        break;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q)).toList();
    }

    if (_sortMode == 'stock_asc') {
      list.sort((a, b) => a.currentStock.compareTo(b.currentStock));
    } else if (_sortMode == 'sales_desc') {
      list.sort((a, b) => b.totalSoldQty.compareTo(a.totalSoldQty));
    } else if (_sortMode == 'name_asc') {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    return list;
  }

  void _shareReorderList() {
    final filtered = _getFilteredItems();
    if (filtered.isEmpty) return;

    String msg = '📋 *SaafHisaab — Purchase Re-Order List*\n';
    msg += '📅 Date: ${DateFormat('dd MMM yyyy').format(IndianDateTime.now())}\n';
    msg += '────────────────────\n\n';

    int idx = 1;
    for (final item in filtered) {
      final stockLabel = item.isOutOfStock
          ? '🔴 Out of Stock'
          : item.isLowStock
              ? '🟡 Low Stock (${item.currentStock.toStringAsFixed(0)})'
              : '🟢 Stock: ${item.currentStock.toStringAsFixed(0)}';

      msg += '$idx. *${item.name}*\n';
      msg += '   • Status: $stockLabel\n';
      msg += '   • Suggested Order: *${item.suggestedReorderQty.toStringAsFixed(0)} ${item.unit}*\n\n';
      idx++;
    }

    msg += '_Generated via SaafHisaab — Aapki dukaan ka saaf hisaab_';
    Share.share(msg, subject: 'Purchase Re-Order List');
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final filteredItems = _getFilteredItems();

    final outOfStockCount = _allItems.where((i) => i.isOutOfStock).length;
    final lowStockCount = _allItems.where((i) => i.isLowStock).length;
    final totalReorderNeeded = outOfStockCount + lowStockCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppLang.tr(isEn, 'Top Re-Order Items', 'पुनः ऑर्डर करने योग्य उत्पाद'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: AppLang.tr(isEn, 'Share Re-Order List', 'ऑर्डर सूची शेयर करें'),
            onPressed: _shareReorderList,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: AppLang.tr(isEn, 'Refresh', 'ताज़ा करें'),
            onPressed: _loadReorderData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Slim Reorder KPI Header
          Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.15),
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
                      AppLang.tr(isEn, 'Reorder Urgency', 'ऑर्डर आवश्यकता'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$totalReorderNeeded ${AppLang.tr(isEn, 'Items Urgent', 'उत्पाद तत्काल')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildKpiChip('🔴 $outOfStockCount ${AppLang.tr(isEn, 'Out', 'खत्म')}'),
                    const SizedBox(width: 6),
                    _buildKpiChip('🟡 $lowStockCount ${AppLang.tr(isEn, 'Low', 'कम')}'),
                  ],
                ),
              ],
            ),
          ),

          // Filter Chips Bar
          _buildFilterChipsBar(isEn, outOfStockCount, lowStockCount),

          // Compact Search & Sort Bar
          _buildSearchAndSortBar(isEn),

          // Items List with Minimum Padding
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? _buildErrorView(isEn)
                    : filteredItems.isEmpty
                        ? _buildEmptyView(isEn)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return _buildCompactReorderCard(item, isEn);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildFilterChipsBar(bool isEn, int outCount, int lowCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chipItem(
              filter: ReorderFilter.all,
              label: '${AppLang.tr(isEn, 'All Items', 'सभी')} (${_allItems.length})',
            ),
            const SizedBox(width: 6),
            _chipItem(
              filter: ReorderFilter.outOfStock,
              label: '🔴 ${AppLang.tr(isEn, 'Out of Stock', 'स्टॉक खत्म')} ($outCount)',
            ),
            const SizedBox(width: 6),
            _chipItem(
              filter: ReorderFilter.lowStock,
              label: '🟡 ${AppLang.tr(isEn, 'Low Stock', 'कम स्टॉक')} ($lowCount)',
            ),
            const SizedBox(width: 6),
            _chipItem(
              filter: ReorderFilter.highDemand,
              label: '🔥 ${AppLang.tr(isEn, 'High Demand', 'अधिक मांग')}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipItem({required ReorderFilter filter, required String label}) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 11.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      onSelected: (_) => setState(() => _selectedFilter = filter),
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
                  hintText: AppLang.tr(isEn, 'Search items...', 'उत्पाद खोजें...'),
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
                    _sortMode == 'urgency'
                        ? AppLang.tr(isEn, 'Urgency', 'प्राथमिकता')
                        : _sortMode == 'stock_asc'
                            ? AppLang.tr(isEn, 'Stock', 'स्टॉक')
                            : _sortMode == 'sales_desc'
                                ? AppLang.tr(isEn, 'Demand', 'बिक्री')
                                : AppLang.tr(isEn, 'A-Z', 'A-Z'),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'urgency',
                child: Text(AppLang.tr(isEn, 'Urgency (Out of stock first)', 'प्राथमिकता अनुसार'), style: const TextStyle(fontSize: 12.5)),
              ),
              PopupMenuItem(
                value: 'stock_asc',
                child: Text(AppLang.tr(isEn, 'Lowest Stock First', 'न्यूनतम स्टॉक पहले'), style: const TextStyle(fontSize: 12.5)),
              ),
              PopupMenuItem(
                value: 'sales_desc',
                child: Text(AppLang.tr(isEn, 'Highest Sales Demand', 'अधिकतम बिक्री अनुसार'), style: const TextStyle(fontSize: 12.5)),
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

  // ── Compact Re-Order Item Card ──
  Widget _buildCompactReorderCard(ReorderItem item, bool isEn) {
    Color stockColor = AppColors.success;
    Color stockBg = const Color(0xFFD1FAE5);
    String stockText = '${item.currentStock.toStringAsFixed(0)} in stock';

    if (item.isOutOfStock) {
      stockColor = AppColors.error;
      stockBg = const Color(0xFFFEE2E2);
      stockText = 'Out of Stock (0)';
    } else if (item.isLowStock) {
      stockColor = const Color(0xFFD97706);
      stockBg = const Color(0xFFFEF3C7);
      stockText = 'Low: ${item.currentStock.toStringAsFixed(0)} left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isOutOfStock
              ? Colors.red.shade200
              : item.isLowStock
                  ? Colors.amber.shade300
                  : AppColors.border,
          width: item.isOutOfStock ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank indicator
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${item.rank}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Title and category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
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
                      '${item.category} • Sold ${item.totalSoldQty.toStringAsFixed(0)} ${item.unit}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Stock Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stockBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stockText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: stockColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Row 2: Suggested Order & Inactivity
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Order Qty: ${item.suggestedReorderQty.toStringAsFixed(0)} ${item.unit}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Last sold: ${item.lastSoldDateFormatted} (${item.inactiveStatusText})',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const Spacer(),

              // Quick Reorder WhatsApp button
              InkWell(
                onTap: () {
                  final msg = 'Hello, please send ${item.suggestedReorderQty.toStringAsFixed(0)} ${item.unit} of *${item.name}* at earliest.';
                  Share.share(msg, subject: 'Order for ${item.name}');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.send_rounded, size: 10, color: AppColors.success),
                      SizedBox(width: 3),
                      Text(
                        'Order',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(bool isEn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 40, color: AppColors.success),
            const SizedBox(height: 12),
            Text(
              AppLang.tr(isEn, 'Stock is Well Maintained!', 'स्टॉक संतुलित है!'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              AppLang.tr(
                isEn,
                'No items found matching the selected re-order filter.',
                'चयनित फ़िल्टर के अनुसार कोई पुनः ऑर्डर योग्य उत्पाद नहीं मिला।',
              ),
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
              AppLang.tr(isEn, 'Failed to load re-order data', 'डेटा लोड करने में त्रुटि'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage ?? '',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _loadReorderData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(AppLang.tr(isEn, 'Retry', 'पुनः प्रयास करें')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemSaleStats {
  double totalSold = 0;
  int ordersCount = 0;
  DateTime? lastSoldDate;
  double lastPrice = 0;
}
