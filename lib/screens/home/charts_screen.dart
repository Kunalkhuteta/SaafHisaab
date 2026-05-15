import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';

enum _ChartRange { week, month, year, custom }
enum _ChartTab { sale, purchase, returns, credit }

class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen>
    with SingleTickerProviderStateMixin {
  _ChartRange _range = _ChartRange.month;
  DateTimeRange? _customRange;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final shopAsync = ref.watch(shopProvider);

    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            bottom: 16,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child:
                    const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  AppLang.tr(isEn, 'Charts', 'Charts'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              _rangeButton(isEn),
            ],
          ),
        ),
        Expanded(
          child: shopAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (shop) {
              if (shop == null) return const SizedBox();
              final range = _selectedRange();
              return FutureBuilder<_ChartsData>(
                future: _loadData(shop.id, range),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final data = snapshot.data ?? _ChartsData.empty();
                  return _chartBody(data, range, isEn);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _rangeButton(bool isEn) {
    return PopupMenuButton<_ChartRange>(
      initialValue: _range,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == _ChartRange.custom) {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: _customRange ?? _selectedRange(),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme:
                    const ColorScheme.light(primary: AppColors.primary),
              ),
              child: child!,
            ),
          );
          if (picked == null) return;
          setState(() {
            _customRange = picked;
            _range = value;
          });
          return;
        }
        setState(() => _range = value);
      },
      itemBuilder: (_) => _ChartRange.values
          .map(
            (range) => PopupMenuItem(
              value: range,
              child: Text(_rangeLabel(range, isEn)),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              _rangeLabel(_range, isEn),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _chartBody(_ChartsData data, DateTimeRange range, bool isEn) {
    final tab = _ChartTab.values[_tabController.index];
    final series = data.seriesFor(tab);
    final color = _tabColor(tab);
    final total = series.fold(0.0, (sum, point) => sum + point.amount);
    final average = series.isEmpty ? 0.0 : total / series.length;
    final peak = series.fold(0.0, (max, point) => point.amount > max ? point.amount : max);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(child: _metricCard('Total', total, color)),
              const SizedBox(width: 10),
              Expanded(child: _metricCard('Average', average, AppColors.purple)),
              const SizedBox(width: 10),
              Expanded(child: _metricCard('Peak', peak, AppColors.warning)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              onTap: (_) => setState(() {}),
              tabs: const [
                Tab(text: 'Sale'),
                Tab(text: 'Purc'),
                Tab(text: 'Returns'),
                Tab(text: 'Credit'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 310,
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: series.every((point) => point.amount == 0)
                ? const Center(
                    child: Text(
                      'No chart data',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: peak <= 0 ? 1 : peak * 1.22,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.border.withOpacity(0.8),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) => Text(
                              _compactMoney(value),
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= series.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  series[index].label,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < series.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: series[i].amount,
                                width: series.length > 10 ? 12 : 18,
                                borderRadius: BorderRadius.circular(7),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [color.withOpacity(0.62), color],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 650),
                    swapAnimationCurve: Curves.easeOutCubic,
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            '${_formatDate(range.start)} - ${_formatDate(range.end)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<_ChartsData> _loadData(String shopId, DateTimeRange range) async {
    final results = await Future.wait<dynamic>([
      SupabaseService.getBills(shopId, range.start, range.end),
      SupabaseService.getSales(shopId, range.start, range.end),
      SupabaseService.getUdharCustomers(shopId),
    ]);

    return _ChartsData.from(
      bills: results[0] as List<BillModel>,
      sales: results[1] as List<SaleModel>,
      receivables: results[2] as List<UdharCustomerModel>,
      range: range,
      bucketCount: _bucketCount(range),
    );
  }

  DateTimeRange _selectedRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _ChartRange.week:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: _endOfDay(today),
        );
      case _ChartRange.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: _endOfDay(today),
        );
      case _ChartRange.year:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: _endOfDay(today),
        );
      case _ChartRange.custom:
        return _customRange ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
    }
  }

  int _bucketCount(DateTimeRange range) {
    final days = range.end.difference(range.start).inDays + 1;
    if (days <= 7) return days;
    if (days <= 45) return days <= 16 ? days : 8;
    return 12;
  }

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  String _rangeLabel(_ChartRange range, bool isEn) {
    switch (range) {
      case _ChartRange.week:
        return AppLang.tr(isEn, 'Week', 'Week');
      case _ChartRange.month:
        return AppLang.tr(isEn, 'Month', 'Month');
      case _ChartRange.year:
        return AppLang.tr(isEn, 'Year', 'Year');
      case _ChartRange.custom:
        return AppLang.tr(isEn, 'Custom', 'Custom');
    }
  }

  Color _tabColor(_ChartTab tab) {
    switch (tab) {
      case _ChartTab.sale:
        return AppColors.success;
      case _ChartTab.purchase:
        return AppColors.primary;
      case _ChartTab.returns:
        return AppColors.warning;
      case _ChartTab.credit:
        return AppColors.purple;
    }
  }

  String _compactMoney(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _ChartsData {
  final List<_ChartPoint> sales;
  final List<_ChartPoint> purchases;
  final List<_ChartPoint> returns;
  final List<_ChartPoint> credit;

  const _ChartsData({
    required this.sales,
    required this.purchases,
    required this.returns,
    required this.credit,
  });

  factory _ChartsData.empty() =>
      const _ChartsData(sales: [], purchases: [], returns: [], credit: []);

  factory _ChartsData.from({
    required List<BillModel> bills,
    required List<SaleModel> sales,
    required List<UdharCustomerModel> receivables,
    required DateTimeRange range,
    required int bucketCount,
  }) {
    final buckets = _buckets(range, bucketCount);
    final salePoints = _emptyPoints(buckets);
    final purchasePoints = _emptyPoints(buckets);
    final returnPoints = _emptyPoints(buckets);
    final creditPoints = _emptyPoints(buckets);

    for (final sale in sales) {
      _add(salePoints, buckets, sale.saleDate, sale.totalAmount);
    }

    for (final bill in bills) {
      if (bill.billType == 'sale' &&
          !sales.any((sale) => sale.billId == bill.id)) {
        _add(salePoints, buckets, bill.billDate, bill.amount);
      } else if (bill.billType == 'purchase') {
        _add(purchasePoints, buckets, bill.billDate, bill.amount);
      } else if (bill.billType == 'sale_return' ||
          bill.billType == 'purchase_return') {
        _add(returnPoints, buckets, bill.billDate, bill.amount);
      }
    }

    for (final customer in receivables) {
      _add(creditPoints, buckets, customer.createdAt, customer.totalDue);
    }

    return _ChartsData(
      sales: salePoints,
      purchases: purchasePoints,
      returns: returnPoints,
      credit: creditPoints,
    );
  }

  List<_ChartPoint> seriesFor(_ChartTab tab) {
    switch (tab) {
      case _ChartTab.sale:
        return sales;
      case _ChartTab.purchase:
        return purchases;
      case _ChartTab.returns:
        return returns;
      case _ChartTab.credit:
        return credit;
    }
  }

  static List<_Bucket> _buckets(DateTimeRange range, int count) {
    final totalDays = range.end.difference(range.start).inDays + 1;
    if (count <= 1) {
      return [_Bucket(range.start, range.end, _label(range.start))];
    }
    final daysPerBucket = (totalDays / count).ceil();
    return List.generate(count, (index) {
      final start = range.start.add(Duration(days: index * daysPerBucket));
      var end = start.add(Duration(days: daysPerBucket - 1));
      if (end.isAfter(range.end)) end = range.end;
      return _Bucket(start, end, _label(start));
    });
  }

  static List<_ChartPoint> _emptyPoints(List<_Bucket> buckets) =>
      buckets.map((bucket) => _ChartPoint(bucket.label, 0)).toList();

  static void _add(
    List<_ChartPoint> points,
    List<_Bucket> buckets,
    DateTime date,
    double amount,
  ) {
    final day = DateTime(date.year, date.month, date.day);
    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final start = DateTime(bucket.start.year, bucket.start.month, bucket.start.day);
      final end = DateTime(bucket.end.year, bucket.end.month, bucket.end.day);
      if (!day.isBefore(start) && !day.isAfter(end)) {
        points[i] = _ChartPoint(points[i].label, points[i].amount + amount);
        return;
      }
    }
  }

  static String _label(DateTime date) => '${date.day}/${date.month}';
}

class _Bucket {
  final DateTime start;
  final DateTime end;
  final String label;

  const _Bucket(this.start, this.end, this.label);
}

class _ChartPoint {
  final String label;
  final double amount;

  const _ChartPoint(this.label, this.amount);
}
