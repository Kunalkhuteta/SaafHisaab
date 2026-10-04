import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../models/shop_access_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../services/reports_html_template.dart';
import '../../widgets/report_pdf_action_button.dart';
import '../../utils/indian_date_time.dart';

enum TrendingTab {
  salesperson,
  location,
  item,
  customer,
  party,
  month,
}

enum DateRangeFilter {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  prevMonth,
  thisYear,
  allTime,
  custom,
}

class TrendingRecord {
  final int rank;
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final double quantity;
  final String unit;
  final int billCount;
  final double sharePercent;
  final String highlightText;
  final DateTime? lastSaleDate;
  final int inactiveDays;
  final Map<String, dynamic> metadata;

  const TrendingRecord({
    required this.rank,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.quantity,
    this.unit = '',
    required this.billCount,
    required this.sharePercent,
    this.highlightText = '',
    this.lastSaleDate,
    this.inactiveDays = 0,
    this.metadata = const {},
  });

  String get lastSaleDateFormatted {
    if (lastSaleDate == null) return 'No records';
    return DateFormat('dd MMM yyyy').format(lastSaleDate!);
  }

  String get inactiveStatusText {
    if (lastSaleDate == null) return 'No activity';
    if (inactiveDays <= 0) return 'Active Today';
    if (inactiveDays == 1) return '1d ago';
    return '${inactiveDays}d inactive';
  }
}

class MonthTrendRecord {
  final int year;
  final int month;
  final String label; // e.g. "Oct 2026"
  final double salesAmount;
  final double purchaseAmount;
  final int salesCount;
  final int purchaseCount;
  final double momGrowth; // Month-over-month growth %
  final String topItem;
  final String topCustomer;
  final DateTime? lastSaleDate;
  final int inactiveDays;

  const MonthTrendRecord({
    required this.year,
    required this.month,
    required this.label,
    required this.salesAmount,
    required this.purchaseAmount,
    required this.salesCount,
    required this.purchaseCount,
    required this.momGrowth,
    required this.topItem,
    required this.topCustomer,
    this.lastSaleDate,
    this.inactiveDays = 0,
  });
}

class TopTrendingReportScreen extends ConsumerStatefulWidget {
  const TopTrendingReportScreen({super.key});

  @override
  ConsumerState<TopTrendingReportScreen> createState() => _TopTrendingReportScreenState();
}

class _TopTrendingReportScreenState extends ConsumerState<TopTrendingReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateRangeFilter _dateFilter = DateRangeFilter.thisMonth;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  bool _isLoading = true;
  String? _errorMessage;

  // Raw data collections
  List<BillModel> _bills = [];
  List<Map<String, dynamic>> _salesRows = [];
  Map<String, String> _memberNames = {};
  Map<String, String> _memberRoles = {};
  Map<String, String> _partyStations = {};
  Map<String, String> _customerPhones = {};
  Map<String, double> _customerDues = {};
  Map<String, double> _partyPayables = {};

  // Global all-time last transaction dates
  Map<String, DateTime> _globalPersonLastDate = {};
  Map<String, DateTime> _globalItemLastDate = {};
  Map<String, DateTime> _globalCustomerLastDate = {};
  Map<String, DateTime> _globalPartyLastDate = {};
  Map<String, DateTime> _globalLocationLastDate = {};

  // Processed lists
  List<TrendingRecord> _salespeople = [];
  List<TrendingRecord> _locations = [];
  List<TrendingRecord> _items = [];
  List<TrendingRecord> _customers = [];
  List<TrendingRecord> _parties = [];
  List<MonthTrendRecord> _monthlyTrends = [];

  // Search & Filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortMode = 'amount_desc'; // 'amount_desc', 'qty_desc', 'name_asc', 'inactive_desc'

  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _applyDateFilter(DateRangeFilter.thisMonth);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyDateFilter(DateRangeFilter filter) {
    final now = IndianDateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (filter) {
      case DateRangeFilter.today:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case DateRangeFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day, 0, 0, 0);
        end = DateTime(y.year, y.month, y.day, 23, 59, 59);
        break;
      case DateRangeFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
        break;
      case DateRangeFilter.thisMonth:
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        break;
      case DateRangeFilter.prevMonth:
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        start = DateTime(prevYear, prevMonth, 1, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month, 0).day;
        end = DateTime(prevYear, prevMonth, lastDay, 23, 59, 59);
        break;
      case DateRangeFilter.thisYear:
        final fyYear = now.month >= 4 ? now.year : now.year - 1;
        start = DateTime(fyYear, 4, 1, 0, 0, 0);
        break;
      case DateRangeFilter.allTime:
        start = DateTime(2020, 1, 1, 0, 0, 0);
        break;
      case DateRangeFilter.custom:
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
        _dateFilter = DateRangeFilter.custom;
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
      if (shop == null) throw Exception('Shop details not found');

      final client = Supabase.instance.client;
      final fromStr = _fromDate.toIso8601String().split('T')[0];
      final toStr = _toDate.toIso8601String().split('T')[0];

      // 1. Load bills in date range
      final billsResponse = await client
          .from('bills')
          .select()
          .eq('shop_id', shop.id)
          .gte('bill_date', fromStr)
          .lte('bill_date', toStr)
          .order('bill_date', ascending: false);

      _bills = (billsResponse as List).map((b) => BillModel.fromJson(b)).toList();

      // 2. Fetch sales line items for bills in range
      final billIds = _bills.map((b) => b.id).where((id) => id.isNotEmpty).toList();
      _salesRows = [];
      if (billIds.isNotEmpty) {
        for (var i = 0; i < billIds.length; i += 100) {
          final chunk = billIds.sublist(i, (i + 100 > billIds.length) ? billIds.length : i + 100);
          final rows = await client
              .from('sales')
              .select()
              .eq('shop_id', shop.id)
              .inFilter('bill_id', chunk);
          _salesRows.addAll(List<Map<String, dynamic>>.from(rows));
        }
      }

      if (_salesRows.isEmpty) {
        final directSales = await client
            .from('sales')
            .select()
            .eq('shop_id', shop.id)
            .gte('sale_date', fromStr)
            .lte('sale_date', toStr);
        _salesRows = List<Map<String, dynamic>>.from(directSales);
      }

      // 3. Global all-time queries to calculate exact Last Sale Date & Inactivity Duration
      _globalPersonLastDate = {};
      _globalItemLastDate = {};
      _globalCustomerLastDate = {};
      _globalPartyLastDate = {};
      _globalLocationLastDate = {};

      try {
        final historyBills = await client
            .from('bills')
            .select('user_id, vendor_name, bill_type, bill_date, notes')
            .eq('shop_id', shop.id)
            .order('bill_date', ascending: false)
            .limit(1000);

        for (final b in historyBills) {
          final date = IndianDateTime.parse(b['bill_date']);
          final uid = (b['user_id'] ?? '').toString();
          final vendor = (b['vendor_name'] ?? '').toString().trim().toLowerCase();
          final bType = (b['bill_type'] ?? '').toString();

          if (uid.isNotEmpty && !_globalPersonLastDate.containsKey(uid)) {
            _globalPersonLastDate[uid] = date;
          }

          if (vendor.isNotEmpty) {
            if (bType == 'sale' && !_globalCustomerLastDate.containsKey(vendor)) {
              _globalCustomerLastDate[vendor] = date;
            } else if (bType == 'purchase' && !_globalPartyLastDate.containsKey(vendor)) {
              _globalPartyLastDate[vendor] = date;
            }
          }

          // Location extraction
          String loc = 'Main Store (Counter)';
          final notes = (b['notes'] ?? '').toString().toLowerCase();
          if (notes.contains('station:') || notes.contains('city:')) {
            final match = RegExp(r'(station|city):\s*([a-zA-Z0-9\s]+)').firstMatch(notes);
            if (match != null && match.group(2) != null) loc = match.group(2)!.trim();
          }
          if (!_globalLocationLastDate.containsKey(loc.toLowerCase())) {
            _globalLocationLastDate[loc.toLowerCase()] = date;
          }
        }
      } catch (e) {
        debugPrint('Global bill date lookup error: $e');
      }

      try {
        final historySales = await client
            .from('sales')
            .select('item_name, sale_date')
            .eq('shop_id', shop.id)
            .order('sale_date', ascending: false)
            .limit(1000);

        for (final s in historySales) {
          final item = (s['item_name'] ?? '').toString().trim().toLowerCase();
          if (item.isNotEmpty && !_globalItemLastDate.containsKey(item)) {
            _globalItemLastDate[item] = IndianDateTime.parse(s['sale_date']);
          }
        }
      } catch (e) {
        debugPrint('Global sales item date lookup error: $e');
      }

      // 4. Shop members & staff lookup
      _memberNames = {shop.userId: shop.ownerName.isNotEmpty ? shop.ownerName : 'Owner'};
      _memberRoles = {shop.userId: 'Owner'};
      try {
        final members = await SupabaseService.getShopMembers(shop.id);
        for (final m in members) {
          _memberNames[m.userId] = m.name.isNotEmpty ? m.name : 'Staff';
          _memberRoles[m.userId] = m.role.label;
        }
      } catch (e) {
        debugPrint('Staff lookup error: $e');
      }

      // 5. Customers metadata
      _customerPhones = {};
      _customerDues = {};
      try {
        final custData = await SupabaseService.getAllUdharCustomers(shop.id);
        for (final c in custData) {
          final key = c.customerName.trim().toLowerCase();
          if (key.isNotEmpty) {
            _customerPhones[key] = c.customerPhone;
            _customerDues[key] = c.totalDue;
          }
        }
      } catch (e) {
        debugPrint('Customer lookup error: $e');
      }

      // 6. Purchase parties metadata
      _partyStations = {};
      _partyPayables = {};
      try {
        final partyData = await client
            .from('purchase_parties')
            .select()
            .eq('shop_id', shop.id);
        for (final p in partyData) {
          final key = (p['name'] ?? '').toString().trim().toLowerCase();
          if (key.isNotEmpty) {
            final station = (p['station'] ?? p['address'] ?? '').toString().trim();
            if (station.isNotEmpty) _partyStations[key] = station;
            _partyPayables[key] = (p['pending_amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      } catch (e) {
        debugPrint('Party lookup error: $e');
      }

      // 7. Monthly trend data (12 months)
      final twelveMonthsAgo = DateTime(IndianDateTime.now().year - 1, IndianDateTime.now().month, 1);
      final yearBillsResponse = await client
          .from('bills')
          .select()
          .eq('shop_id', shop.id)
          .gte('bill_date', twelveMonthsAgo.toIso8601String().split('T')[0])
          .lte('bill_date', IndianDateTime.now().toIso8601String().split('T')[0]);
      final yearBills = (yearBillsResponse as List).map((b) => BillModel.fromJson(b)).toList();

      // 8. Compute aggregations for all 6 dimensions
      _computeSalespeople();
      _computeLocations();
      _computeItems();
      _computeCustomers();
      _computeParties();
      _computeMonthlyTrends(yearBills);

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

  // ── Dimension 1: Salesperson ──
  void _computeSalespeople() {
    final Map<String, _PersonAccumulator> map = {};
    double totalRevenue = 0;
    final now = IndianDateTime.now();

    for (final bill in _bills.where((b) => b.billType == 'sale')) {
      final uid = bill.userId.isNotEmpty ? bill.userId : 'unknown';
      final acc = map.putIfAbsent(uid, () => _PersonAccumulator(userId: uid));
      acc.amount += bill.amount;
      acc.billCount += 1;
      if (acc.lastDate == null || bill.billDate.isAfter(acc.lastDate!)) {
        acc.lastDate = bill.billDate;
      }
      totalRevenue += bill.amount;
    }

    for (final s in _salesRows) {
      final uid = (s['user_id'] ?? '').toString();
      final targetUid = uid.isNotEmpty && map.containsKey(uid) ? uid : map.keys.firstOrNull;
      if (targetUid != null && map.containsKey(targetUid)) {
        final qty = (s['quantity'] as num?)?.toDouble() ?? 1.0;
        final itemName = (s['item_name'] ?? '').toString();
        map[targetUid]!.quantity += qty.abs();
        if (itemName.isNotEmpty) {
          map[targetUid]!.itemsSold[itemName] =
              (map[targetUid]!.itemsSold[itemName] ?? 0) + qty.abs();
        }
      }
    }

    final list = map.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    _salespeople = list.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final acc = entry.value;
      final name = _memberNames[acc.userId] ?? 'Staff Member';
      final role = _memberRoles[acc.userId] ?? 'Sales';
      final topItem = acc.itemsSold.entries.isNotEmpty
          ? (acc.itemsSold.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key
          : '';

      final share = totalRevenue > 0 ? (acc.amount / totalRevenue) * 100 : 0.0;
      final effectiveLastDate = _globalPersonLastDate[acc.userId] ?? acc.lastDate;
      final inactiveDays = effectiveLastDate != null ? now.difference(effectiveLastDate).inDays : 0;

      return TrendingRecord(
        rank: index,
        id: acc.userId,
        title: name,
        subtitle: '$role • ${acc.billCount} bills',
        amount: acc.amount,
        quantity: acc.quantity,
        unit: 'units',
        billCount: acc.billCount,
        sharePercent: share,
        highlightText: topItem.isNotEmpty ? 'Top Item: $topItem' : '',
        lastSaleDate: effectiveLastDate,
        inactiveDays: inactiveDays,
        metadata: {
          'role': role,
          'avgBill': acc.billCount > 0 ? acc.amount / acc.billCount : 0.0,
          'topItem': topItem,
        },
      );
    }).toList();
  }

  // ── Dimension 2: Location ──
  void _computeLocations() {
    final Map<String, _LocationAccumulator> map = {};
    double totalRevenue = 0;
    final now = IndianDateTime.now();

    for (final bill in _bills.where((b) => b.billType == 'sale')) {
      final custName = bill.vendorName.trim().toLowerCase();
      String location = 'Main Store (Counter)';
      if (_partyStations.containsKey(custName) && _partyStations[custName]!.isNotEmpty) {
        location = _partyStations[custName]!;
      } else if (bill.notes.toLowerCase().contains('station:') || bill.notes.toLowerCase().contains('city:')) {
        final match = RegExp(r'(station|city):\s*([a-zA-Z0-9\s]+)', caseSensitive: false).firstMatch(bill.notes);
        if (match != null && match.group(2) != null) location = match.group(2)!.trim();
      }

      final acc = map.putIfAbsent(location, () => _LocationAccumulator(name: location));
      acc.amount += bill.amount;
      acc.billCount += 1;
      if (acc.lastDate == null || bill.billDate.isAfter(acc.lastDate!)) {
        acc.lastDate = bill.billDate;
      }
      if (bill.vendorName.isNotEmpty) acc.uniqueCustomers.add(bill.vendorName);
      totalRevenue += bill.amount;
    }

    final list = map.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    _locations = list.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final acc = entry.value;
      final share = totalRevenue > 0 ? (acc.amount / totalRevenue) * 100 : 0.0;
      final effectiveLastDate = _globalLocationLastDate[acc.name.toLowerCase()] ?? acc.lastDate;
      final inactiveDays = effectiveLastDate != null ? now.difference(effectiveLastDate).inDays : 0;

      return TrendingRecord(
        rank: index,
        id: acc.name,
        title: acc.name,
        subtitle: '${acc.uniqueCustomers.length} Customers • ${acc.billCount} Invoices',
        amount: acc.amount,
        quantity: acc.uniqueCustomers.length.toDouble(),
        unit: 'clients',
        billCount: acc.billCount,
        sharePercent: share,
        highlightText: '${acc.billCount} Transactions',
        lastSaleDate: effectiveLastDate,
        inactiveDays: inactiveDays,
        metadata: {
          'customers': acc.uniqueCustomers.toList(),
          'avgOrder': acc.billCount > 0 ? acc.amount / acc.billCount : 0.0,
        },
      );
    }).toList();
  }

  // ── Dimension 3: Item ──
  void _computeItems() {
    final Map<String, _ItemAccumulator> map = {};
    double totalSales = 0;
    final now = IndianDateTime.now();

    for (final s in _salesRows) {
      final name = (s['item_name'] ?? 'Unnamed Item').toString().trim();
      if (name.isEmpty) continue;

      final qty = (s['quantity'] as num?)?.toDouble() ?? 1.0;
      final amt = (s['total_amount'] as num?)?.toDouble() ?? 0.0;
      final unit = (s['unit'] ?? 'pcs').toString();
      final saleDateStr = s['sale_date'];
      final saleDate = saleDateStr != null ? IndianDateTime.tryParse(saleDateStr) : null;

      final acc = map.putIfAbsent(name, () => _ItemAccumulator(name: name, unit: unit));
      acc.quantity += qty;
      acc.amount += amt;
      acc.billCount += 1;
      if (saleDate != null && (acc.lastDate == null || saleDate.isAfter(acc.lastDate!))) {
        acc.lastDate = saleDate;
      }
      totalSales += amt;
    }

    final list = map.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    _items = list.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final acc = entry.value;
      final share = totalSales > 0 ? (acc.amount / totalSales) * 100 : 0.0;
      final avgPrice = acc.quantity > 0 ? acc.amount / acc.quantity : 0.0;
      final effectiveLastDate = _globalItemLastDate[acc.name.toLowerCase()] ?? acc.lastDate;
      final inactiveDays = effectiveLastDate != null ? now.difference(effectiveLastDate).inDays : 0;

      return TrendingRecord(
        rank: index,
        id: acc.name,
        title: acc.name,
        subtitle: '${acc.quantity.toStringAsFixed(acc.quantity.truncateToDouble() == acc.quantity ? 0 : 2)} ${acc.unit} • Avg ₹${avgPrice.toStringAsFixed(0)}',
        amount: acc.amount,
        quantity: acc.quantity,
        unit: acc.unit,
        billCount: acc.billCount,
        sharePercent: share,
        highlightText: '#$index Most Sold',
        lastSaleDate: effectiveLastDate,
        inactiveDays: inactiveDays,
        metadata: {
          'avgPrice': avgPrice,
          'unit': acc.unit,
        },
      );
    }).toList();
  }

  // ── Dimension 4: Customer ──
  void _computeCustomers() {
    final Map<String, _CustomerAccumulator> map = {};
    double totalRevenue = 0;
    final now = IndianDateTime.now();

    for (final bill in _bills.where((b) => b.billType == 'sale')) {
      final name = bill.vendorName.trim().isNotEmpty ? bill.vendorName.trim() : 'Walk-in Customer';
      final acc = map.putIfAbsent(name, () => _CustomerAccumulator(name: name));
      acc.amount += bill.amount;
      acc.billCount += 1;
      if (acc.lastDate == null || bill.billDate.isAfter(acc.lastDate!)) {
        acc.lastDate = bill.billDate;
      }
      totalRevenue += bill.amount;
    }

    final list = map.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    _customers = list.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final acc = entry.value;
      final key = acc.name.toLowerCase();
      final phone = _customerPhones[key] ?? '';
      final due = _customerDues[key] ?? 0.0;
      final share = totalRevenue > 0 ? (acc.amount / totalRevenue) * 100 : 0.0;
      final effectiveLastDate = _globalCustomerLastDate[key] ?? acc.lastDate;
      final inactiveDays = effectiveLastDate != null ? now.difference(effectiveLastDate).inDays : 0;

      return TrendingRecord(
        rank: index,
        id: acc.name,
        title: acc.name,
        subtitle: phone.isNotEmpty ? phone : '${acc.billCount} invoices',
        amount: acc.amount,
        quantity: acc.billCount.toDouble(),
        unit: 'bills',
        billCount: acc.billCount,
        sharePercent: share,
        highlightText: due > 0 ? 'Udhar: ₹${_currencyFmt.format(due).replaceAll('₹', '')}' : 'Cleared',
        lastSaleDate: effectiveLastDate,
        inactiveDays: inactiveDays,
        metadata: {
          'phone': phone,
          'due': due,
          'avgBill': acc.billCount > 0 ? acc.amount / acc.billCount : 0.0,
        },
      );
    }).toList();
  }

  // ── Dimension 5: Party (Suppliers) ──
  void _computeParties() {
    final Map<String, _PartyAccumulator> map = {};
    double totalPurchases = 0;
    final now = IndianDateTime.now();

    for (final bill in _bills.where((b) => b.billType == 'purchase' || b.billType == 'purchase_return')) {
      final name = bill.vendorName.trim().isNotEmpty ? bill.vendorName.trim() : 'General Supplier';
      final acc = map.putIfAbsent(name, () => _PartyAccumulator(name: name));
      if (bill.billType == 'purchase') {
        acc.amount += bill.amount;
        acc.billCount += 1;
        totalPurchases += bill.amount;
      } else {
        acc.returnAmount += bill.amount;
      }
      if (acc.lastDate == null || bill.billDate.isAfter(acc.lastDate!)) {
        acc.lastDate = bill.billDate;
      }
    }

    final list = map.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    _parties = list.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final acc = entry.value;
      final key = acc.name.toLowerCase();
      final station = _partyStations[key] ?? '';
      final payable = _partyPayables[key] ?? 0.0;
      final share = totalPurchases > 0 ? (acc.amount / totalPurchases) * 100 : 0.0;
      final effectiveLastDate = _globalPartyLastDate[key] ?? acc.lastDate;
      final inactiveDays = effectiveLastDate != null ? now.difference(effectiveLastDate).inDays : 0;

      return TrendingRecord(
        rank: index,
        id: acc.name,
        title: acc.name,
        subtitle: station.isNotEmpty ? '$station • ${acc.billCount} bills' : '${acc.billCount} bills',
        amount: acc.amount,
        quantity: acc.billCount.toDouble(),
        unit: 'bills',
        billCount: acc.billCount,
        sharePercent: share,
        highlightText: payable > 0 ? 'Payable: ₹${_currencyFmt.format(payable).replaceAll('₹', '')}' : 'Settled',
        lastSaleDate: effectiveLastDate,
        inactiveDays: inactiveDays,
        metadata: {
          'station': station,
          'payable': payable,
          'returnAmount': acc.returnAmount,
        },
      );
    }).toList();
  }

  // ── Dimension 6: Month Trend ──
  void _computeMonthlyTrends(List<BillModel> yearBills) {
    final Map<String, _MonthAccumulator> map = {};
    final now = IndianDateTime.now();

    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final label = DateFormat('MMM yyyy').format(d);
      map[key] = _MonthAccumulator(year: d.year, month: d.month, label: label);
    }

    for (final bill in yearBills) {
      final key = '${bill.billDate.year}-${bill.billDate.month.toString().padLeft(2, '0')}';
      if (map.containsKey(key)) {
        if (bill.billType == 'sale') {
          map[key]!.salesAmount += bill.amount;
          map[key]!.salesCount += 1;
          if (map[key]!.lastDate == null || bill.billDate.isAfter(map[key]!.lastDate!)) {
            map[key]!.lastDate = bill.billDate;
          }
          if (bill.vendorName.isNotEmpty) {
            map[key]!.customers[bill.vendorName] =
                (map[key]!.customers[bill.vendorName] ?? 0) + bill.amount;
          }
        } else if (bill.billType == 'purchase') {
          map[key]!.purchaseAmount += bill.amount;
          map[key]!.purchaseCount += 1;
        }
      }
    }

    final sortedKeys = map.keys.toList()..sort();
    final List<MonthTrendRecord> records = [];

    for (int i = 0; i < sortedKeys.length; i++) {
      final current = map[sortedKeys[i]]!;
      double momGrowth = 0.0;
      if (i > 0) {
        final prev = map[sortedKeys[i - 1]]!;
        if (prev.salesAmount > 0) {
          momGrowth = ((current.salesAmount - prev.salesAmount) / prev.salesAmount) * 100;
        } else if (current.salesAmount > 0) {
          momGrowth = 100.0;
        }
      }

      final topCust = current.customers.entries.isNotEmpty
          ? (current.customers.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key
          : 'General';

      final inactiveDays = current.lastDate != null ? now.difference(current.lastDate!).inDays : 0;

      records.add(MonthTrendRecord(
        year: current.year,
        month: current.month,
        label: current.label,
        salesAmount: current.salesAmount,
        purchaseAmount: current.purchaseAmount,
        salesCount: current.salesCount,
        purchaseCount: current.purchaseCount,
        momGrowth: momGrowth,
        topItem: '',
        topCustomer: topCust,
        lastSaleDate: current.lastDate,
        inactiveDays: inactiveDays,
      ));
    }

    _monthlyTrends = records.reversed.toList();
  }

  // ── Share Trending Report ──
  void _shareTrendingReport() {
    final isEn = ref.read(appLanguageProvider);
    final filterLabel = _getFilterLabel(isEn);
    final activeTab = TrendingTab.values[_tabController.index];

    String msg = '🔥 *SaafHisaab Top Trending Report*\n';
    msg += '📅 *Period:* $filterLabel\n';
    msg += '────────────────────\n\n';

    switch (activeTab) {
      case TrendingTab.salesperson:
        msg += '👤 *TOP SALESPERSONS*\n';
        for (final r in _salespeople.take(5)) {
          msg += '#${r.rank} *${r.title}* - ${_currencyFmt.format(r.amount)} | Last Sale: ${r.lastSaleDateFormatted} (${r.inactiveStatusText})\n';
        }
        break;
      case TrendingTab.location:
        msg += '📍 *TOP LOCATIONS*\n';
        for (final r in _locations.take(5)) {
          msg += '#${r.rank} *${r.title}* - ${_currencyFmt.format(r.amount)} | Inactivity: ${r.inactiveStatusText}\n';
        }
        break;
      case TrendingTab.item:
        msg += '📦 *TOP ITEMS*\n';
        for (final r in _items.take(5)) {
          msg += '#${r.rank} *${r.title}* - ${_currencyFmt.format(r.amount)} | Last Sale: ${r.lastSaleDateFormatted} (${r.inactiveStatusText})\n';
        }
        break;
      case TrendingTab.customer:
        msg += '👥 *TOP CUSTOMERS*\n';
        for (final r in _customers.take(5)) {
          msg += '#${r.rank} *${r.title}* - ${_currencyFmt.format(r.amount)} | Last Purchase: ${r.lastSaleDateFormatted} (${r.inactiveStatusText})\n';
        }
        break;
      case TrendingTab.party:
        msg += '🤝 *TOP PARTIES (SUPPLIERS)*\n';
        for (final r in _parties.take(5)) {
          msg += '#${r.rank} *${r.title}* - ${_currencyFmt.format(r.amount)} | Last Purchase: ${r.lastSaleDateFormatted} (${r.inactiveStatusText})\n';
        }
        break;
      case TrendingTab.month:
        msg += '📊 *MONTHLY TRENDS*\n';
        for (final m in _monthlyTrends.take(6)) {
          final growth = m.momGrowth >= 0 ? '+${m.momGrowth.toStringAsFixed(1)}%' : '${m.momGrowth.toStringAsFixed(1)}%';
          msg += '• *${m.label}*: Sales ${_currencyFmt.format(m.salesAmount)} ($growth)\n';
        }
        break;
    }

    msg += '\n_Generated via SaafHisaab — Aapki dukaan ka saaf hisaab_';
    Share.share(msg, subject: 'Top Trending Report');
  }

  String _getFilterLabel(bool isEn) {
    switch (_dateFilter) {
      case DateRangeFilter.today:
        return AppLang.tr(isEn, 'Today', 'आज');
      case DateRangeFilter.yesterday:
        return AppLang.tr(isEn, 'Yesterday', 'कल');
      case DateRangeFilter.thisWeek:
        return AppLang.tr(isEn, 'This Week', 'इस सप्ताह');
      case DateRangeFilter.thisMonth:
        return AppLang.tr(isEn, 'This Month', 'इस महीने');
      case DateRangeFilter.prevMonth:
        return AppLang.tr(isEn, 'Previous Month', 'पिछला महीना');
      case DateRangeFilter.thisYear:
        return AppLang.tr(isEn, 'Current Year', 'इस वर्ष');
      case DateRangeFilter.allTime:
        return AppLang.tr(isEn, 'All Time', 'सभी समय');
      case DateRangeFilter.custom:
        final fmt = DateFormat('dd MMM');
        return '${fmt.format(_fromDate)} - ${fmt.format(_toDate)}';
    }
  }

  List<TrendingRecord> _getFilteredList(List<TrendingRecord> source) {
    var list = source;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((item) =>
          item.title.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q) ||
          item.highlightText.toLowerCase().contains(q)).toList();
    }

    if (_sortMode == 'amount_desc') {
      list.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortMode == 'qty_desc') {
      list.sort((a, b) => b.quantity.compareTo(a.quantity));
    } else if (_sortMode == 'name_asc') {
      list.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sortMode == 'inactive_desc') {
      list.sort((a, b) => b.inactiveDays.compareTo(a.inactiveDays));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppLang.tr(isEn, 'Top Trending', 'शीर्ष ट्रेंडिंग'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          ReportPdfActionButton(
            reportTitle: 'Top_Trending_${TrendingTab.values[_tabController.index].name}_${_getFilterLabel(isEn)}',
            onGenerateHtml: () async {
              final shop = await ref.read(shopProvider.future);
              final activeIndex = _tabController.index;
              String tabTitle = 'Salesperson';
              List<TrendingRecord> records = _getFilteredList(_salespeople);
              if (activeIndex == 1) {
                tabTitle = 'Location';
                records = _getFilteredList(_locations);
              } else if (activeIndex == 2) {
                tabTitle = 'Item';
                records = _getFilteredList(_items);
              } else if (activeIndex == 3) {
                tabTitle = 'Customer';
                records = _getFilteredList(_customers);
              } else if (activeIndex == 4) {
                tabTitle = 'Party';
                records = _getFilteredList(_parties);
              } else if (activeIndex == 5) {
                tabTitle = 'Month';
                records = _monthlyTrends.map((m) => TrendingRecord(
                  rank: _monthlyTrends.indexOf(m) + 1,
                  id: '${m.year}-${m.month}',
                  title: m.label,
                  subtitle: '${m.salesCount} Sales • Top: ${m.topCustomer}',
                  amount: m.salesAmount,
                  quantity: 0,
                  billCount: m.salesCount,
                  sharePercent: 0,
                  highlightText: m.momGrowth >= 0 ? '+${m.momGrowth.toStringAsFixed(1)}%' : '${m.momGrowth.toStringAsFixed(1)}%',
                  inactiveDays: m.inactiveDays,
                  metadata: {},
                )).toList();
              }

              return ReportsHtmlTemplate.generateTopTrending(
                shop: shop,
                tabTitle: tabTitle,
                periodLabel: _getFilterLabel(isEn),
                records: records,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: AppLang.tr(isEn, 'Share Report', 'रिपोर्ट शेयर करें'),
            onPressed: _shareTrendingReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: AppLang.tr(isEn, 'Refresh', 'ताज़ा करें'),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
              tabs: [
                Tab(
                  icon: const Icon(Icons.badge_rounded, size: 16),
                  text: AppLang.tr(isEn, 'Salesperson', 'सेल्सपर्सन'),
                ),
                Tab(
                  icon: const Icon(Icons.location_on_rounded, size: 16),
                  text: AppLang.tr(isEn, 'Location', 'लोकेशन'),
                ),
                Tab(
                  icon: const Icon(Icons.inventory_2_rounded, size: 16),
                  text: AppLang.tr(isEn, 'Item', 'आइटम'),
                ),
                Tab(
                  icon: const Icon(Icons.groups_rounded, size: 16),
                  text: AppLang.tr(isEn, 'Customer', 'ग्राहक'),
                ),
                Tab(
                  icon: const Icon(Icons.storefront_rounded, size: 16),
                  text: AppLang.tr(isEn, 'Party', 'पार्टी'),
                ),
                Tab(
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  text: AppLang.tr(isEn, 'Month', 'महीना'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Date Filter Horizontal Ribbon
          _buildDateFilterBar(isEn),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? _buildErrorView(isEn)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDimensionView(
                            records: _getFilteredList(_salespeople),
                            tab: TrendingTab.salesperson,
                            isEn: isEn,
                          ),
                          _buildDimensionView(
                            records: _getFilteredList(_locations),
                            tab: TrendingTab.location,
                            isEn: isEn,
                          ),
                          _buildDimensionView(
                            records: _getFilteredList(_items),
                            tab: TrendingTab.item,
                            isEn: isEn,
                          ),
                          _buildDimensionView(
                            records: _getFilteredList(_customers),
                            tab: TrendingTab.customer,
                            isEn: isEn,
                          ),
                          _buildDimensionView(
                            records: _getFilteredList(_parties),
                            tab: TrendingTab.party,
                            isEn: isEn,
                          ),
                          _buildMonthlyTrendView(isEn),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ── Date Filter Chips Bar ──
  Widget _buildDateFilterBar(bool isEn) {
    final filters = [
      {'type': DateRangeFilter.thisMonth, 'label': AppLang.tr(isEn, 'This Month', 'इस महीने')},
      {'type': DateRangeFilter.today, 'label': AppLang.tr(isEn, 'Today', 'आज')},
      {'type': DateRangeFilter.yesterday, 'label': AppLang.tr(isEn, 'Yesterday', 'कल')},
      {'type': DateRangeFilter.thisWeek, 'label': AppLang.tr(isEn, 'This Week', 'इस सप्ताह')},
      {'type': DateRangeFilter.prevMonth, 'label': AppLang.tr(isEn, 'Last Month', 'पिछला महीना')},
      {'type': DateRangeFilter.thisYear, 'label': AppLang.tr(isEn, 'This Year', 'इस वर्ष')},
      {'type': DateRangeFilter.allTime, 'label': AppLang.tr(isEn, 'All Time', 'सभी समय')},
      {'type': DateRangeFilter.custom, 'label': AppLang.tr(isEn, 'Custom', 'कस्टम')},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final type = f['type'] as DateRangeFilter;
            final label = f['label'] as String;
            final isSelected = _dateFilter == type;

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
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
                onSelected: (selected) {
                  if (type == DateRangeFilter.custom) {
                    _selectCustomDateRange();
                  } else {
                    _applyDateFilter(type);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Standard Dimension View ──
  Widget _buildDimensionView({
    required List<TrendingRecord> records,
    required TrendingTab tab,
    required bool isEn,
  }) {
    final double totalAmount = records.fold(0.0, (sum, r) => sum + r.amount);
    final int totalBills = records.fold(0, (sum, r) => sum + r.billCount);
    final topPerformer = records.isNotEmpty ? records.first.title : '—';

    return Column(
      children: [
        // Slim KPI Banner
        _buildSlimKpiBanner(
          totalAmount: totalAmount,
          totalBills: totalBills,
          topPerformer: topPerformer,
          tab: tab,
          isEn: isEn,
        ),

        // Compact Search & Sort Bar
        _buildCompactSearchAndSortBar(isEn),

        // Records List with Minimum Padding
        Expanded(
          child: records.isEmpty
              ? _buildEmptyStateWithAllTimeOption(isEn)
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  children: [
                    if (records.length >= 2) _buildTop5LeaderboardChart(records, tab, isEn),
                    ...records.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildCompactTrendingCard(item, tab, isEn),
                        )),
                  ],
                ),
        ),
      ],
    );
  }

  // ── Slim, Modern KPI Banner ──
  Widget _buildSlimKpiBanner({
    required double totalAmount,
    required int totalBills,
    required String topPerformer,
    required TrendingTab tab,
    required bool isEn,
  }) {
    String tabLabel = '';
    switch (tab) {
      case TrendingTab.salesperson:
        tabLabel = AppLang.tr(isEn, 'Top Person', 'शीर्ष व्यक्ति');
        break;
      case TrendingTab.location:
        tabLabel = AppLang.tr(isEn, 'Top Place', 'शीर्ष स्थान');
        break;
      case TrendingTab.item:
        tabLabel = AppLang.tr(isEn, 'Top Item', 'शीर्ष उत्पाद');
        break;
      case TrendingTab.customer:
        tabLabel = AppLang.tr(isEn, 'Top Buyer', 'शीर्ष खरीदार');
        break;
      case TrendingTab.party:
        tabLabel = AppLang.tr(isEn, 'Top Supplier', 'शीर्ष विक्रेता');
        break;
      case TrendingTab.month:
        tabLabel = AppLang.tr(isEn, 'Best Month', 'सर्वश्रेष्ठ महीना');
        break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
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
                tab == TrendingTab.party
                    ? AppLang.tr(isEn, 'Total Purchases', 'कुल खरीद')
                    : AppLang.tr(isEn, 'Total Revenue', 'कुल बिक्री'),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 1),
              Text(
                _currencyFmt.format(totalAmount),
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
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalBills ${AppLang.tr(isEn, 'Bills', 'बिल')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 130),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$tabLabel: $topPerformer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  // ── Compact Search & Sort Bar ──
  Widget _buildCompactSearchAndSortBar(bool isEn) {
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
                  hintText: AppLang.tr(isEn, 'Search...', 'खोजें...'),
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
                            ? AppLang.tr(isEn, 'Volume', 'मात्रा')
                            : _sortMode == 'inactive_desc'
                                ? AppLang.tr(isEn, 'Inactivity', 'निष्क्रिय')
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
                child: Text(AppLang.tr(isEn, 'Highest Volume / Count', 'ज़्यादा मात्रा / गणना'), style: const TextStyle(fontSize: 12.5)),
              ),
              PopupMenuItem(
                value: 'inactive_desc',
                child: Text(AppLang.tr(isEn, 'Longest Inactive (Days)', 'लंबे समय से निष्क्रिय'), style: const TextStyle(fontSize: 12.5)),
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

  // ── High-Density Card with Minimum Padding ──
  Widget _buildCompactTrendingCard(TrendingRecord item, TrendingTab tab, bool isEn) {
    Color rankColor;
    Color rankBg;
    if (item.rank == 1) {
      rankColor = const Color(0xFFD97706);
      rankBg = const Color(0xFFFEF3C7);
    } else if (item.rank == 2) {
      rankColor = const Color(0xFF4B5563);
      rankBg = const Color(0xFFF3F4F6);
    } else if (item.rank == 3) {
      rankColor = const Color(0xFFB45309);
      rankBg = const Color(0xFFFFEDD5);
    } else {
      rankColor = AppColors.primary;
      rankBg = AppColors.primaryBg;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showRecordDetailsModal(item, tab, isEn),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: item.rank == 1 ? Colors.amber.shade300 : AppColors.border,
              width: item.rank == 1 ? 1.2 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Rank + Title + Subtitle + Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: rankBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#${item.rank}',
                      style: TextStyle(
                        color: rankColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
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
                          item.subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFmt.format(item.amount),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${item.sharePercent.toStringAsFixed(1)}% share',
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

              const SizedBox(height: 6),

              // Row 2: Last Sale Date & Inactivity Duration
              Row(
                children: [
                  // Last Sale Date Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_available_rounded, size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          'Last: ${item.lastSaleDateFormatted}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Inactivity Duration Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.inactiveDays > 30
                          ? const Color(0xFFFEE2E2)
                          : item.inactiveDays > 7
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 10.5,
                          color: item.inactiveDays > 30
                              ? AppColors.error
                              : item.inactiveDays > 7
                                  ? const Color(0xFFD97706)
                                  : AppColors.success,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          item.inactiveStatusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: item.inactiveDays > 30
                                ? AppColors.error
                                : item.inactiveDays > 7
                                    ? const Color(0xFFB45309)
                                    : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (item.highlightText.isNotEmpty) ...[
                    const Spacer(),
                    Text(
                      item.highlightText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: item.rank == 1 ? Colors.amber.shade900 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 5),

              // Visual Share Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (item.sharePercent / 100).clamp(0.02, 1.0),
                  minHeight: 3.5,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    item.rank == 1
                        ? Colors.amber.shade600
                        : item.rank <= 3
                            ? AppColors.primaryLight
                            : AppColors.primary.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dimension 6: Monthly Trend View ──
  Widget _buildMonthlyTrendView(bool isEn) {
    if (_monthlyTrends.isEmpty) {
      return _buildEmptyStateWithAllTimeOption(isEn);
    }

    final highestMonth = _monthlyTrends.reduce((a, b) => a.salesAmount > b.salesAmount ? a : b);
    final totalYearSales = _monthlyTrends.fold(0.0, (sum, m) => sum + m.salesAmount);
    final avgMonthlySales = totalYearSales / (_monthlyTrends.isNotEmpty ? _monthlyTrends.length : 1);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      children: [
        // Slim Monthly Overview
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLang.tr(isEn, 'Annual Velocity', 'वार्षिक गति'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _currencyFmt.format(totalYearSales),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              _buildTrendMetric(
                label: AppLang.tr(isEn, 'Monthly Avg', 'मासिक औसत'),
                value: _currencyFmt.format(avgMonthlySales),
              ),
              _buildTrendMetric(
                label: AppLang.tr(isEn, 'Peak Month', 'सर्वश्रेष्ठ'),
                value: '${highestMonth.label}\n(${_currencyFmt.format(highestMonth.salesAmount)})',
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Monthly Bar Chart
        _buildMonthlyBarChart(isEn),

        const SizedBox(height: 8),

        // Monthly Breakdown Header
        Text(
          AppLang.tr(isEn, 'Month-by-Month Trends', 'महीनेवार ट्रेंड्स'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),

        // Monthly Cards List with Minimum Padding
        ..._monthlyTrends.map((m) {
          final isPositive = m.momGrowth >= 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      m.label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPositive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 12,
                            color: isPositive ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isPositive ? '+${m.momGrowth.toStringAsFixed(1)}%' : '${m.momGrowth.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isPositive ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${AppLang.tr(isEn, 'Sales:', 'बिक्री:')} ${_currencyFmt.format(m.salesAmount)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${AppLang.tr(isEn, 'Purchase:', 'खरीद:')} ${_currencyFmt.format(m.purchaseAmount)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      '${m.salesCount} ${AppLang.tr(isEn, 'bills', 'बिल')}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (m.lastSaleDate != null)
                      Text(
                        'Last Sale: ${DateFormat('dd MMM').format(m.lastSaleDate!)} (${m.inactiveDays}d ago)',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    if (m.topCustomer.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        'Top Buyer: ${m.topCustomer}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrendMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  // ── Top 5 Leaderboard Comparison Chart ──
  Widget _buildTop5LeaderboardChart(List<TrendingRecord> records, TrendingTab tab, bool isEn) {
    final top5 = records.take(5).toList();
    final double maxVal = top5.fold(100.0, (max, r) => r.amount > max ? r.amount : max);

    String chartTitle;
    switch (tab) {
      case TrendingTab.salesperson:
        chartTitle = AppLang.tr(isEn, 'Top 5 Salespersons Comparison', 'शीर्ष 5 सेल्सपर्सन तुलना');
        break;
      case TrendingTab.location:
        chartTitle = AppLang.tr(isEn, 'Top 5 Locations by Revenue', 'राजस्व अनुसार शीर्ष 5 लोकेशन');
        break;
      case TrendingTab.item:
        chartTitle = AppLang.tr(isEn, 'Top 5 Selling Items', 'शीर्ष 5 सबसे ज़्यादा बिकने वाले उत्पाद');
        break;
      case TrendingTab.customer:
        chartTitle = AppLang.tr(isEn, 'Top 5 Customers by Volume', 'शीर्ष 5 ग्राहक');
        break;
      case TrendingTab.party:
        chartTitle = AppLang.tr(isEn, 'Top 5 Suppliers by Purchases', 'खरीद अनुसार शीर्ष 5 विक्रेता');
        break;
      case TrendingTab.month:
        chartTitle = '';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  chartTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = top5[groupIndex];
                      return BarTooltipItem(
                        '#${item.rank} ${item.title}\n₹${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < top5.length) {
                          final name = top5[idx].title;
                          final shortName = name.length > 6 ? '${name.substring(0, 5)}..' : name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              shortName,
                              style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: top5.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: item.amount,
                        color: idx == 0
                            ? const Color(0xFFD97706)
                            : idx == 1
                                ? const Color(0xFF6B7280)
                                : idx == 2
                                    ? const Color(0xFFB45309)
                                    : AppColors.primary,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Monthly fl_chart Bar Chart ──
  Widget _buildMonthlyBarChart(bool isEn) {
    final reversedTrends = _monthlyTrends.reversed.toList();
    final double maxVal = reversedTrends.fold(1000.0, (max, m) => m.salesAmount > max ? m.salesAmount : max);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLang.tr(isEn, 'Sales Trajectory', 'बिक्री का ग्राफ'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(
                    AppLang.tr(isEn, 'Sales (₹)', 'बिक्री (₹)'),
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = reversedTrends[groupIndex];
                      return BarTooltipItem(
                        '${item.label}\n₹${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < reversedTrends.length) {
                          final parts = reversedTrends[idx].label.split(' ');
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              parts.first,
                              style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: reversedTrends.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: item.salesAmount,
                        color: AppColors.primary,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Record Details Modal Sheet ──
  void _showRecordDetailsModal(TrendingRecord item, TrendingTab tab, bool isEn) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${item.rank}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildModalDetailBox(
                    label: AppLang.tr(isEn, 'Total Amount', 'कुल राशि'),
                    value: _currencyFmt.format(item.amount),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildModalDetailBox(
                    label: AppLang.tr(isEn, 'Orders/Bills', 'कुल बिल'),
                    value: '${item.billCount}',
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  _buildModalDetailBox(
                    label: AppLang.tr(isEn, 'Contribution', 'योगदान'),
                    value: '${item.sharePercent.toStringAsFixed(1)}%',
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Activity & Inactivity Row in Modal
              Row(
                children: [
                  _buildModalDetailBox(
                    label: AppLang.tr(isEn, 'Last Active Date', 'अंतिम सक्रिय तारीख'),
                    value: item.lastSaleDateFormatted,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  _buildModalDetailBox(
                    label: AppLang.tr(isEn, 'Inactivity Duration', 'निष्क्रियता अवधि'),
                    value: item.inactiveStatusText,
                    color: item.inactiveDays > 30 ? AppColors.error : AppColors.success,
                  ),
                ],
              ),
              if (item.highlightText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        item.highlightText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalDetailBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State View With Quick All-Time Option ──
  Widget _buildEmptyStateWithAllTimeOption(bool isEn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.primaryBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLang.tr(isEn, 'No Trending Activity in This Period', 'इस अवधि में कोई डेटा नहीं मिला'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              AppLang.tr(
                isEn,
                'Try viewing "All Time" to analyze historical top performers.',
                'सभी समय के ऐतिहासिक रिकॉर्ड देखने के लिए नीचे दिए गए बटन पर टैप करें।',
              ),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _applyDateFilter(DateRangeFilter.allTime),
              icon: const Icon(Icons.all_inclusive_rounded, size: 16),
              label: Text(AppLang.tr(isEn, 'Switch to All Time', 'सभी समय का डेटा देखें')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error View ──
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
              AppLang.tr(isEn, 'Failed to load report data', 'रिपोर्ट लोड करने में समस्या आई'),
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
              onPressed: _loadData,
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

// ── Private Accumulator Classes ──
class _PersonAccumulator {
  final String userId;
  double amount = 0;
  double quantity = 0;
  int billCount = 0;
  DateTime? lastDate;
  final Map<String, double> itemsSold = {};
  _PersonAccumulator({required this.userId});
}

class _LocationAccumulator {
  final String name;
  double amount = 0;
  int billCount = 0;
  DateTime? lastDate;
  final Set<String> uniqueCustomers = {};
  _LocationAccumulator({required this.name});
}

class _ItemAccumulator {
  final String name;
  final String unit;
  double amount = 0;
  double quantity = 0;
  int billCount = 0;
  DateTime? lastDate;
  _ItemAccumulator({required this.name, required this.unit});
}

class _CustomerAccumulator {
  final String name;
  double amount = 0;
  int billCount = 0;
  DateTime? lastDate;
  _CustomerAccumulator({required this.name});
}

class _PartyAccumulator {
  final String name;
  double amount = 0;
  double returnAmount = 0;
  int billCount = 0;
  DateTime? lastDate;
  _PartyAccumulator({required this.name});
}

class _MonthAccumulator {
  final int year;
  final int month;
  final String label;
  double salesAmount = 0;
  double purchaseAmount = 0;
  int salesCount = 0;
  int purchaseCount = 0;
  DateTime? lastDate;
  final Map<String, double> customers = {};
  _MonthAccumulator({required this.year, required this.month, required this.label});
}
