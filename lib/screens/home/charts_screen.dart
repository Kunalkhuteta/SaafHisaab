import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import 'chart_data_helper.dart';

class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});
  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen>
    with TickerProviderStateMixin {
  ChartRange _range = ChartRange.month;
  ChartType _chartType = ChartType.bar;
  DateTimeRange? _customRange;
  late final TabController _dataTabCtrl;
  int _touchedPieIndex = -1;

  Future<ChartsData>? _chartsFuture;
  ChartRange? _lastRange;
  String? _lastShopId;
  DateTimeRange? _lastCustomRange;

  @override
  void initState() {
    super.initState();
    _dataTabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _dataTabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final shopAsync = ref.watch(shopProvider);
    return Column(children: [
      _buildHeader(isEn),
      Expanded(
        child: shopAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (shop) {
            if (shop == null) return const SizedBox();
            final range = _selectedRange();
            
            if (_chartsFuture == null || _lastShopId != shop.id || _lastRange != _range || _lastCustomRange != _customRange) {
              _lastShopId = shop.id;
              _lastRange = _range;
              _lastCustomRange = _customRange;
              _chartsFuture = _loadData(shop.id, range);
            }

            return FutureBuilder<ChartsData>(
              future: _chartsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                return _body(snap.data ?? ChartsData.empty(), range, isEn);
              },
            );
          },
        ),
      ),
    ]);
  }

  // ─── HEADER ───
  Widget _buildHeader(bool isEn) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20, right: 20, bottom: 14,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Scaffold.of(context).openDrawer(),
          child: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            AppLang.tr(isEn, 'Analytics', 'Analytics'),
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white,
            ),
          ),
        ),
        _rangeChip(isEn),
      ]),
    );
  }

  Widget _rangeChip(bool isEn) {
    return PopupMenuButton<ChartRange>(
      initialValue: _range,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) async {
        if (v == ChartRange.custom) {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: _customRange ?? _selectedRange(),
            builder: (c, child) => Theme(
              data: Theme.of(c).copyWith(
                  colorScheme:
                      const ColorScheme.light(primary: AppColors.primary)),
              child: child!,
            ),
          );
          if (picked == null) return;
          setState(() { _customRange = picked; _range = v; });
          return;
        }
        setState(() => _range = v);
      },
      itemBuilder: (_) => ChartRange.values
          .map((r) => PopupMenuItem(value: r, child: Text(_rangeLabel(r, isEn))))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_rangeLabel(_range, isEn),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white, size: 16),
        ]),
      ),
    );
  }

  // ─── BODY ───
  Widget _body(ChartsData data, DateTimeRange range, bool isEn) {
    final tab = ChartTab.values[_dataTabCtrl.index];
    final series = data.seriesFor(tab);
    final color = _tabColor(tab);
    final total = series.fold(0.0, (s, p) => s + p.amount);
    final avg = series.isEmpty ? 0.0 : total / series.length;
    final peak =
        series.fold(0.0, (m, p) => p.amount > m ? p.amount : m);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        setState(() {
          _chartsFuture = null; // Force reload
        });
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          // Metric cards
          Row(children: [
            Expanded(child: _metricCard('Total', total, color, Icons.account_balance_wallet_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _metricCard('Average', avg, AppColors.purple, Icons.trending_flat_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _metricCard('Peak', peak, AppColors.warning, Icons.trending_up_rounded)),
          ]),
          const SizedBox(height: 14),

          // Data category tabs
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _dataTabCtrl,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              onTap: (_) => setState(() {}),
              dividerHeight: 0,
              tabs: const [
                Tab(text: 'Sale'),
                Tab(text: 'Purchase'),
                Tab(text: 'Returns'),
                Tab(text: 'Credit'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Chart container
          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(children: [
              // Sub-label (e.g. "May Days")
              if (series.isNotEmpty && series.first.subLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    series.first.subLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SizedBox(
                height: _chartType == ChartType.pie ? 260 : 280,
                child: _hasData(series) ? _buildChart(series, color, peak) : _emptyState(),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Chart type switcher
          _chartTypeSwitcher(color),
          const SizedBox(height: 12),

          // Date range label
          Text(
            '${_fmtDate(range.start)} – ${_fmtDate(range.end)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── CHART TYPE SWITCHER ───
  Widget _chartTypeSwitcher(Color activeColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: ChartType.values.map((t) {
          final selected = t == _chartType;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _chartType = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? activeColor.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(color: activeColor.withOpacity(0.3))
                      : null,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                    t == ChartType.line
                        ? Icons.show_chart_rounded
                        : t == ChartType.bar
                            ? Icons.bar_chart_rounded
                            : Icons.pie_chart_rounded,
                    size: 18,
                    color: selected ? activeColor : AppColors.textHint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t == ChartType.line ? 'Line' : t == ChartType.bar ? 'Bar' : 'Pie',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? activeColor : AppColors.textSecondary,
                    ),
                  ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── CHART BUILDERS ───
  Widget _buildChart(List<ChartPoint> series, Color color, double peak) {
    switch (_chartType) {
      case ChartType.line:
        return _lineChart(series, color, peak);
      case ChartType.bar:
        return _barChart(series, color, peak);
      case ChartType.pie:
        return _pieChart(series, color);
    }
  }

  Widget _lineChart(List<ChartPoint> series, Color color, double peak) {
    final maxY = peak <= 0 ? 1.0 : peak * 1.2;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          clipData: const FlClipData.all(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppColors.border.withOpacity(0.6),
              strokeWidth: 0.8,
              dashArray: [4, 4],
            ),
          ),
          titlesData: _titlesData(series, maxY),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              tooltipRoundedRadius: 10,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '₹${_compactMoney(s.y)}',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < series.length; i++)
                  FlSpot(i.toDouble(), series[i].amount)
              ],
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: series.length <= 15,
                getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                  radius: 3.5,
                  color: AppColors.surface,
                  strokeWidth: 2.5,
                  strokeColor: color,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _barChart(List<ChartPoint> series, Color color, double peak) {
    final maxY = peak <= 0 ? 1.0 : peak * 1.22;
    final barW = series.length > 20 ? 8.0 : series.length > 10 ? 12.0 : 18.0;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.border.withOpacity(0.6),
            strokeWidth: 0.8,
            dashArray: [4, 4],
          ),
        ),
        titlesData: _titlesData(series, maxY),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary,
            tooltipRoundedRadius: 10,
            getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
              '₹${_compactMoney(r.toY)}',
              const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < series.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: series[i].amount,
                width: barW,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [color.withOpacity(0.55), color],
                ),
              ),
            ]),
        ],
      ),
      swapAnimationDuration: const Duration(milliseconds: 500),
      swapAnimationCurve: Curves.easeOutCubic,
    );
  }

  Widget _pieChart(List<ChartPoint> series, Color baseColor) {
    final nonZero = <int>[];
    for (var i = 0; i < series.length; i++) {
      if (series[i].amount > 0) nonZero.add(i);
    }
    if (nonZero.isEmpty) return _emptyState();

    final colors = _generatePieColors(baseColor, nonZero.length);
    final total = nonZero.fold(0.0, (s, i) => s + series[i].amount);

    return Row(children: [
      Expanded(
        flex: 3,
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (evt, resp) {
                setState(() {
                  if (!evt.isInterestedForInteractions ||
                      resp == null ||
                      resp.touchedSection == null) {
                    _touchedPieIndex = -1;
                  } else {
                    _touchedPieIndex =
                        resp.touchedSection!.touchedSectionIndex;
                  }
                });
              },
            ),
            sectionsSpace: 2,
            centerSpaceRadius: 36,
            sections: [
              for (var j = 0; j < nonZero.length; j++)
                PieChartSectionData(
                  value: series[nonZero[j]].amount,
                  color: colors[j],
                  radius: _touchedPieIndex == j ? 56 : 48,
                  title: _touchedPieIndex == j
                      ? '${(series[nonZero[j]].amount / total * 100).toStringAsFixed(0)}%'
                      : '',
                  titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
            ],
          ),
          swapAnimationDuration: const Duration(milliseconds: 400),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var j = 0; j < nonZero.length && j < 8; j++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: colors[j],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        series[nonZero[j]].label,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              if (nonZero.length > 8)
                Text(
                  '+${nonZero.length - 8} more',
                  style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  // ─── SHARED TITLES ───
  FlTitlesData _titlesData(List<ChartPoint> series, double maxY) {
    final showEvery = series.length > 15 ? 3 : series.length > 8 ? 2 : 1;
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: maxY / 4,
          getTitlesWidget: (v, meta) {
            if (v == maxY) return const SizedBox();
            return Text(
              _compactMoney(v),
              style: const TextStyle(color: AppColors.textHint, fontSize: 10),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= series.length) return const SizedBox();
            if (idx % showEvery != 0) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  series[idx].label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── METRIC CARD ───
  Widget _metricCard(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '₹${_compactMoney(value)}',
            style: TextStyle(
                fontSize: 16, color: color, fontWeight: FontWeight.w900),
          ),
        ),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.analytics_outlined, size: 40, color: AppColors.textHint.withOpacity(0.4)),
        const SizedBox(height: 8),
        const Text('No data available',
            style: TextStyle(
                color: AppColors.textHint,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ]),
    );
  }

  // ─── HELPERS ───
  bool _hasData(List<ChartPoint> s) => s.any((p) => p.amount > 0);

  List<Color> _generatePieColors(Color base, int count) {
    final hsl = HSLColor.fromColor(base);
    return List.generate(count, (i) {
      final hue = (hsl.hue + i * (360.0 / math.max(count, 1))) % 360;
      return HSLColor.fromAHSL(1, hue, hsl.saturation * 0.85, hsl.lightness)
          .toColor();
    });
  }

  Future<ChartsData> _loadData(String shopId, DateTimeRange range) async {
    final results = await Future.wait<dynamic>([
      SupabaseService.getBills(shopId, range.start, range.end),
      SupabaseService.getSales(shopId, range.start, range.end),
      SupabaseService.getUdharCustomers(shopId),
    ]);
    return ChartsData.from(
      bills: (results[0] as List).cast(),
      sales: (results[1] as List).cast(),
      receivables: (results[2] as List).cast(),
      range: range,
      rangeType: _range,
    );
  }

  DateTimeRange _selectedRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case ChartRange.week:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 6)),
            end: _eod(today));
      case ChartRange.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: _eod(today));
      case ChartRange.year:
        return DateTimeRange(
            start: DateTime(now.year, 1, 1), end: _eod(today));
      case ChartRange.custom:
        return _customRange ??
            DateTimeRange(
                start: DateTime(now.year, now.month, 1), end: today);
    }
  }

  DateTime _eod(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  Color _tabColor(ChartTab tab) {
    switch (tab) {
      case ChartTab.sale: return AppColors.success;
      case ChartTab.purchase: return AppColors.primary;
      case ChartTab.returns: return AppColors.warning;
      case ChartTab.credit: return AppColors.purple;
    }
  }

  String _rangeLabel(ChartRange r, bool isEn) {
    switch (r) {
      case ChartRange.week: return AppLang.tr(isEn, 'Week', 'Week');
      case ChartRange.month: return AppLang.tr(isEn, 'Month', 'Month');
      case ChartRange.year: return AppLang.tr(isEn, 'Year', 'Year');
      case ChartRange.custom: return AppLang.tr(isEn, 'Custom', 'Custom');
    }
  }

  String _compactMoney(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_mNames[d.month - 1]} ${d.year}';

  static const _mNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
}
