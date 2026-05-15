import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../bills/invoice_list_screen.dart';
import '../udhar/udhar_screen.dart';

enum _DashboardType {
  sale,
  purchase,
  saleReturn,
  purchaseReturn,
  receivable,
}

enum _DateFilter {
  today,
  yesterday,
  lastWeek,
  previousMonth,
  thisMonth,
  currentYear,
  previousYear,
  custom,
}

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab>
    with SingleTickerProviderStateMixin {
  _DashboardType _selectedType = _DashboardType.sale;
  _DateFilter _filter = _DateFilter.thisMonth;
  DateTimeRange? _customRange;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    return shopAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final data = snapshot.data ?? _DashboardData.empty();
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(shopProvider);
                      setState(() {});
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          sliver: SliverList.separated(
                            itemCount: _DashboardType.values.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) => _summaryCard(
                              _DashboardType.values[index],
                              data,
                              isEn,
                            ),
                          ),
                        ),
                      ],
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

  Future<_DashboardData> _loadData(String shopId) async {
    final fy = _financialYearRange(DateTime.now());
    final results = await Future.wait<dynamic>([
      SupabaseService.getBills(shopId, fy.start, fy.end),
      SupabaseService.getSales(shopId, fy.start, fy.end),
      SupabaseService.getUdharCustomers(shopId),
    ]);

    return _DashboardData(
      bills: (results[0] as List<BillModel>),
      sales: (results[1] as List<SaleModel>),
      receivables: (results[2] as List<UdharCustomerModel>),
    );
  }

  Widget _summaryCard(_DashboardType type, _DashboardData data, bool isEn) {
    final total = data.financialYearTotal(type);
    final color = _typeColor(type);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _DashboardDetailScreen(
              type: type,
              data: data,
              isEn: isEn,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(type), color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _typeLabel(type, isEn),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FittedBox(
              alignment: Alignment.centerRight,
              fit: BoxFit.scaleDown,
              child: Text(
                '₹${total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 19),
          ],
        ),
      ),
    );
  }

  Widget _entryPanel(_DashboardData data, bool isEn) {
    final range = _selectedRange();
    final entries = data.entriesFor(_selectedType, range);
    final currentMode = _modeForIndex(_tabController.index);
    final filteredEntries =
        entries.where((entry) => entry.paymentMode == currentMode).toList();
    final total =
        filteredEntries.fold(0.0, (sum, entry) => sum + entry.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _typeLabel(_selectedType, isEn),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '₹${total.toStringAsFixed(0)} • ${filteredEntries.length} entries',
                          style: TextStyle(
                            fontSize: 12,
                            color: _typeColor(_selectedType),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_DateFilter>(
                      value: _filter,
                      borderRadius: BorderRadius.circular(12),
                      items: _DateFilter.values
                          .map(
                            (filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(_filterLabel(filter, isEn)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        if (value == _DateFilter.custom) {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: _customRange ?? range,
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked == null) return;
                          setState(() {
                            _customRange = picked;
                            _filter = value;
                          });
                          return;
                        }
                        setState(() => _filter = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              onTap: (_) => setState(() {}),
              tabs: const [
                Tab(text: 'Cash'),
                Tab(text: 'Credit'),
                Tab(text: 'UPI'),
              ],
            ),
            if (filteredEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: const [
                    Icon(Icons.receipt_long_outlined,
                        color: AppColors.textHint, size: 34),
                    SizedBox(height: 8),
                    Text(
                      'No entries found',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                itemCount: filteredEntries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _entryTile(filteredEntries[index], index),
              ),
          ],
        ),
      ),
    );
  }

  Widget _entryTile(_DashboardEntry entry, int index) {
    final color = _typeColor(_selectedType);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#${index + 1}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title.isEmpty ? 'Entry' : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDate(entry.date)} • ${entry.paymentMode.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${entry.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  DateTimeRange _selectedRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_filter) {
      case _DateFilter.today:
        return DateTimeRange(start: today, end: _endOfDay(today));
      case _DateFilter.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: yesterday, end: _endOfDay(yesterday));
      case _DateFilter.lastWeek:
        final start = today.subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: _endOfDay(today));
      case _DateFilter.previousMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case _DateFilter.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: _endOfDay(today),
        );
      case _DateFilter.currentYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: _endOfDay(today),
        );
      case _DateFilter.previousYear:
        return DateTimeRange(
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year - 1, 12, 31, 23, 59, 59),
        );
      case _DateFilter.custom:
        return _customRange ?? DateTimeRange(start: today, end: _endOfDay(today));
    }
  }

  DateTimeRange _financialYearRange(DateTime now) {
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    return DateTimeRange(
      start: DateTime(startYear, 4, 1),
      end: DateTime(startYear + 1, 3, 31, 23, 59, 59),
    );
  }

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  String _modeForIndex(int index) {
    switch (index) {
      case 1:
        return 'credit';
      case 2:
        return 'upi';
      default:
        return 'cash';
    }
  }

  void _showAddMenu(BuildContext context, bool isEn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(ctx).padding.bottom + 18,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _addMenuTile(ctx, isEn, _DashboardType.sale),
            _addMenuTile(ctx, isEn, _DashboardType.purchase),
            _addMenuTile(ctx, isEn, _DashboardType.saleReturn),
            _addMenuTile(ctx, isEn, _DashboardType.purchaseReturn),
            _addMenuTile(ctx, isEn, _DashboardType.receivable),
          ],
        ),
      ),
    );
  }

  Widget _addMenuTile(BuildContext sheetContext, bool isEn, _DashboardType type) {
    return ListTile(
      leading: Icon(_typeIcon(type), color: _typeColor(type)),
      title: Text(
        _typeLabel(type, isEn),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.pop(sheetContext);
        if (type == _DashboardType.receivable) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UdharScreen()),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceListScreen(
              billType: _billTypeValue(type),
              title: _typeLabel(type, true),
              titleHi: _typeLabel(type, false),
            ),
          ),
        ).then((_) => setState(() {}));
      },
    );
  }

  String _billTypeValue(_DashboardType type) {
    switch (type) {
      case _DashboardType.sale:
        return 'sale';
      case _DashboardType.purchase:
        return 'purchase';
      case _DashboardType.saleReturn:
        return 'sale_return';
      case _DashboardType.purchaseReturn:
        return 'purchase_return';
      case _DashboardType.receivable:
        return '';
    }
  }

  String _typeLabel(_DashboardType type, bool isEn) {
    switch (type) {
      case _DashboardType.sale:
        return AppLang.tr(isEn, 'Sale', 'Sale');
      case _DashboardType.purchase:
        return AppLang.tr(isEn, 'Purchase', 'Purchase');
      case _DashboardType.saleReturn:
        return AppLang.tr(isEn, 'Sale Return', 'Sale Return');
      case _DashboardType.purchaseReturn:
        return AppLang.tr(isEn, 'Purchase Return', 'Purchase Return');
      case _DashboardType.receivable:
        return AppLang.tr(isEn, 'Outstanding Receivable', 'Outstanding Receivable');
    }
  }

  String _filterLabel(_DateFilter filter, bool isEn) {
    switch (filter) {
      case _DateFilter.today:
        return AppLang.tr(isEn, 'Today', 'Today');
      case _DateFilter.yesterday:
        return AppLang.tr(isEn, 'Yesterday', 'Yesterday');
      case _DateFilter.lastWeek:
        return AppLang.tr(isEn, 'Last Week', 'Last Week');
      case _DateFilter.previousMonth:
        return AppLang.tr(isEn, 'Previous Month', 'Previous Month');
      case _DateFilter.thisMonth:
        return AppLang.tr(isEn, 'This Month', 'This Month');
      case _DateFilter.currentYear:
        return AppLang.tr(isEn, 'Current Year', 'Current Year');
      case _DateFilter.previousYear:
        return AppLang.tr(isEn, 'Previous Year', 'Previous Year');
      case _DateFilter.custom:
        return AppLang.tr(isEn, 'Custom Date', 'Custom Date');
    }
  }

  IconData _typeIcon(_DashboardType type) {
    switch (type) {
      case _DashboardType.sale:
        return Icons.trending_up_rounded;
      case _DashboardType.purchase:
        return Icons.shopping_bag_rounded;
      case _DashboardType.saleReturn:
        return Icons.assignment_return_rounded;
      case _DashboardType.purchaseReturn:
        return Icons.keyboard_return_rounded;
      case _DashboardType.receivable:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color _typeColor(_DashboardType type) {
    switch (type) {
      case _DashboardType.sale:
        return AppColors.success;
      case _DashboardType.purchase:
        return AppColors.primary;
      case _DashboardType.saleReturn:
        return AppColors.warning;
      case _DashboardType.purchaseReturn:
        return AppColors.purple;
      case _DashboardType.receivable:
        return AppColors.error;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _DashboardDetailScreen extends StatefulWidget {
  final _DashboardType type;
  final _DashboardData data;
  final bool isEn;

  const _DashboardDetailScreen({
    required this.type,
    required this.data,
    required this.isEn,
  });

  @override
  State<_DashboardDetailScreen> createState() => _DashboardDetailScreenState();
}

class _DashboardDetailScreenState extends State<_DashboardDetailScreen>
    with SingleTickerProviderStateMixin {
  _DateFilter _filter = _DateFilter.thisMonth;
  DateTimeRange? _customRange;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(widget.type);
    final range = _selectedRange();
    final entries = widget.data.entriesFor(widget.type, range);
    final mode = _modeForIndex(_tabController.index);
    final filteredEntries =
        entries.where((entry) => entry.paymentMode == mode).toList();
    final total =
        filteredEntries.fold(0.0, (sum, entry) => sum + entry.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_typeLabel(widget.type, widget.isEn)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_DateFilter>(
                value: _filter,
                dropdownColor: AppColors.surface,
                iconEnabledColor: Colors.white,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                selectedItemBuilder: (_) => _DateFilter.values
                    .map(
                      (filter) => Align(
                        alignment: Alignment.center,
                        child: Text(
                          _filterLabel(filter, widget.isEn),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                items: _DateFilter.values
                    .map(
                      (filter) => DropdownMenuItem(
                        value: filter,
                        child: Text(_filterLabel(filter, widget.isEn)),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  if (value == _DateFilter.custom) {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _customRange ?? range,
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.primary,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked == null) return;
                    setState(() {
                      _customRange = picked;
                      _filter = value;
                    });
                    return;
                  }
                  setState(() => _filter = value);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTarget,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            color: AppColors.surface,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon(widget.type), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${filteredEntries.length} entries • ${_filterLabel(_filter, widget.isEn)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              onTap: (_) => setState(() {}),
              tabs: const [
                Tab(text: 'Cash'),
                Tab(text: 'Credit'),
                Tab(text: 'UPI'),
              ],
            ),
          ),
          Expanded(
            child: filteredEntries.isEmpty
                ? const Center(
                    child: Text(
                      'No entries found',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _entryTile(filteredEntries[index], index, color),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _entryTile(_DashboardEntry entry, int index, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#${index + 1}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title.isEmpty ? 'Entry' : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDate(entry.date)} • ${entry.paymentMode.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${entry.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _openAddTarget() {
    if (widget.type == _DashboardType.receivable) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UdharScreen()),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceListScreen(
          billType: _billTypeValue(widget.type),
          title: _typeLabel(widget.type, true),
          titleHi: _typeLabel(widget.type, false),
        ),
      ),
    );
  }

  String _billTypeValue(_DashboardType type) {
    switch (type) {
      case _DashboardType.sale:
        return 'sale';
      case _DashboardType.purchase:
        return 'purchase';
      case _DashboardType.saleReturn:
        return 'sale_return';
      case _DashboardType.purchaseReturn:
        return 'purchase_return';
      case _DashboardType.receivable:
        return '';
    }
  }

  DateTimeRange _selectedRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_filter) {
      case _DateFilter.today:
        return DateTimeRange(start: today, end: _endOfDay(today));
      case _DateFilter.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: yesterday, end: _endOfDay(yesterday));
      case _DateFilter.lastWeek:
        final start = today.subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: _endOfDay(today));
      case _DateFilter.previousMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case _DateFilter.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: _endOfDay(today),
        );
      case _DateFilter.currentYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: _endOfDay(today),
        );
      case _DateFilter.previousYear:
        return DateTimeRange(
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year - 1, 12, 31, 23, 59, 59),
        );
      case _DateFilter.custom:
        return _customRange ??
            DateTimeRange(start: today, end: _endOfDay(today));
    }
  }

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  String _modeForIndex(int index) {
    switch (index) {
      case 1:
        return 'credit';
      case 2:
        return 'upi';
      default:
        return 'cash';
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _typeLabel(_DashboardType type, bool isEn) {
    switch (type) {
      case _DashboardType.sale:
        return AppLang.tr(isEn, 'Sale', 'Sale');
      case _DashboardType.purchase:
        return AppLang.tr(isEn, 'Purchase', 'Purchase');
      case _DashboardType.saleReturn:
        return AppLang.tr(isEn, 'Sale Return', 'Sale Return');
      case _DashboardType.purchaseReturn:
        return AppLang.tr(isEn, 'Purchase Return', 'Purchase Return');
      case _DashboardType.receivable:
        return AppLang.tr(
            isEn, 'Outstanding Receivable', 'Outstanding Receivable');
    }
  }

  String _filterLabel(_DateFilter filter, bool isEn) {
    switch (filter) {
      case _DateFilter.today:
        return AppLang.tr(isEn, 'Today', 'Today');
      case _DateFilter.yesterday:
        return AppLang.tr(isEn, 'Yesterday', 'Yesterday');
      case _DateFilter.lastWeek:
        return AppLang.tr(isEn, 'Last Week', 'Last Week');
      case _DateFilter.previousMonth:
        return AppLang.tr(isEn, 'Previous Month', 'Previous Month');
      case _DateFilter.thisMonth:
        return AppLang.tr(isEn, 'This Month', 'This Month');
      case _DateFilter.currentYear:
        return AppLang.tr(isEn, 'Current Year', 'Current Year');
      case _DateFilter.previousYear:
        return AppLang.tr(isEn, 'Previous Year', 'Previous Year');
      case _DateFilter.custom:
        return AppLang.tr(isEn, 'Custom Date', 'Custom Date');
    }
  }

  IconData _typeIcon(_DashboardType type) {
    switch (type) {
      case _DashboardType.sale:
        return Icons.trending_up_rounded;
      case _DashboardType.purchase:
        return Icons.shopping_bag_rounded;
      case _DashboardType.saleReturn:
        return Icons.assignment_return_rounded;
      case _DashboardType.purchaseReturn:
        return Icons.keyboard_return_rounded;
      case _DashboardType.receivable:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color _typeColor(_DashboardType type) {
    switch (type) {
      case _DashboardType.sale:
        return AppColors.success;
      case _DashboardType.purchase:
        return AppColors.primary;
      case _DashboardType.saleReturn:
        return AppColors.warning;
      case _DashboardType.purchaseReturn:
        return AppColors.purple;
      case _DashboardType.receivable:
        return AppColors.error;
    }
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
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 20,
      ),
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
                Text(
                  AppLang.tr(isEn, 'Hello, $ownerName', 'Hello, $ownerName'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardData {
  final List<BillModel> bills;
  final List<SaleModel> sales;
  final List<UdharCustomerModel> receivables;

  const _DashboardData({
    required this.bills,
    required this.sales,
    required this.receivables,
  });

  factory _DashboardData.empty() =>
      const _DashboardData(bills: [], sales: [], receivables: []);

  double financialYearTotal(_DashboardType type) {
    if (type == _DashboardType.receivable) {
      return receivables.fold(0.0, (sum, item) => sum + item.totalDue);
    }
    return bills
        .where((bill) => bill.billType == _billType(type))
        .fold(0.0, (sum, bill) => sum + bill.amount);
  }

  List<_DashboardEntry> entriesFor(_DashboardType type, DateTimeRange range) {
    if (type == _DashboardType.sale) {
      final saleEntries = sales
          .where((sale) => _inRange(sale.saleDate, range))
          .map(
            (sale) => _DashboardEntry(
              title: sale.itemName,
              amount: sale.totalAmount,
              date: sale.saleDate,
              paymentMode: _normalizeMode(sale.paymentMode),
            ),
          )
          .toList();

      final saleBillEntries = bills
          .where((bill) =>
              bill.billType == 'sale' &&
              _inRange(bill.billDate, range) &&
              !sales.any((sale) => sale.billId == bill.id))
          .map((bill) => _entryFromBill(bill))
          .toList();

      return [...saleEntries, ...saleBillEntries]
        ..sort((a, b) => b.date.compareTo(a.date));
    }

    if (type == _DashboardType.receivable) {
      return receivables
          .where((item) => _inRange(item.createdAt, range))
          .map(
            (item) => _DashboardEntry(
              title: item.customerName,
              amount: item.totalDue,
              date: item.createdAt,
              paymentMode: 'credit',
            ),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }

    return bills
        .where((bill) =>
            bill.billType == _billType(type) && _inRange(bill.billDate, range))
        .map((bill) => _entryFromBill(bill))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static _DashboardEntry _entryFromBill(BillModel bill) {
    return _DashboardEntry(
      title: bill.vendorName,
      amount: bill.amount,
      date: bill.billDate,
      paymentMode: 'cash',
    );
  }

  static String _billType(_DashboardType type) {
    switch (type) {
      case _DashboardType.sale:
        return 'sale';
      case _DashboardType.purchase:
        return 'purchase';
      case _DashboardType.saleReturn:
        return 'sale_return';
      case _DashboardType.purchaseReturn:
        return 'purchase_return';
      case _DashboardType.receivable:
        return '';
    }
  }

  static String _normalizeMode(String mode) {
    final lower = mode.toLowerCase();
    if (lower == 'upi') return 'upi';
    if (lower == 'credit' || lower == 'udhar') return 'credit';
    return 'cash';
  }

  static bool _inRange(DateTime date, DateTimeRange range) {
    final normalized = DateTime(date.year, date.month, date.day);
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }
}

class _DashboardEntry {
  final String title;
  final double amount;
  final DateTime date;
  final String paymentMode;

  const _DashboardEntry({
    required this.title,
    required this.amount,
    required this.date,
    required this.paymentMode,
  });
}
