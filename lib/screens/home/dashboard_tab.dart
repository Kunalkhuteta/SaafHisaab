import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../models/shop_access_model.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../bills/invoice_list_screen.dart';
import '../udhar/udhar_screen.dart';
import '../stock/stock_screen.dart';
import '../profile/profile_screen.dart';
import 'chart_data_helper.dart';
import 'package:saafhisaab/utils/indian_date_time.dart';

// ─────────────────────────────────────────────────────────────────────────
// All DATA / LOGIC below (Riverpod wiring, Supabase queries, role gating,
// chart-point building, language switching, navigation) is unchanged from
// the original DashboardTab. Only the widget tree (build methods, colors,
// card styling, chart styling, filter control) was restyled to match the
// new design reference.
// ─────────────────────────────────────────────────────────────────────────

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

  Future<_DashboardData> _loadData(String shopId, ShopRole? role) async {
    final now = IndianDateTime.now();

    // Default range for bills/cards (this month)
    final gridStart = IndianDateTime.date(now.year, now.month, 1);
    final gridEnd = IndianDateTime.date(now.year, now.month, now.day, 23, 59, 59);

    // Range for charts based on filter
    DateTime chartStart;
    DateTime chartEnd = gridEnd;
    ChartRange rangeType;

    if (_chartFilter == 'week') {
      chartStart = now.subtract(Duration(days: now.weekday - 1));
      chartStart = IndianDateTime.date(chartStart.year, chartStart.month, chartStart.day);
      rangeType = ChartRange.week;
    } else if (_chartFilter == 'year') {
      chartStart = IndianDateTime.date(now.year, 4, 1);
      if (now.month < 4) chartStart = IndianDateTime.date(now.year - 1, 4, 1);
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

    // Filter today's bills directly from the already-fetched allBills list
    final todayStr = IndianDateTime.now().toIso8601String().split('T')[0];
    final todayBills = allBills.where((b) => b.billDate.toIso8601String().split('T')[0] == todayStr).toList();

    // For staff members, we only count today's sales bills (since they are restricted from purchases and their card navigates to the sales list).
    // For others, we count all bills today.
    final todayBillCount = (role?.isStaff ?? false)
        ? todayBills.where((b) => b.billType == 'sale').length
        : todayBills.length;

    // Filter bills for grid cards (Month)
    final gridBills = allBills.where((b) => !b.billDate.isBefore(gridStart) && !b.billDate.isAfter(gridEnd)).toList();

    final gridBillIds = gridBills
        .where((b) => b.billType == 'sale' || b.billType == 'purchase')
        .map((b) => b.id)
        .where((id) => id.isNotEmpty)
        .toList();

    final Map<String, String> billPaymentModes = {};
    if (gridBillIds.isNotEmpty) {
      try {
        final salesData = await Supabase.instance.client
            .from('sales')
            .select('bill_id, payment_mode')
            .eq('shop_id', shopId)
            .inFilter('bill_id', gridBillIds);

        for (var row in salesData as List) {
          final bId = row['bill_id'] as String?;
          if (bId != null) {
            billPaymentModes[bId] = row['payment_mode'] ?? 'cash';
          }
        }
      } catch (e) {
        debugPrint('Error loading bill payment modes for dashboard: $e');
      }
    }

    double totalSales = 0;
    double totalPurchase = 0;
    double cashSales = 0;
    double creditSales = 0;
    double cashPurchase = 0;
    double creditPurchase = 0;

    for (final b in gridBills) {
      if (b.billType == 'sale') {
        totalSales += b.amount;
        final mode = billPaymentModes[b.id] ?? 'cash';
        if (mode == 'credit' || mode == 'split') {
          creditSales += b.amount;
        } else {
          cashSales += b.amount;
        }
      }
      if (b.billType == 'purchase') {
        totalPurchase += b.amount;
        final mode = billPaymentModes[b.id] ?? 'cash';
        if (mode == 'credit' || mode == 'split') {
          creditPurchase += b.amount;
        } else {
          cashPurchase += b.amount;
        }
      }
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
      cashSales: cashSales,
      creditSales: creditSales,
      cashPurchase: cashPurchase,
      creditPurchase: creditPurchase,
      totalCredit: totalCredit,
      lowStockCount: lowStock,
      todayBillCount: todayBillCount,
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
        final start = IndianDateTime.date(range.start.year, range.start.month + i, 1);
        final end = IndianDateTime.date(start.year, start.month + 1, 0, 23, 59, 59);
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
      final day = IndianDateTime.date(bill.billDate.year, bill.billDate.month, bill.billDate.day);
      for (var i = 0; i < buckets.length; i++) {
        final b = buckets[i];
        final s = IndianDateTime.date(b.start.year, b.start.month, b.start.day);
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

  // ── New palette tokens (visual only — layered on top of AppColors) ──────
  static const Color _bgLight = Color(0xFFFAFAFB);
  static const Color _navy = Color(0xFF1E2A45);
  static const Color _secondaryText = Color(0xFF9AA0AC);

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final shopAsync = ref.watch(shopProvider);
    final accessAsync = ref.watch(shopAccessProvider);
    final role = accessAsync.valueOrNull?.role;

    if (accessAsync.isLoading && role == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (accessAsync.hasError) {
      return Center(child: Text('Error: ${accessAsync.error}'));
    }
    if (role == null) {
      return const Center(child: Text('No shop access found.'));
    }

    return shopAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (shop) {
        if (shop == null) return const SizedBox();

        return Container(
          color: _bgLight,
          child: Column(
            children: [
              _DashboardAppBar(
                userName: ref.watch(currentUserNameProvider),
                shopName: shop.shopName,
                isEn: isEn,
              ),
              Expanded(
                child: FutureBuilder<_DashboardData>(
                  future: _loadData(shop.id, role),
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
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stat cards grid — same data/role gating as before, new card visual style
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.55,
                              children: [
                                if (role.isStaff)
                                  _gridCard(
                                    title: 'Today Bills',
                                    amount: data.todayBillCount.toDouble(),
                                    isCount: true,
                                    color: AppColors.success,
                                    icon: Icons.receipt_long_rounded,
                                    onTap: () => _gotoInvoice('sale', isEn),
                                  ),
                                if (!role.isStaff)
                                  _gridCard(
                                    title: AppLang.tr(isEn, 'Cash Sales', 'नकद बिक्री'),
                                    amount: data.cashSales,
                                    color: AppColors.success,
                                    icon: Icons.trending_up_rounded,
                                    onTap: () => _gotoInvoice('sale', isEn),
                                  ),
                                if (!role.isStaff)
                                  _gridCard(
                                    title: AppLang.tr(isEn, 'Credit Sales', 'उधार बिक्री'),
                                    amount: data.creditSales,
                                    color: AppColors.warning,
                                    icon: Icons.assignment_turned_in_rounded,
                                    onTap: () => _gotoInvoice('sale', isEn),
                                  ),
                                if (role.canViewPurchases)
                                  _gridCard(
                                    title: AppLang.tr(isEn, 'Cash Purchase', 'नकद खरीद'),
                                    amount: data.cashPurchase,
                                    color: AppColors.primary,
                                    icon: Icons.shopping_bag_rounded,
                                    onTap: () => _gotoInvoice('purchase', isEn),
                                  ),
                                if (role.canViewPurchases)
                                  _gridCard(
                                    title: AppLang.tr(isEn, 'Credit Purchase', 'उधार खरीद'),
                                    amount: data.creditPurchase,
                                    color: AppColors.primaryLight,
                                    icon: Icons.assignment_rounded,
                                    onTap: () => _gotoInvoice('purchase', isEn),
                                  ),
                                if (role.canViewUdhar)
                                  _gridCard(
                                    title: AppLang.tr(isEn, 'Total Udhar', 'कुल उधार'),
                                    amount: data.totalCredit,
                                    color: AppColors.purple,
                                    icon: Icons.account_balance_wallet_rounded,
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const UdharScreen())).then((_) => setState(() {}));
                                    },
                                  ),
                                if (role.canViewStock)
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
                            if (role.canViewReports) const SizedBox(height: 24),

                            // Analytics section — same 4 chart pages / filter values as before, new header + segmented control style
                            if (role.canViewReports) _buildOverviewHeader(isEn),
                            if (role.canViewReports) const SizedBox(height: 16),
                            if (role.canViewReports) SizedBox(
                              height: 240,
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
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Overview header: same three filter values (week/month/year), new
  // segmented-pill look instead of the old dropdown ─────────────────────
  Widget _buildOverviewHeader(bool isEn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppLang.tr(isEn, 'Analytics Overview', 'एनालिटिक्स अवलोकन'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _navy),
        ),
        _buildFilterPill(isEn),
      ],
    );
  }

  Widget _buildFilterPill(bool isEn) {
    final options = <String, String>{
      'week': AppLang.tr(isEn, 'Week', 'हफ़्ता'),
      'month': AppLang.tr(isEn, 'Month', 'महीना'),
      'year': AppLang.tr(isEn, 'Year', 'साल'),
    };
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.entries.map((e) {
          final selected = _chartFilter == e.key;
          return GestureDetector(
            onTap: () {
              if (_chartFilter != e.key) setState(() => _chartFilter = e.key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: selected
                    ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? _navy : _secondaryText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Stat card: same title/amount/color/icon/onTap contract as before,
  // new visual treatment (gradient icon avatar + big rounded shadow card) ─
  Widget _gridCard({required String title, required double amount, required Color color, required IconData icon, required VoidCallback onTap, bool isCount = false}) {
    final gradient = LinearGradient(
      colors: [color, Color.lerp(color, Colors.black, 0.25)!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isCount ? amount.toInt().toString() : '₹${_compactMoney(amount)}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _navy),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _secondaryText, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chart card: same title/series/color/type contract as before, new
  // rounded-20 white shadow card shell ─────────────────────────────────────
  Widget _chartCard(String title, List<ChartPoint> series, Color color, ChartType cType) {
    final hasData = series.any((p) => p.amount > 0);
    final peak = series.fold(0.0, (m, p) => p.amount > m ? p.amount : m);

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 12),
          Expanded(
            child: hasData ? _buildChart(series, color, peak, cType) : Center(child: Text('No Data', style: TextStyle(color: _secondaryText.withOpacity(0.6), fontSize: 12))),
          ),
        ],
      ),
    );
  }

  // --- CHART BUILDERS (unchanged data logic, restyled colors/decoration) ---
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
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: _flatGridLine,
        ),
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
                  child: Text(series[idx].label, style: const TextStyle(fontSize: 8, color: _secondaryText)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _navy,
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
    final darker = Color.lerp(color, Colors.black, 0.25)!;
    return BarChart(
      BarChartData(
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: _flatGridLine,
        ),
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
                  child: Text(series[idx].label, style: const TextStyle(fontSize: 8, color: _secondaryText)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _navy,
            getTooltipItem: (g, gIdx, r, rIdx) => BarTooltipItem('₹${_compactMoney(r.toY)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ),
        barGroups: [
          for (var i = 0; i < series.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: series[i].amount,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                gradient: LinearGradient(colors: [color, darker], begin: Alignment.bottomCenter, end: Alignment.topCenter),
              )
            ]),
        ],
      ),
    );
  }

  static FlLine _flatGridLine(double value) => const FlLine(color: Color(0xFFEAECF0), strokeWidth: 1);

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
                    titleStyle: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
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
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[j], shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(series[nonZero[j]].label, style: const TextStyle(fontSize: 9, color: _secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis)),
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

// ── App bar: same data/navigation as before (drawer, hello+shop name,
// settings → profile), restyled with rounded bottom corners + soft shadow
// to match the new design's rounder, softer visual language ────────────────
class _DashboardAppBar extends StatelessWidget {
  final String userName;
  final String shopName;
  final bool isEn;

  const _DashboardAppBar({
    required this.userName,
    required this.shopName,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1E2A45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLang.tr(isEn, 'Hello, $userName', 'Hello, $userName'),
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

// ── Data model — unchanged from the original ───────────────────────────────
class _DashboardData {
  final double totalSales;
  final double totalPurchase;
  final double cashSales;
  final double creditSales;
  final double cashPurchase;
  final double creditPurchase;
  final double totalCredit;
  final int lowStockCount;
  final int todayBillCount;
  final ChartsData charts;
  final List<ChartPoint> saleReturnsPoints;
  final List<ChartPoint> purchaseReturnsPoints;

  const _DashboardData({
    required this.totalSales,
    required this.totalPurchase,
    required this.cashSales,
    required this.creditSales,
    required this.cashPurchase,
    required this.creditPurchase,
    required this.totalCredit,
    required this.lowStockCount,
    required this.todayBillCount,
    required this.charts,
    required this.saleReturnsPoints,
    required this.purchaseReturnsPoints,
  });

  factory _DashboardData.empty() => _DashboardData(
        totalSales: 0,
        totalPurchase: 0,
        cashSales: 0,
        creditSales: 0,
        cashPurchase: 0,
        creditPurchase: 0,
        totalCredit: 0,
        lowStockCount: 0,
        todayBillCount: 0,
        charts: ChartsData.empty(),
        saleReturnsPoints: [],
        purchaseReturnsPoints: [],
      );
}