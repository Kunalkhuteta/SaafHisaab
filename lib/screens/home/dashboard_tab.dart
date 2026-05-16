import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../bills/invoice_list_screen.dart';
import '../udhar/udhar_screen.dart';
import '../stock/stock_screen.dart';
import '../profile/profile_screen.dart';
import 'chart_data_helper.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  final PageController _chartsPageCtrl = PageController(viewportFraction: 0.92);
  Timer? _timer;
  String _chartFilter = 'month'; // week, month, year

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_chartsPageCtrl.hasClients) {
        int nextPage = _chartsPageCtrl.page!.round() + 1;
        if (nextPage > 3) nextPage = 0;
        _chartsPageCtrl.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chartsPageCtrl.dispose();
    super.dispose();
  }

  void _gotoInvoice(String type, bool isEn) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceListScreen(
          billType: type,
          title: type == 'sale' ? AppLang.tr(isEn, 'Sales', 'बिक्री') 
                 : type == 'purchase' ? AppLang.tr(isEn, 'Purchase', 'खरीद')
                 : type == 'sale_return' ? AppLang.tr(isEn, 'Sale Return', 'बिक्री वापसी')
                 : AppLang.tr(isEn, 'Purchase Return', 'खरीद वापसी'),
          titleHi: type == 'sale' ? 'बिक्री' 
                 : type == 'purchase' ? 'खरीद'
                 : type == 'sale_return' ? 'बिक्री वापसी'
                 : 'खरीद वापसी',
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Future<_DashboardData> _loadData(String shopId) async {
    final now = DateTime.now();
    
    // Default range for bills/cards (this month)
    final gridStart = DateTime(now.year, now.month, 1);
    final gridEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Range for charts based on filter
    DateTime chartStart;
    DateTime chartEnd = gridEnd;
    ChartRange rangeType;

    if (_chartFilter == 'week') {
      chartStart = now.subtract(Duration(days: now.weekday - 1));
      chartStart = DateTime(chartStart.year, chartStart.month, chartStart.day);
      rangeType = ChartRange.week;
    } else if (_chartFilter == 'year') {
      chartStart = DateTime(now.year, 4, 1);
      if (now.month < 4) chartStart = DateTime(now.year - 1, 4, 1);
      rangeType = ChartRange.year;
    } else {
      chartStart = gridStart;
      rangeType = ChartRange.month;
    }
    final chartRange = DateTimeRange(start: chartStart, end: chartEnd);

    // Fetch data using the wider of the two ranges (usually year is widest, but just in case, fetch both and filter)
    final fetchStart = chartStart.isBefore(gridStart) ? chartStart : gridStart;

    final results = await Future.wait<dynamic>([
      SupabaseService.getBills(shopId, fetchStart, gridEnd),
      SupabaseService.getUdharCustomers(shopId),
      SupabaseService.getLowStockCount(shopId),
    ]);

    final allBills = results[0] as List<BillModel>;
    final receivables = results[1] as List<UdharCustomerModel>;
    final lowStock = results[2] as int;

    // Filter bills for grid cards (Month)
    final gridBills = allBills.where((b) => !b.billDate.isBefore(gridStart) && !b.billDate.isAfter(gridEnd)).toList();
    
    double totalSales = 0;
    double totalPurchase = 0;
    for (final b in gridBills) {
      if (b.billType == 'sale') totalSales += b.amount;
      if (b.billType == 'purchase') totalPurchase += b.amount;
    }
    double totalCredit = receivables.fold(0.0, (s, r) => s + r.totalDue);

    // Filter bills for charts
    final chartBills = allBills.where((b) => !b.billDate.isBefore(chartStart) && !b.billDate.isAfter(chartEnd)).toList();

    // Create custom buckets for charts
    final charts = ChartsData.from(
      bills: chartBills,
      sales: [],
      receivables: receivables,
      range: chartRange,
      rangeType: rangeType,
    );

    // Filter return points manually to split them
    final saleReturnPoints = _buildReturnPoints(chartBills, 'sale_return', chartRange, rangeType);
    final purchaseReturnPoints = _buildReturnPoints(chartBills, 'purchase_return', chartRange, rangeType);

    return _DashboardData(
      totalSales: totalSales,
      totalPurchase: totalPurchase,
      totalCredit: totalCredit,
      lowStockCount: lowStock,
      charts: charts,
      saleReturnsPoints: saleReturnPoints,
      purchaseReturnsPoints: purchaseReturnPoints,
    );
  }

  List<ChartPoint> _buildReturnPoints(List<BillModel> bills, String type, DateTimeRange range, ChartRange rangeType) {
    List<ChartBucket> buckets;
    
    if (rangeType == ChartRange.year) {
      final months = range.end.difference(range.start).inDays ~/ 30 + 1;
      buckets = List.generate(months > 12 ? 12 : months, (i) {
        final start = DateTime(range.start.year, range.start.month + i, 1);
        final end = DateTime(start.year, start.month + 1, 0, 23, 59, 59);
        return ChartBucket(start, end, _monthAbbr(start.month), subLabel: '${start.year}');
      });
    } else {
      final days = range.end.difference(range.start).inDays + 1;
      buckets = List.generate(days, (i) {
        final d = range.start.add(Duration(days: i));
        return ChartBucket(d, d, '${d.day}', subLabel: 'Days');
      });
    }

    final points = buckets.map((b) => ChartPoint(b.label, 0, subLabel: b.subLabel)).toList();
    
    for (final bill in bills.where((b) => b.billType == type)) {
      final day = DateTime(bill.billDate.year, bill.billDate.month, bill.billDate.day);
      for (var i = 0; i < buckets.length; i++) {
        final b = buckets[i];
        final s = DateTime(b.start.year, b.start.month, b.start.day);
        if (!day.isBefore(s) && !day.isAfter(s)) {
          points[i] = ChartPoint(points[i].label, points[i].amount + bill.amount, subLabel: points[i].subLabel);
          break;
        }
      }
    }
    return points;
  }

  String _monthAbbr(int month) {
    const abbrs = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return abbrs[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final shopAsync = ref.watch(shopProvider);

    return shopAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (shop) {
        if (shop == null) return const SizedBox();

        return Column(
          children: [
            _DashboardAppBar(
              ownerName: shop.ownerName,
              shopName: shop.shopName,
              isEn: isEn,
            ),
            Expanded(
              child: FutureBuilder<_DashboardData>(
                future: _loadData(shop.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final data = snapshot.data ?? _DashboardData.empty();
                  final cTypeStr = ref.watch(chartTypeProvider);
                  final ChartType cType = cTypeStr == 'line' ? ChartType.line : cTypeStr == 'pie' ? ChartType.pie : ChartType.bar;

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(shopProvider);
                      setState(() {});
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1/3 Space: 2x2 Grid
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 2.3,
                              children: [
                                _gridCard(
                                  title: AppLang.tr(isEn, 'Sales', 'बिक्री'),
                                  amount: data.totalSales,
                                  color: AppColors.success,
                                  icon: Icons.trending_up_rounded,
                                  onTap: () => _gotoInvoice('sale', isEn),
                                ),
                                _gridCard(
                                  title: AppLang.tr(isEn, 'Purchase', 'खरीद'),
                                  amount: data.totalPurchase,
                                  color: AppColors.primary,
                                  icon: Icons.shopping_bag_rounded,
                                  onTap: () => _gotoInvoice('purchase', isEn),
                                ),
                                _gridCard(
                                  title: AppLang.tr(isEn, 'Credit', 'उधार'),
                                  amount: data.totalCredit,
                                  color: AppColors.purple,
                                  icon: Icons.account_balance_wallet_rounded,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UdharScreen())).then((_) => setState(() {}));
                                  },
                                ),
                                _gridCard(
                                  title: AppLang.tr(isEn, 'Low Stock', 'कम स्टॉक'),
                                  amount: data.lowStockCount.toDouble(),
                                  isCount: true,
                                  color: AppColors.error,
                                  icon: Icons.warning_rounded,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StockScreen())).then((_) => setState(() {}));
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // 1/3 Space: Charts
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppLang.tr(isEn, 'Analytics Overview', 'एनालिटिक्स अवलोकन'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _chartFilter,
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.primary),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                    items: [
                                      DropdownMenuItem(value: 'week', child: Text(AppLang.tr(isEn, 'This Week', 'इस हफ़्ते'))),
                                      DropdownMenuItem(value: 'month', child: Text(AppLang.tr(isEn, 'This Month', 'इस महीने'))),
                                      DropdownMenuItem(value: 'year', child: Text(AppLang.tr(isEn, 'This Year', 'इस साल'))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _chartFilter = val);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 220,
                              child: PageView(
                                controller: _chartsPageCtrl,
                                padEnds: false,
                                children: [
                                  _chartCard('Sales Trend', data.charts.sales, AppColors.success, cType),
                                  _chartCard('Purchase Trend', data.charts.purchases, AppColors.primary, cType),
                                  _chartCard('Sale Returns', data.saleReturnsPoints, AppColors.warning, cType),
                                  _chartCard('Purchase Returns', data.purchaseReturnsPoints, AppColors.purple, cType),
                                ],
                              ),
                            ),
                            // Small bottom padding
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _gridCard({required String title, required double amount, required Color color, required IconData icon, required VoidCallback onTap, bool isCount = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isCount ? amount.toInt().toString() : '₹${_compactMoney(amount)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(String title, List<ChartPoint> series, Color color, ChartType cType) {
    final hasData = series.any((p) => p.amount > 0);
    final peak = series.fold(0.0, (m, p) => p.amount > m ? p.amount : m);

    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Expanded(
            child: hasData ? _buildChart(series, color, peak, cType) : Center(child: Text('No Data', style: TextStyle(color: AppColors.textHint.withOpacity(0.5), fontSize: 12))),
          ),
        ],
      ),
    );
  }

  // --- CHART BUILDERS (Copied & simplified from charts_screen for Dashboard View) ---
  Widget _buildChart(List<ChartPoint> series, Color color, double peak, ChartType cType) {
    switch (cType) {
      case ChartType.line: return _lineChart(series, color, peak);
      case ChartType.bar: return _barChart(series, color, peak);
      case ChartType.pie: return _pieChart(series, color);
    }
  }

  Widget _lineChart(List<ChartPoint> series, Color color, double peak) {
    final maxY = peak <= 0 ? 1.0 : peak * 1.2;
    return LineChart(
      LineChartData(
        minY: 0, maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 32, interval: 1,
              getTitlesWidget: (v, m) {
                final idx = v.toInt();
                if (idx < 0 || idx >= series.length) return const SizedBox();
                return Transform.rotate(
                  angle: -math.pi / 2.5,
                  child: Text(series[idx].label, style: const TextStyle(fontSize: 8, color: AppColors.textHint)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('₹${_compactMoney(s.y)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i].amount)],
            isCurved: true, color: color, barWidth: 2.5, dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  Widget _barChart(List<ChartPoint> series, Color color, double peak) {
    final maxY = peak <= 0 ? 1.0 : peak * 1.2;
    return BarChart(
      BarChartData(
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 32, interval: 1,
              getTitlesWidget: (v, m) {
                final idx = v.toInt();
                if (idx < 0 || idx >= series.length) return const SizedBox();
                return Transform.rotate(
                  angle: -math.pi / 2.5,
                  child: Text(series[idx].label, style: const TextStyle(fontSize: 8, color: AppColors.textHint)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gIdx, r, rIdx) => BarTooltipItem('₹${_compactMoney(r.toY)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ),
        barGroups: [
          for (var i = 0; i < series.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: series[i].amount, width: 6, color: color, borderRadius: BorderRadius.circular(2))
            ]),
        ],
      ),
    );
  }

  Widget _pieChart(List<ChartPoint> series, Color baseColor) {
    final nonZero = <int>[];
    for (var i = 0; i < series.length; i++) if (series[i].amount > 0) nonZero.add(i);
    
    final hsl = HSLColor.fromColor(baseColor);
    final colors = List.generate(nonZero.length, (i) {
      final hue = (hsl.hue + i * (360.0 / math.max(nonZero.length, 1))) % 360;
      return HSLColor.fromAHSL(1, hue, hsl.saturation * 0.85, hsl.lightness).toColor();
    });

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2, centerSpaceRadius: 28,
              pieTouchData: PieTouchData(enabled: true),
              sections: [
                for (var j = 0; j < nonZero.length; j++)
                  PieChartSectionData(
                    value: series[nonZero[j]].amount, 
                    color: colors[j], 
                    radius: 34, 
                    showTitle: true,
                    title: _compactMoney(series[nonZero[j]].amount),
                    titleStyle: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)
                  ),
              ],
            ),
          ),
        ),
        if (nonZero.isNotEmpty) const SizedBox(width: 8),
        if (nonZero.isNotEmpty)
          SizedBox(
            width: 70,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: nonZero.length,
              itemBuilder: (context, j) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, color: colors[j]),
                    const SizedBox(width: 4),
                    Expanded(child: Text(series[nonZero[j]].label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _compactMoney(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _DashboardAppBar extends StatelessWidget {
  final String ownerName;
  final String shopName;
  final bool isEn;

  const _DashboardAppBar({
    required this.ownerName,
    required this.shopName,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLang.tr(isEn, 'Hello, $ownerName', 'Hello, $ownerName'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(shopName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardData {
  final double totalSales;
  final double totalPurchase;
  final double totalCredit;
  final int lowStockCount;
  final ChartsData charts;
  final List<ChartPoint> saleReturnsPoints;
  final List<ChartPoint> purchaseReturnsPoints;

  const _DashboardData({
    required this.totalSales,
    required this.totalPurchase,
    required this.totalCredit,
    required this.lowStockCount,
    required this.charts,
    required this.saleReturnsPoints,
    required this.purchaseReturnsPoints,
  });

  factory _DashboardData.empty() => _DashboardData(
        totalSales: 0,
        totalPurchase: 0,
        totalCredit: 0,
        lowStockCount: 0,
        charts: ChartsData.empty(),
        saleReturnsPoints: [],
        purchaseReturnsPoints: [],
      );
}
