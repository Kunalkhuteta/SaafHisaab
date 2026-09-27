import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/bill_model.dart';
import '../../models/shop_model.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/party_wise_sales_html_template.dart';
import '../../utils/indian_date_time.dart';
import 'party_sale_detail_screen.dart';

enum DateFilterType {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  previousMonth,
  currentYear,
  custom,
}

class PartyWiseSalesReportScreen extends ConsumerStatefulWidget {
  const PartyWiseSalesReportScreen({super.key});

  @override
  ConsumerState<PartyWiseSalesReportScreen> createState() => _PartyWiseSalesReportScreenState();
}

class _PartyWiseSalesReportScreenState extends ConsumerState<PartyWiseSalesReportScreen> {
  DateFilterType _selectedFilter = DateFilterType.today;
  DateTime _fromDate = IndianDateTime.now();
  DateTime _toDate = IndianDateTime.now();

  bool _isLoading = true;
  String? _errorMessage;
  List<PartySaleSummary> _allParties = [];
  List<PartySaleSummary> _filteredParties = [];

  final TextEditingController _searchController = TextEditingController();
  String _sortMode = 'amount_desc'; // 'amount_desc', 'due_desc', 'bills_desc', 'name_asc'

  @override
  void initState() {
    super.initState();
    _applyFilter(DateFilterType.today);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter(DateFilterType filter) {
    final now = IndianDateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (filter) {
      case DateFilterType.today:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case DateFilterType.yesterday:
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day, 0, 0, 0);
        end = DateTime(y.year, y.month, y.day, 23, 59, 59);
        break;
      case DateFilterType.thisWeek:
        // Start from Monday of this week
        final weekday = now.weekday; // 1 = Monday, 7 = Sunday
        final monday = now.subtract(Duration(days: weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
        break;
      case DateFilterType.thisMonth:
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        break;
      case DateFilterType.previousMonth:
        final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        start = DateTime(prevMonthYear, prevMonth, 1, 0, 0, 0);
        final lastDayOfPrevMonth = DateTime(now.year, now.month, 0).day;
        end = DateTime(prevMonthYear, prevMonth, lastDayOfPrevMonth, 23, 59, 59);
        break;
      case DateFilterType.currentYear:
        start = DateTime(now.year, 1, 1, 0, 0, 0);
        break;
      case DateFilterType.custom:
        // Keep current custom range
        start = _fromDate;
        break;
    }

    setState(() {
      _selectedFilter = filter;
      _fromDate = start;
      _toDate = end;
    });

    _fetchReportData();
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
        _selectedFilter = DateFilterType.custom;
        _fromDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _fetchReportData();
    }
  }

  String _getFilterLabel() {
    final isEn = ref.read(appLanguageProvider);
    switch (_selectedFilter) {
      case DateFilterType.today:
        return AppLang.tr(isEn, 'Today', 'आज');
      case DateFilterType.yesterday:
        return AppLang.tr(isEn, 'Yesterday', 'कल');
      case DateFilterType.thisWeek:
        return AppLang.tr(isEn, 'This Week', 'इस सप्ताह');
      case DateFilterType.thisMonth:
        return AppLang.tr(isEn, 'This Month', 'इस महीने');
      case DateFilterType.previousMonth:
        return AppLang.tr(isEn, 'Previous Month', 'पिछला महीना');
      case DateFilterType.currentYear:
        return AppLang.tr(isEn, 'Current Year', 'इस वर्ष');
      case DateFilterType.custom:
        final fmt = DateFormat('dd/MM');
        return '${fmt.format(_fromDate)} - ${fmt.format(_toDate)}';
    }
  }

  Future<void> _fetchReportData() async {
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

      // 1. Fetch sale bills in range
      final billsData = await client
          .from('bills')
          .select()
          .eq('shop_id', shop.id)
          .eq('bill_type', 'sale')
          .gte('bill_date', fromStr)
          .lte('bill_date', toStr)
          .order('bill_date', ascending: false);

      final List<BillModel> bills = (billsData as List).map((b) => BillModel.fromJson(b)).toList();

      // 2. Fetch line items for these bills
      final billIds = bills.map((b) => b.id).where((id) => id.isNotEmpty).toList();
      List<dynamic> salesRows = [];
      if (billIds.isNotEmpty) {
        salesRows = await client
            .from('sales')
            .select()
            .eq('shop_id', shop.id)
            .inFilter('bill_id', billIds);
      }

      // Group sales line items by bill_id
      final Map<String, List<Map<String, dynamic>>> itemsByBillId = {};
      for (final s in salesRows) {
        final bId = s['bill_id']?.toString() ?? '';
        if (bId.isNotEmpty) {
          itemsByBillId.putIfAbsent(bId, () => []).add(Map<String, dynamic>.from(s));
        }
      }

      // 3. Customer metadata lookup (phones / address)
      Map<String, Map<String, dynamic>> customersByName = {};
      try {
        final custData = await client
            .from('udhar_customers')
            .select('name, phone, address')
            .eq('shop_id', shop.id);
        for (final c in custData as List) {
          final cName = (c['name']?.toString() ?? '').trim().toLowerCase();
          if (cName.isNotEmpty) {
            customersByName[cName] = Map<String, dynamic>.from(c);
          }
        }
      } catch (e) {
        debugPrint('Customer lookup error: $e');
      }

      // 4. Group bills and items by Party Name
      final Map<String, List<BillModel>> billsByParty = {};
      for (final b in bills) {
        final rawName = b.vendorName.trim();
        final partyName = rawName.isNotEmpty ? rawName : 'Walk-in Customer';
        billsByParty.putIfAbsent(partyName, () => []).add(b);
      }

      final List<PartySaleSummary> summaries = [];

      for (final entry in billsByParty.entries) {
        final partyName = entry.key;
        final partyBills = entry.value;

        double totalSales = 0.0;
        double totalPaid = 0.0;
        double totalCredit = 0.0;
        final Set<String> modes = {};

        // Aggregate items for this party
        final Map<String, _ItemAccumulator> itemsAcc = {};

        for (final b in partyBills) {
          totalSales += b.amount;

          // Parse payment mode & advance vs credit
          double billPaid = 0.0;
          double billCredit = 0.0;
          String mode = 'Cash';

          final String notes = b.notes;

          // Check __saafhisaab_credit_advance:XX;credit:YY__
          final creditMarker = RegExp(r'__saafhisaab_credit_advance:([\d\.]+);credit:([\d\.]+)__');
          final match = creditMarker.firstMatch(notes);

          if (match != null) {
            billPaid = double.tryParse(match.group(1) ?? '0') ?? 0.0;
            billCredit = double.tryParse(match.group(2) ?? '0') ?? 0.0;
            if (billCredit > 0 && billPaid > 0) {
              mode = 'Split';
            } else if (billCredit > 0) {
              mode = 'Credit';
            } else {
              mode = 'Cash';
            }
          } else if (notes.contains('__sales_invoice_payload__')) {
            try {
              final payloadIndex = notes.indexOf('__sales_invoice_payload__');
              final jsonText = notes.substring(payloadIndex + '__sales_invoice_payload__'.length);
              final payload = jsonDecode(jsonText);
              final sihdr = payload['SIHDR'] as Map<String, dynamic>? ?? {};
              final invTran = payload['InvTranTbl'] as Map<String, dynamic>? ?? {};

              final rawMode = (sihdr['PymtMode'] ?? sihdr['PymtFlag'] ?? 'C').toString().toUpperCase();
              if (rawMode.contains('R') || rawMode.contains('CREDIT')) {
                mode = 'Credit';
                billCredit = b.amount;
              } else if (rawMode.contains('E') || rawMode.contains('UPI')) {
                mode = 'UPI';
                billPaid = b.amount;
              } else if (rawMode.contains('D') || rawMode.contains('SPLIT')) {
                mode = 'Split';
                final cashRecd = (invTran['CashReceived'] ?? sihdr['CashReceived'] ?? 0.0) as num;
                final epay = (sihdr['EPymtAmt'] ?? 0.0) as num;
                billPaid = (cashRecd + epay).toDouble();
                billCredit = (b.amount - billPaid).clamp(0.0, b.amount);
              } else {
                mode = 'Cash';
                billPaid = b.amount;
              }
            } catch (_) {
              billPaid = b.amount;
            }
          } else {
            // Standard sale bill fallback
            final bItems = itemsByBillId[b.id] ?? [];
            if (bItems.isNotEmpty && bItems.first['payment_mode'] != null) {
              final pMode = bItems.first['payment_mode'].toString().toLowerCase();
              if (pMode == 'credit') {
                mode = 'Credit';
                billCredit = b.amount;
              } else if (pMode == 'upi' || pMode == 'online') {
                mode = 'UPI';
                billPaid = b.amount;
              } else if (pMode == 'split') {
                mode = 'Split';
                billPaid = b.amount / 2;
                billCredit = b.amount / 2;
              } else {
                mode = 'Cash';
                billPaid = b.amount;
              }
            } else {
              billPaid = b.amount;
            }
          }

          modes.add(mode);
          totalPaid += billPaid;
          totalCredit += billCredit;

          // Process line items for this bill
          final bItems = itemsByBillId[b.id] ?? [];
          if (bItems.isNotEmpty) {
            for (final row in bItems) {
              final name = (row['item_name']?.toString() ?? 'Item').trim();
              final qty = ((row['quantity'] ?? 1.0) as num).toDouble();
              final unit = (row['unit']?.toString() ?? 'Pcs').trim();
              final price = ((row['selling_price'] ?? 0.0) as num).toDouble();
              final amt = ((row['total_amount'] ?? (qty * price)) as num).toDouble();

              final acc = itemsAcc.putIfAbsent(name.toLowerCase(), () => _ItemAccumulator(displayName: name, unit: unit));
              acc.totalQty += qty;
              acc.totalAmount += amt;
              acc.orderCount += 1;
              acc.lastDate = b.billDate;
            }
          } else {
            // Bill with no sales table breakdown: add single lump item
            final lumpName = partyName.isNotEmpty ? 'General Sale' : 'Store Items';
            final acc = itemsAcc.putIfAbsent(lumpName.toLowerCase(), () => _ItemAccumulator(displayName: lumpName, unit: 'Lump'));
            acc.totalQty += 1;
            acc.totalAmount += b.amount;
            acc.orderCount += 1;
            acc.lastDate = b.billDate;
          }
        }

        final List<PartyItemSale> itemsList = itemsAcc.values.map((a) {
          final avg = a.totalQty > 0 ? (a.totalAmount / a.totalQty) : 0.0;
          return PartyItemSale(
            itemName: a.displayName,
            quantity: a.totalQty,
            unit: a.unit,
            totalAmount: a.totalAmount,
            avgRate: avg,
            orderCount: a.orderCount,
            lastDate: a.lastDate,
          );
        }).toList();

        // Sort items by total amount descending
        itemsList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

        // Phone & address
        final custMatch = customersByName[partyName.toLowerCase()];
        final phone = custMatch?['phone']?.toString() ?? '';
        final address = custMatch?['address']?.toString() ?? '';

        summaries.add(PartySaleSummary(
          partyName: partyName,
          phone: phone,
          address: address,
          bills: partyBills,
          items: itemsList,
          totalSales: totalSales,
          totalPaid: totalPaid,
          totalCredit: totalCredit,
          paymentModes: modes,
        ));
      }

      // Default sort: highest sales first
      _sortSummaries(summaries);

      setState(() {
        _allParties = summaries;
        _applySearch();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _sortSummaries(List<PartySaleSummary> list) {
    switch (_sortMode) {
      case 'amount_desc':
        list.sort((a, b) => b.totalSales.compareTo(a.totalSales));
        break;
      case 'due_desc':
        list.sort((a, b) => b.totalCredit.compareTo(a.totalCredit));
        break;
      case 'bills_desc':
        list.sort((a, b) => b.invoiceCount.compareTo(a.invoiceCount));
        break;
      case 'name_asc':
        list.sort((a, b) => a.partyName.toLowerCase().compareTo(b.partyName.toLowerCase()));
        break;
    }
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredParties = List.from(_allParties);
    } else {
      _filteredParties = _allParties.where((p) {
        return p.partyName.toLowerCase().contains(query) ||
            p.phone.contains(query) ||
            p.items.any((it) => it.itemName.toLowerCase().contains(query));
      }).toList();
    }
    _sortSummaries(_filteredParties);
  }

  // ── Master AppBar PDF One-Stop Bill Action ──
  Future<void> _handleMasterPdfAction(String action) async {
    if (_allParties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No party data available to print for this period.')),
      );
      return;
    }

    final isEn = ref.read(appLanguageProvider);
    final shop = ref.read(shopProvider).valueOrNull;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        const SizedBox(width: 12),
        Text(AppLang.tr(isEn, 'Preparing Party-Wise Master Report...', 'पार्टी-वार रिपोर्ट तैयार हो रही है...')),
      ]),
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.primary,
    ));

    final html = PartyWiseSalesHtmlTemplate.generateMasterReport(
      shop: shop,
      filterPeriodLabel: _getFilterLabel(),
      fromDate: _fromDate,
      toDate: _toDate,
      parties: _filteredParties,
    );

    final title = 'PartyWise_Sales_${_getFilterLabel().replaceAll(' ', '_')}';

    if (action == 'print') {
      await InvoicePdfService.printOrSavePdf(htmlContent: html, invoiceTitle: title);
    } else if (action == 'browser') {
      InvoicePdfService.openHtmlInBrowser(htmlContent: html, invoiceTitle: title);
    } else if (action == 'share') {
      await InvoicePdfService.shareInvoice(
        htmlContent: html,
        filename: title,
        invoiceTitle: 'Party-Wise Sales Summary - ${_getFilterLabel()}',
      );
    }
  }

  // ── Per-Party Card PDF Action ──
  Future<void> _handlePartyPdfAction(PartySaleSummary party, String action) async {
    final isEn = ref.read(appLanguageProvider);
    final shop = ref.read(shopProvider).valueOrNull;

    final html = PartyWiseSalesHtmlTemplate.generatePartyDetailReport(
      shop: shop,
      party: party,
      filterPeriodLabel: _getFilterLabel(),
      fromDate: _fromDate,
      toDate: _toDate,
    );

    final title = 'Statement_${party.partyName.replaceAll(' ', '_')}_${_getFilterLabel().replaceAll(' ', '_')}';

    if (action == 'print') {
      await InvoicePdfService.printOrSavePdf(htmlContent: html, invoiceTitle: title);
    } else if (action == 'browser') {
      InvoicePdfService.openHtmlInBrowser(htmlContent: html, invoiceTitle: title);
    } else if (action == 'share') {
      await InvoicePdfService.shareInvoice(
        htmlContent: html,
        filename: title,
        invoiceTitle: 'Statement - ${party.partyName}',
      );
    }
  }

  void _openPartyDetails(PartySaleSummary party) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartySaleDetailScreen(
          party: party,
          dateFilterLabel: _getFilterLabel(),
          fromDate: _fromDate,
          toDate: _toDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    // Compute KPI sums
    double totalPeriodSales = 0;
    double totalPeriodPaid = 0;
    double totalPeriodCredit = 0;
    int totalPeriodBills = 0;

    for (final p in _filteredParties) {
      totalPeriodSales += p.totalSales;
      totalPeriodPaid += p.totalPaid;
      totalPeriodCredit += p.totalCredit;
      totalPeriodBills += p.invoiceCount;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLang.tr(isEn, 'Party Wise Sale Report', 'पार्टी वार बिक्री रिपोर्ट'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('${_getFilterLabel()} • ${_filteredParties.length} Parties',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Master PDF Dropdown / Action
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: AppLang.tr(isEn, 'One-Stop Master Report PDF', 'मास्टर रिपोर्ट PDF'),
            onSelected: (action) => _handleMasterPdfAction(action),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'print',
                child: Row(children: [
                  const Icon(Icons.print_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(AppLang.tr(isEn, 'Print / Save Master PDF', 'मास्टर PDF बनाएं / प्रिंट करें'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
              PopupMenuItem(
                value: 'browser',
                child: Row(children: [
                  const Icon(Icons.open_in_browser_rounded, color: Colors.teal, size: 20),
                  const SizedBox(width: 10),
                  Text(AppLang.tr(isEn, 'Preview Master in Browser', 'ब्राउज़र में मास्टर रिपोर्ट देखें'),
                    style: const TextStyle(fontSize: 13)),
                ]),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(children: [
                  const Icon(Icons.share_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Text(AppLang.tr(isEn, 'Share Master Statement', 'मास्टर रिपोर्ट शेयर करें'),
                    style: const TextStyle(fontSize: 13)),
                ]),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchReportData,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Date Filter Bar ──
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _dateChip(DateFilterType.today, AppLang.tr(isEn, 'Today', 'आज')),
                  const SizedBox(width: 8),
                  _dateChip(DateFilterType.yesterday, AppLang.tr(isEn, 'Yesterday', 'कल')),
                  const SizedBox(width: 8),
                  _dateChip(DateFilterType.thisWeek, AppLang.tr(isEn, 'This Week', 'इस सप्ताह')),
                  const SizedBox(width: 8),
                  _dateChip(DateFilterType.thisMonth, AppLang.tr(isEn, 'This Month', 'इस महीने')),
                  const SizedBox(width: 8),
                  _dateChip(DateFilterType.previousMonth, AppLang.tr(isEn, 'Prev Month', 'पिछला महीना')),
                  const SizedBox(width: 8),
                  _dateChip(DateFilterType.currentYear, AppLang.tr(isEn, 'Current Year', 'इस वर्ष')),
                  const SizedBox(width: 8),
                  _customDateChip(isEn),
                ],
              ),
            ),
          ),

          // ── KPI Summary Cards ──
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _kpiCard(
                  title: AppLang.tr(isEn, 'Total Sales', 'कुल बिक्री'),
                  amount: totalPeriodSales,
                  color: const Color(0xFF1E3A8A),
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(width: 8),
                _kpiCard(
                  title: AppLang.tr(isEn, 'Received', 'प्राप्त'),
                  amount: totalPeriodPaid,
                  color: const Color(0xFF16A34A),
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 8),
                _kpiCard(
                  title: AppLang.tr(isEn, 'Credit/Due', 'उधार/बाकी'),
                  amount: totalPeriodCredit,
                  color: const Color(0xFFDC2626),
                  icon: Icons.hourglass_top_rounded,
                ),
              ],
            ),
          ),

          // ── Search & Sort Strip ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() => _applySearch()),
                      decoration: InputDecoration(
                        hintText: AppLang.tr(isEn, 'Search party or item...', 'पार्टी या सामान खोजें...'),
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textHint),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _applySearch());
                                },
                              )
                            : null,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sort Menu
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort_rounded, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                  tooltip: 'Sort By',
                  onSelected: (val) {
                    setState(() {
                      _sortMode = val;
                      _sortSummaries(_filteredParties);
                    });
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'amount_desc',
                      child: Text(AppLang.tr(isEn, 'Highest Sales First', 'अधिकतम बिक्री पहले'),
                        style: TextStyle(fontWeight: _sortMode == 'amount_desc' ? FontWeight.bold : FontWeight.normal)),
                    ),
                    PopupMenuItem(
                      value: 'due_desc',
                      child: Text(AppLang.tr(isEn, 'Highest Credit/Due First', 'अधिकतम उधार पहले'),
                        style: TextStyle(fontWeight: _sortMode == 'due_desc' ? FontWeight.bold : FontWeight.normal)),
                    ),
                    PopupMenuItem(
                      value: 'bills_desc',
                      child: Text(AppLang.tr(isEn, 'Most Invoices First', 'अधिकतम बिल पहले'),
                        style: TextStyle(fontWeight: _sortMode == 'bills_desc' ? FontWeight.bold : FontWeight.normal)),
                    ),
                    PopupMenuItem(
                      value: 'name_asc',
                      child: Text(AppLang.tr(isEn, 'Party Name (A to Z)', 'पार्टी नाम (A से Z)'),
                        style: TextStyle(fontWeight: _sortMode == 'name_asc' ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Double click hint note banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppLang.tr(
                      isEn,
                      'Tip: Double-click (or tap) any card to view purchased items & invoice history.',
                      'सुझाव: खरीदे गए सामान और बिल इतिहास देखने के लिए किसी भी कार्ड पर डबल-क्लिक (या टैप) करें।',
                    ),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // ── Parties List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                              const SizedBox(height: 12),
                              Text('Failed to load report: $_errorMessage', textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchReportData,
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredParties.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.groups_outlined, size: 56, color: AppColors.textHint),
                                const SizedBox(height: 14),
                                Text(
                                  AppLang.tr(isEn, 'No party sales in ${_getFilterLabel()}', '${_getFilterLabel()} में कोई बिक्री नहीं मिली'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppLang.tr(isEn, 'Try selecting a different date filter', 'कृपया कोई अन्य तारीख अवधि चुनें'),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _fetchReportData,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: _filteredParties.length,
                              itemBuilder: (context, index) {
                                final party = _filteredParties[index];
                                return _partyCard(party, isEn);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(DateFilterType type, String label) {
    final isSelected = _selectedFilter == type;
    return GestureDetector(
      onTap: () => _applyFilter(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.primary : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _customDateChip(bool isEn) {
    final isSelected = _selectedFilter == DateFilterType.custom;
    return GestureDetector(
      onTap: _selectCustomDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range_rounded, size: 14, color: isSelected ? AppColors.primary : Colors.white),
            const SizedBox(width: 4),
            Text(
              isSelected ? _getFilterLabel() : AppLang.tr(isEn, 'Custom', 'कस्टम'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '₹${amount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partyCard(PartySaleSummary party, bool isEn) {
    // Top 2 items preview string
    final itemsPreview = party.items.take(2).map((i) => '${i.quantity.toStringAsFixed(i.quantity.truncateToDouble() == i.quantity ? 0 : 1)} ${i.unit} ${i.itemName}').join(', ');
    final remainingCount = party.items.length > 2 ? party.items.length - 2 : 0;

    return GestureDetector(
      // Supports both double click (as requested) and single tap
      onDoubleTap: () => _openPartyDetails(party),
      onTap: () => _openPartyDetails(party),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header of card
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Party initial badge
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        party.partyName.isNotEmpty ? party.partyName[0].toUpperCase() : 'P',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and invoice badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          party.partyName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (party.phone.isNotEmpty) ...[
                              Text('📞 +91 ${party.phone}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                              const SizedBox(width: 6),
                              Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.textHint, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${party.invoiceCount} ${party.invoiceCount == 1 ? "Bill" : "Bills"}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Total Sale Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${party.totalSales.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 2),
                      // Payment breakdown badge
                      if (party.totalCredit > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Due: ₹${party.totalCredit.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Fully Paid',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Item summary snippet (if items exist)
            if (itemsPreview.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.textHint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Items: $itemsPreview${remainingCount > 0 ? " (+$remainingCount more)" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Card Bottom Action Bar (PDF button & View Details button)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Payment Modes Pills
                  Wrap(
                    spacing: 4,
                    children: party.paymentModes.map((m) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          m,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      );
                    }).toList(),
                  ),

                  // Actions
                  Row(
                    children: [
                      // Per-party PDF statement shareable button
                      PopupMenuButton<String>(
                        tooltip: AppLang.tr(isEn, 'Party Statement PDF', 'पार्टी स्टेटमेंट PDF'),
                        onSelected: (action) => _handlePartyPdfAction(party, action),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'print',
                            child: Row(children: [
                              const Icon(Icons.print_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(AppLang.tr(isEn, 'Print / Save Statement PDF', 'स्टेटमेंट PDF बनाएं / प्रिंट करें'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'browser',
                            child: Row(children: [
                              const Icon(Icons.open_in_browser_rounded, color: Colors.teal, size: 18),
                              const SizedBox(width: 8),
                              Text(AppLang.tr(isEn, 'Preview Statement in Browser', 'ब्राउज़र में स्टेटमेंट देखें'),
                                style: const TextStyle(fontSize: 12)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(children: [
                              const Icon(Icons.share_rounded, color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              Text(AppLang.tr(isEn, 'Share Statement', 'स्टेटमेंट शेयर करें'),
                                style: const TextStyle(fontSize: 12)),
                            ]),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.picture_as_pdf_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                AppLang.tr(isEn, 'PDF', 'PDF'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Details icon
                      InkWell(
                        onTap: () => _openPartyDetails(party),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLang.tr(isEn, 'Items', 'सामान'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.purple),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.purple),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemAccumulator {
  final String displayName;
  final String unit;
  double totalQty = 0;
  double totalAmount = 0;
  int orderCount = 0;
  DateTime? lastDate;

  _ItemAccumulator({
    required this.displayName,
    required this.unit,
  });
}
