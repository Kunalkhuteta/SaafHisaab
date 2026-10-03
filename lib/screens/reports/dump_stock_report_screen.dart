import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../utils/indian_date_time.dart';

class DumpStockItem {
  final String id;
  final String itemName;
  final String category;
  final double quantity;
  final String unit;
  final double rate;
  final double totalLoss;
  final String reason;
  final String notes;
  final DateTime date;

  const DumpStockItem({
    required this.id,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.totalLoss,
    required this.reason,
    required this.notes,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_name': itemName,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'rate': rate,
        'total_loss': totalLoss,
        'reason': reason,
        'notes': notes,
        'date': date.toIso8601String(),
      };

  factory DumpStockItem.fromJson(Map<String, dynamic> json) => DumpStockItem(
        id: json['id'] ?? '',
        itemName: json['item_name'] ?? '',
        category: json['category'] ?? 'General',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] ?? 'piece',
        rate: (json['rate'] as num?)?.toDouble() ?? 0,
        totalLoss: (json['total_loss'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] ?? 'Damaged',
        notes: json['notes'] ?? '',
        date: IndianDateTime.parse(json['date']),
      );
}

class DeadStockItem {
  final String id;
  final String itemName;
  final String category;
  final double quantity;
  final String unit;
  final double buyingPrice;
  final double blockedCapital;
  final int daysInactive;

  const DeadStockItem({
    required this.id,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.buyingPrice,
    required this.blockedCapital,
    required this.daysInactive,
  });
}

class DumpStockReportScreen extends ConsumerStatefulWidget {
  const DumpStockReportScreen({super.key});

  @override
  ConsumerState<DumpStockReportScreen> createState() => _DumpStockReportScreenState();
}

class _DumpStockReportScreenState extends ConsumerState<DumpStockReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<DumpStockItem> _dumpList = [];
  List<DeadStockItem> _deadStockList = [];
  List<Map<String, dynamic>> _availableStockItems = [];

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
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) throw Exception('Shop not loaded');

      final client = Supabase.instance.client;
      final sp = await SharedPreferences.getInstance();

      // 1. Load local logged dump stock records
      final dumpKey = 'dump_stock_records_${shop.id}';
      final dumpJson = sp.getString(dumpKey);
      if (dumpJson != null) {
        final List decoded = jsonDecode(dumpJson);
        _dumpList = decoded.map((e) => DumpStockItem.fromJson(e)).toList();
        _dumpList.sort((a, b) => b.date.compareTo(a.date));
      } else {
        _dumpList = [];
      }

      // 2. Fetch stock items
      final stockData = await client
          .from('stock_items')
          .select()
          .eq('shop_id', shop.id);

      _availableStockItems = List<Map<String, dynamic>>.from(stockData);

      // 3. Fetch sales in last 90 days to identify non-moving / dead stock
      final ninetyDaysAgo = IndianDateTime.now().subtract(const Duration(days: 90));
      final dateStr = ninetyDaysAgo.toIso8601String().split('T')[0];

      final recentSales = await client
          .from('sales')
          .select('item_name, sale_date')
          .eq('shop_id', shop.id)
          .gte('sale_date', dateStr);

      final soldItemNames = <String, DateTime>{};
      for (final s in recentSales) {
        final name = (s['item_name'] ?? '').toString().toLowerCase().trim();
        final dt = IndianDateTime.parse(s['sale_date']);
        if (!soldItemNames.containsKey(name) || dt.isAfter(soldItemNames[name]!)) {
          soldItemNames[name] = dt;
        }
      }

      final now = IndianDateTime.now();
      final List<DeadStockItem> deadItems = [];

      for (final s in _availableStockItems) {
        final name = (s['item_name'] ?? '').toString().trim();
        final qty = (s['current_quantity'] as num?)?.toDouble() ?? 0.0;
        final buyPrice = (s['buying_price'] as num?)?.toDouble() ?? 0.0;
        final category = (s['category'] ?? 'General').toString();
        final unit = (s['unit'] ?? 'piece').toString();
        final itemId = s['id']?.toString() ?? '';

        if (qty > 0) {
          final lowerName = name.toLowerCase();
          final lastSold = soldItemNames[lowerName];
          if (lastSold == null) {
            // Not sold in 90 days at all!
            deadItems.add(DeadStockItem(
              id: itemId,
              itemName: name,
              category: category,
              quantity: qty,
              unit: unit,
              buyingPrice: buyPrice,
              blockedCapital: qty * buyPrice,
              daysInactive: 90,
            ));
          } else {
            final days = now.difference(lastSold).inDays;
            if (days >= 45) {
              deadItems.add(DeadStockItem(
                id: itemId,
                itemName: name,
                category: category,
                quantity: qty,
                unit: unit,
                buyingPrice: buyPrice,
                blockedCapital: qty * buyPrice,
                daysInactive: days,
              ));
            }
          }
        }
      }

      deadItems.sort((a, b) => b.blockedCapital.compareTo(a.blockedCapital));
      _deadStockList = deadItems;

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDumpRecord(DumpStockItem item) async {
    final shop = await ref.read(shopProvider.future);
    if (shop == null) return;

    final sp = await SharedPreferences.getInstance();
    final dumpKey = 'dump_stock_records_${shop.id}';

    _dumpList.insert(0, item);
    final encoded = jsonEncode(_dumpList.map((e) => e.toJson()).toList());
    await sp.setString(dumpKey, encoded);
    setState(() {});
  }

  Future<void> _deleteDumpRecord(String id) async {
    final shop = await ref.read(shopProvider.future);
    if (shop == null) return;

    final sp = await SharedPreferences.getInstance();
    final dumpKey = 'dump_stock_records_${shop.id}';

    _dumpList.removeWhere((e) => e.id == id);
    final encoded = jsonEncode(_dumpList.map((e) => e.toJson()).toList());
    await sp.setString(dumpKey, encoded);
    setState(() {});
  }

  void _showAddDumpModal(bool isEn) {
    if (_availableStockItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLang.tr(isEn, 'No stock items found in inventory', 'इन्वेंट्री में कोई सामान नहीं मिला'))),
      );
      return;
    }

    Map<String, dynamic>? selectedItem = _availableStockItems.first;
    final qtyCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();
    String selectedReason = 'Expired / Outdated';

    final reasons = [
      'Expired / Outdated',
      'Physical Breakage / Damaged',
      'Water / Moisture Damage',
      'Transit Loss',
      'Quality Defect / Spoiled',
      'Shortage / Stolen',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final rate = (selectedItem?['buying_price'] as num?)?.toDouble() ?? 0.0;
            final double q = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
            final double totalLoss = q * rate;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
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
                      Text(
                        AppLang.tr(isEn, 'Record Damaged / Dump Stock', 'खराब / डंप स्टॉक दर्ज करें'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      // Item Dropdown
                      Text(AppLang.tr(isEn, 'Select Item', 'सामान चुनें'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedItem,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _availableStockItems.map((item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Text(
                              '${item['item_name']} (In Stock: ${item['current_quantity']} ${item['unit'] ?? ''})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedItem = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      // Quantity & Loss preview
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLang.tr(isEn, 'Quantity Dumped', 'डंप मात्रा'),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: qtyCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setSheetState(() {}),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLang.tr(isEn, 'Total Loss Value', 'कुल नुकसान'),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                Container(
                                  height: 48,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    _currencyFmt.format(totalLoss),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Reason Dropdown
                      Text(AppLang.tr(isEn, 'Damage Cause / Reason', 'नुकसान का कारण'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedReason,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedReason = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      // Notes
                      Text(AppLang.tr(isEn, 'Remarks / Notes (Optional)', 'विवरण / टिप्पणी (वैकल्पिक)'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Broken packaging during unboxing',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedItem == null || totalLoss <= 0) return;

                            final newItem = DumpStockItem(
                              id: IndianDateTime.now().millisecondsSinceEpoch.toString(),
                              itemName: selectedItem!['item_name'] ?? 'Item',
                              category: selectedItem!['category'] ?? 'General',
                              quantity: q,
                              unit: selectedItem!['unit'] ?? 'piece',
                              rate: rate,
                              totalLoss: totalLoss,
                              reason: selectedReason,
                              notes: noteCtrl.text.trim(),
                              date: IndianDateTime.now(),
                            );

                            _saveDumpRecord(newItem);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(AppLang.tr(isEn, 'Save Damaged Record', 'नुकसान रिकॉर्ड सहेजें'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _shareReport() {
    final isEn = ref.read(appLanguageProvider);
    final totalDumpLoss = _dumpList.fold(0.0, (sum, i) => sum + i.totalLoss);
    final totalDeadCapital = _deadStockList.fold(0.0, (sum, i) => sum + i.blockedCapital);

    final sb = StringBuffer();
    sb.writeln('🗑️ DUMP & DEAD STOCK REPORT');
    sb.writeln('Date: ${DateFormat('dd MMM yyyy').format(IndianDateTime.now())}');
    sb.writeln('Total Damaged/Dump Loss: ${_currencyFmt.format(totalDumpLoss)}');
    sb.writeln('Total Blocked Dead Stock: ${_currencyFmt.format(totalDeadCapital)}');
    sb.writeln('-----------------------------------');
    sb.writeln('DAMAGED / DUMPED ITEMS:');
    for (final d in _dumpList.take(15)) {
      sb.writeln('• ${d.itemName}: ${d.quantity} ${d.unit} (Loss: ${_currencyFmt.format(d.totalLoss)}) - ${d.reason}');
    }
    sb.writeln('-----------------------------------');
    sb.writeln('NON-MOVING / DEAD STOCK:');
    for (final ds in _deadStockList.take(15)) {
      sb.writeln('• ${ds.itemName}: ${ds.quantity} ${ds.unit} (Blocked: ${_currencyFmt.format(ds.blockedCapital)}) - ${ds.daysInactive}d inactive');
    }
    sb.writeln('Generated via SaafHisaab App');

    Share.share(sb.toString(), subject: 'Dump and Dead Stock Report');
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    final totalDumpLoss = _dumpList.fold(0.0, (sum, i) => sum + i.totalLoss);
    final totalDumpQty = _dumpList.fold(0.0, (sum, i) => sum + i.quantity);
    final totalDeadCapital = _deadStockList.fold(0.0, (sum, i) => sum + i.blockedCapital);

    final filteredDump = _dumpList.where((d) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.itemName.toLowerCase().contains(q) || d.reason.toLowerCase().contains(q);
    }).toList();

    final filteredDead = _deadStockList.where((d) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.itemName.toLowerCase().contains(q) || d.category.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'Dump & Dead Stock', 'डंप और डेड स्टॉक')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: AppLang.tr(isEn, 'Share Report', 'रिपोर्ट साझा करें'),
            onPressed: _dumpList.isEmpty && _deadStockList.isEmpty ? null : _shareReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: [
            Tab(text: AppLang.tr(isEn, 'Damaged / Dump (${_dumpList.length})', 'खराब / डंप (${_dumpList.length})')),
            Tab(text: AppLang.tr(isEn, 'Dead Stock (${_deadStockList.length})', 'डेड स्टॉक (${_deadStockList.length})')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDumpModal(isEn),
        backgroundColor: AppColors.error,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          AppLang.tr(isEn, 'Log Damaged Stock', 'खराब स्टॉक जोड़ें'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
                  children: [
                    // Search box
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: AppLang.tr(isEn, 'Search item name or reason...', 'सामान या कारण खोजें...'),
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
                    ),

                    // Top KPI Stats
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                                Text(
                                  AppLang.tr(isEn, 'Total Dump Loss', 'कुल डंप नुकसान'),
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currencyFmt.format(totalDumpLoss),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error),
                                ),
                                Text(
                                  '${totalDumpQty.toStringAsFixed(0)} units written off',
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.textHint),
                                ),
                              ],
                            ),
                          ),
                          Container(height: 36, width: 1, color: AppColors.border),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLang.tr(isEn, 'Blocked Dead Capital', 'अवरुद्ध पूंजी'),
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currencyFmt.format(totalDeadCapital),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.warning),
                                ),
                                Text(
                                  '${_deadStockList.length} items stagnant',
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.textHint),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab View
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: Dump Log
                          filteredDump.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 54, color: AppColors.textHint.withOpacity(0.5)),
                                      const SizedBox(height: 12),
                                      Text(
                                        AppLang.tr(isEn, 'No damaged or dumped items logged', 'कोई खराब स्टॉक दर्ज नहीं है'),
                                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        AppLang.tr(isEn, 'Tap "+ Log Damaged Stock" to record', 'दर्ज करने के लिए नीचे बटन दबाएं'),
                                        style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                                  itemCount: filteredDump.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = filteredDump[index];
                                    return _buildDumpCard(item, isEn);
                                  },
                                ),

                          // Tab 2: Dead Stock
                          filteredDead.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.success.withOpacity(0.5)),
                                      const SizedBox(height: 12),
                                      Text(
                                        AppLang.tr(isEn, 'All inventory items are actively moving!', 'सभी सामान सक्रिय रूप से बिक रहे हैं!'),
                                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                                  itemCount: filteredDead.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = filteredDead[index];
                                    return _buildDeadCard(item, isEn);
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDumpCard(DumpStockItem item, bool isEn) {
    final dateStr = DateFormat('dd MMM yyyy').format(item.date);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textHint),
                onPressed: () => _deleteDumpRecord(item.id),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.reason,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
                ),
              ),
              const SizedBox(width: 8),
              Text(dateStr, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppLang.tr(isEn, 'Quantity', 'मात्रा')}: ${item.quantity} ${item.unit} @ ${_currencyFmt.format(item.rate)}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              Text(
                '${AppLang.tr(isEn, 'Loss', 'नुकसान')}: ${_currencyFmt.format(item.totalLoss)}',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.error),
              ),
            ],
          ),
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${AppLang.tr(isEn, 'Note', 'नोट')}: ${item.notes}',
              style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeadCard(DeadStockItem item, bool isEn) {
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.hourglass_empty_rounded, color: Colors.amber.shade800, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} ${item.unit} in stock • ${item.daysInactive}+ days stagnant',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFmt.format(item.blockedCapital),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                AppLang.tr(isEn, 'Blocked Capital', 'अवरुद्ध पूंजी'),
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
