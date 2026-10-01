import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../utils/indian_date_time.dart';

enum CashDateFilter {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  prevMonth,
  allTime,
  custom,
}

class PartyCashSummary {
  final int rank;
  final String partyName;
  final String phone;
  final double totalCashReceived;
  final int paymentCount;
  final DateTime lastPaymentDate;
  final int inactiveDays;

  const PartyCashSummary({
    required this.rank,
    required this.partyName,
    required this.phone,
    required this.totalCashReceived,
    required this.paymentCount,
    required this.lastPaymentDate,
    required this.inactiveDays,
  });

  String get lastPaymentFormatted => DateFormat('dd MMM yyyy').format(lastPaymentDate);

  String get inactiveText {
    if (inactiveDays <= 0) return 'Paid Today';
    if (inactiveDays == 1) return '1d ago';
    return '${inactiveDays}d ago';
  }
}

class CashTransaction {
  final String id;
  final String partyName;
  final double amount;
  final DateTime date;
  final String type; // 'Udhar Payment', 'Cash Sale'
  final String note;

  const CashTransaction({
    required this.id,
    required this.partyName,
    required this.amount,
    required this.date,
    required this.type,
    required this.note,
  });
}

class CashReceivedFromPartyScreen extends ConsumerStatefulWidget {
  const CashReceivedFromPartyScreen({super.key});

  @override
  ConsumerState<CashReceivedFromPartyScreen> createState() => _CashReceivedFromPartyScreenState();
}

class _CashReceivedFromPartyScreenState extends ConsumerState<CashReceivedFromPartyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CashDateFilter _dateFilter = CashDateFilter.thisMonth;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  bool _isLoading = true;
  String? _errorMessage;

  List<PartyCashSummary> _partySummaries = [];
  List<CashTransaction> _transactions = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _applyDateFilter(CashDateFilter.thisMonth);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyDateFilter(CashDateFilter filter) {
    final now = IndianDateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (filter) {
      case CashDateFilter.today:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case CashDateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day, 0, 0, 0);
        end = DateTime(y.year, y.month, y.day, 23, 59, 59);
        break;
      case CashDateFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
        break;
      case CashDateFilter.thisMonth:
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        break;
      case CashDateFilter.prevMonth:
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        start = DateTime(prevYear, prevMonth, 1, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month, 0).day;
        end = DateTime(prevYear, prevMonth, lastDay, 23, 59, 59);
        break;
      case CashDateFilter.allTime:
        start = DateTime(2020, 1, 1, 0, 0, 0);
        break;
      case CashDateFilter.custom:
        start = _fromDate;
        end = _toDate;
        break;
    }

    setState(() {
      _dateFilter = filter;
      _fromDate = start;
      _toDate = end;
    });

    _loadCashData();
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
        _dateFilter = CashDateFilter.custom;
        _fromDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadCashData();
    }
  }

  Future<void> _loadCashData() async {
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
      final now = IndianDateTime.now();

      // 1. Fetch customer names lookup for udhar entries
      final customerMap = <String, Map<String, String>>{};
      try {
        final custData = await client
            .from('udhar_customers')
            .select('id, customer_name, customer_phone')
            .eq('shop_id', shop.id);
        for (final c in custData) {
          final id = c['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            customerMap[id] = {
              'name': (c['customer_name'] ?? 'Customer').toString().trim(),
              'phone': (c['customer_phone'] ?? '').toString().trim(),
            };
          }
        }
      } catch (e) {
        debugPrint('Customer map load error: $e');
      }

      // 2. Fetch udhar payments received (entry_type = 'debit')
      final List<CashTransaction> allCashTxns = [];

      try {
        final udharPayments = await client
            .from('udhar_entries')
            .select()
            .eq('shop_id', shop.id)
            .eq('entry_type', 'debit')
            .gte('entry_date', fromStr)
            .lte('entry_date', toStr)
            .order('entry_date', ascending: false);

        for (final u in udharPayments) {
          final cId = u['customer_id']?.toString() ?? '';
          final custInfo = customerMap[cId];
          final party = custInfo != null && custInfo['name']!.isNotEmpty
              ? custInfo['name']!
              : 'Direct Party';
          final amt = (u['amount'] as num?)?.toDouble() ?? 0.0;
          final date = IndianDateTime.parse(u['entry_date']);
          final note = (u['note'] ?? '').toString();

          allCashTxns.add(CashTransaction(
            id: u['id']?.toString() ?? '',
            partyName: party,
            amount: amt,
            date: date,
            type: 'Udhar Payment',
            note: note,
          ));
        }
      } catch (e) {
        debugPrint('Udhar payments load error: $e');
      }

      // 3. Fetch cash sales bills
      try {
        final cashBills = await client
            .from('bills')
            .select()
            .eq('shop_id', shop.id)
            .eq('bill_type', 'sale')
            .gte('bill_date', fromStr)
            .lte('bill_date', toStr)
            .order('bill_date', ascending: false);

        for (final b in cashBills) {
          final notes = (b['notes'] ?? '').toString().toLowerCase();
          // Include if notes explicitly indicate cash or if standard cash sale
          final isCredit = notes.contains('credit') || notes.contains('__credit_party__');
          if (!isCredit) {
            final vendor = (b['vendor_name'] ?? 'Walk-in Customer').toString().trim();
            final amt = (b['amount'] as num?)?.toDouble() ?? 0.0;
            final date = IndianDateTime.parse(b['bill_date']);

            allCashTxns.add(CashTransaction(
              id: b['id']?.toString() ?? '',
              partyName: vendor.isNotEmpty ? vendor : 'Counter Customer',
              amount: amt,
              date: date,
              type: 'Cash Sale',
              note: b['notes'] ?? '',
            ));
          }
        }
      } catch (e) {
        debugPrint('Cash bills load error: $e');
      }

      // Sort transactions newest first
      allCashTxns.sort((a, b) => b.date.compareTo(a.date));
      _transactions = allCashTxns;

      // Group into party-wise summaries
      final Map<String, _PartyCashAcc> accMap = {};
      for (final t in _transactions) {
        final key = t.partyName.toLowerCase();
        final acc = accMap.putIfAbsent(key, () => _PartyCashAcc(name: t.partyName));
        acc.amount += t.amount;
        acc.count += 1;
        if (acc.lastDate == null || t.date.isAfter(acc.lastDate!)) {
          acc.lastDate = t.date;
        }
      }

      final list = accMap.values.toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

      _partySummaries = list.asMap().entries.map((entry) {
        final acc = entry.value;
        final inactive = acc.lastDate != null ? now.difference(acc.lastDate!).inDays : 0;
        return PartyCashSummary(
          rank: entry.key + 1,
          partyName: acc.name,
          phone: '',
          totalCashReceived: acc.amount,
          paymentCount: acc.count,
          lastPaymentDate: acc.lastDate ?? now,
          inactiveDays: inactive,
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

  void _shareCashReport() {
    final isEn = ref.read(appLanguageProvider);
    final total = _transactions.fold(0.0, (sum, t) => sum + t.amount);

    String msg = '💵 *SaafHisaab — Cash Received Report*\n';
    msg += '📅 Period: ${_getFilterLabel(isEn)}\n';
    msg += '💰 Total Cash Received: ${_currencyFmt.format(total)}\n';
    msg += '────────────────────\n\n';

    for (final p in _partySummaries.take(8)) {
      msg += '#${p.rank} *${p.partyName}*: ${_currencyFmt.format(p.totalCashReceived)} (${p.paymentCount} payments)\n';
    }

    msg += '\n_Generated via SaafHisaab — Aapki dukaan ka saaf hisaab_';
    Share.share(msg, subject: 'Cash Received Report');
  }

  String _getFilterLabel(bool isEn) {
    switch (_dateFilter) {
      case CashDateFilter.today:
        return AppLang.tr(isEn, 'Today', 'आज');
      case CashDateFilter.yesterday:
        return AppLang.tr(isEn, 'Yesterday', 'कल');
      case CashDateFilter.thisWeek:
        return AppLang.tr(isEn, 'This Week', 'इस सप्ताह');
      case CashDateFilter.thisMonth:
        return AppLang.tr(isEn, 'This Month', 'इस महीने');
      case CashDateFilter.prevMonth:
        return AppLang.tr(isEn, 'Last Month', 'पिछला महीना');
      case CashDateFilter.allTime:
        return AppLang.tr(isEn, 'All Time', 'सभी समय');
      case CashDateFilter.custom:
        final fmt = DateFormat('dd MMM');
        return '${fmt.format(_fromDate)} - ${fmt.format(_toDate)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final totalCash = _transactions.fold(0.0, (sum, t) => sum + t.amount);
    final totalCount = _transactions.length;
    final topParty = _partySummaries.isNotEmpty ? _partySummaries.first.partyName : '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppLang.tr(isEn, 'Cash Received from Party', 'पार्टी से प्राप्त नकद'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: AppLang.tr(isEn, 'Share Report', 'शेयर करें'),
            onPressed: _shareCashReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: AppLang.tr(isEn, 'Refresh', 'ताज़ा करें'),
            onPressed: _loadCashData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: [
                Tab(text: AppLang.tr(isEn, 'Party Summary', 'पार्टी सारांश')),
                Tab(text: AppLang.tr(isEn, 'All Transactions', 'सभी लेनदेन')),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Date Filter Ribbon
          _buildDateFilterBar(isEn),

          // Slim Cash KPI Banner
          Container(
            margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.15),
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
                      AppLang.tr(isEn, 'Total Cash Collected', 'कुल नकद वसूली'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _currencyFmt.format(totalCash),
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
                        '$totalCount ${AppLang.tr(isEn, 'Txns', 'लेनदेन')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Top: $topParty',
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
              ],
            ),
          ),

          // Search Bar
          _buildSearchBar(isEn),

          // Tab Views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? _buildErrorView(isEn)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPartySummaryTab(isEn),
                          _buildTransactionsTab(isEn),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterBar(bool isEn) {
    final filters = [
      {'type': CashDateFilter.thisMonth, 'label': AppLang.tr(isEn, 'This Month', 'इस महीने')},
      {'type': CashDateFilter.today, 'label': AppLang.tr(isEn, 'Today', 'आज')},
      {'type': CashDateFilter.yesterday, 'label': AppLang.tr(isEn, 'Yesterday', 'कल')},
      {'type': CashDateFilter.thisWeek, 'label': AppLang.tr(isEn, 'This Week', 'इस सप्ताह')},
      {'type': CashDateFilter.prevMonth, 'label': AppLang.tr(isEn, 'Last Month', 'पिछला महीना')},
      {'type': CashDateFilter.allTime, 'label': AppLang.tr(isEn, 'All Time', 'सभी समय')},
      {'type': CashDateFilter.custom, 'label': AppLang.tr(isEn, 'Custom', 'कस्टम')},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final type = f['type'] as CashDateFilter;
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
                onSelected: (_) {
                  if (type == CashDateFilter.custom) {
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

  Widget _buildSearchBar(bool isEn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: AppLang.tr(isEn, 'Search party name...', 'पार्टी का नाम खोजें...'),
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
    );
  }

  Widget _buildPartySummaryTab(bool isEn) {
    var list = _partySummaries;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((p) => p.partyName.toLowerCase().contains(q)).toList();
    }

    if (list.isEmpty) {
      return _buildEmptyView(isEn);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final p = list[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${p.rank}',
                  style: const TextStyle(
                    color: Color(0xFF059669),
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
                      p.partyName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${p.paymentCount} payments',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Last: ${p.lastPaymentFormatted} (${p.inactiveText})',
                            style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _currencyFmt.format(p.totalCashReceived),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab(bool isEn) {
    var list = _transactions;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((t) => t.partyName.toLowerCase().contains(q) || t.note.toLowerCase().contains(q)).toList();
    }

    if (list.isEmpty) {
      return _buildEmptyView(isEn);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final t = list[index];
        final timeStr = DateFormat('dd MMM, hh:mm a').format(t.date);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: t.type == 'Udhar Payment' ? AppColors.surfaceBlue : const Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  t.type == 'Udhar Payment' ? Icons.receipt_long_rounded : Icons.point_of_sale_rounded,
                  size: 16,
                  color: t.type == 'Udhar Payment' ? AppColors.primary : AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.partyName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$timeStr • ${t.type}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                '+${_currencyFmt.format(t.amount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyView(bool isEn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payments_outlined, size: 40, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              AppLang.tr(isEn, 'No Cash Received in This Period', 'इस अवधि में कोई नकद प्राप्ति नहीं हुई'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              AppLang.tr(isEn, 'Try selecting "All Time" to view past collections.', 'पिछला संग्रह देखने के लिए "सभी समय" चुनें।'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _applyDateFilter(CashDateFilter.allTime),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text(AppLang.tr(isEn, 'Switch to All Time', 'सभी समय देखें')),
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
              AppLang.tr(isEn, 'Failed to load cash receipts', 'डेटा लोड करने में त्रुटि'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(_errorMessage ?? '', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadCashData,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text(AppLang.tr(isEn, 'Retry', 'पुनः प्रयास करें')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyCashAcc {
  final String name;
  double amount = 0;
  int count = 0;
  DateTime? lastDate;
  _PartyCashAcc({required this.name});
}
