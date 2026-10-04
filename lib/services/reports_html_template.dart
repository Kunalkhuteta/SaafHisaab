import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shop_model.dart';
import '../models/udhar_model.dart';
import '../models/daily_balance_model.dart';
import '../screens/reports/outstanding_payable_screen.dart';
import '../screens/reports/cash_received_from_party_screen.dart';
import '../screens/reports/daily_item_wise_sale_screen.dart';
import '../screens/reports/goods_trading_accounts_report_screen.dart';
import '../screens/reports/dump_stock_report_screen.dart';
import '../screens/reports/top_trending_report_screen.dart';
import '../screens/reports/top_reorder_items_screen.dart';
import '../screens/reports/transaction_voucher_screen.dart';
import '../screens/reports/trial_balance_report_screen.dart';
import '../screens/reports/profit_loss_report_screen.dart';

enum ReportKpiType {
  neutral,
  success,
  danger,
  warning,
  info,
}

class ReportKpi {
  final String label;
  final String value;
  final ReportKpiType type;
  final String? subtext;

  const ReportKpi({
    required this.label,
    required this.value,
    this.type = ReportKpiType.neutral,
    this.subtext,
  });
}

class ReportColumn {
  final String title;
  final String width;
  final TextAlign align;

  const ReportColumn({
    required this.title,
    this.width = 'auto',
    this.align = TextAlign.left,
  });
}

/// Unified HTML PDF Report Engine
/// Provides standard layout, print CSS, KPI strips, structured tables and reports
class ReportHtmlBuilder {
  static final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final NumberFormat _intCurrencyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');

  static String formatCurrency(num amount, {bool decimals = false}) {
    if (decimals) {
      return _currencyFmt.format(amount);
    }
    return _intCurrencyFmt.format(amount);
  }

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  static String escape(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String buildDocument({
    required String title,
    required String bodyContent,
    String? extraStyles,
  }) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escape(title)}</title>
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 12.5px;
      line-height: 1.45;
      color: #1e293b;
      background: #f8fafc;
      padding: 24px;
    }
    .report-card {
      max-width: 920px;
      margin: 0 auto;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.04);
      padding: 30px;
    }
    .header-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      border-bottom: 2px solid #2563eb;
      padding-bottom: 18px;
      margin-bottom: 20px;
      gap: 16px;
    }
    .shop-info h1 {
      font-size: 22px;
      font-weight: 800;
      color: #1e3a8a;
      letter-spacing: -0.4px;
      margin-bottom: 4px;
    }
    .shop-info p {
      font-size: 11.5px;
      color: #475569;
      line-height: 1.45;
    }
    .report-meta {
      text-align: right;
    }
    .report-meta h2 {
      font-size: 17px;
      font-weight: 800;
      color: #2563eb;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 4px;
    }
    .report-meta p {
      font-size: 11.5px;
      color: #64748b;
      line-height: 1.45;
    }

    /* KPI Summary Strip */
    .kpi-strip {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-bottom: 22px;
    }
    .kpi-box {
      flex: 1 1 160px;
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 12px 14px;
      text-align: center;
    }
    .kpi-label {
      font-size: 10.5px;
      font-weight: 700;
      text-transform: uppercase;
      color: #64748b;
      margin-bottom: 4px;
      letter-spacing: 0.3px;
    }
    .kpi-value {
      font-size: 17px;
      font-weight: 800;
      color: #1e3a8a;
    }
    .kpi-subtext {
      font-size: 10.5px;
      color: #64748b;
      margin-top: 3px;
    }

    /* Badges */
    .badge {
      display: inline-block;
      padding: 2.5px 7px;
      font-size: 10px;
      font-weight: 700;
      border-radius: 4px;
      letter-spacing: 0.4px;
      text-transform: uppercase;
    }
    .badge-success { background: #dcfce7; color: #15803d; border: 1px solid #86efac; }
    .badge-danger { background: #fee2e2; color: #b91c1c; border: 1px solid #fca5a5; }
    .badge-warning { background: #fef3c7; color: #b45309; border: 1px solid #fde68a; }
    .badge-info { background: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd; }
    .badge-neutral { background: #f1f5f9; color: #475569; border: 1px solid #cbd5e1; }

    /* Tables */
    table.data-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 22px;
    }
    table.data-table th {
      background: #f1f5f9;
      color: #334155;
      font-size: 10.5px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      padding: 9px 8px;
      border-top: 1px solid #cbd5e1;
      border-bottom: 2px solid #cbd5e1;
    }
    table.data-table td {
      padding: 8px 8px;
      border-bottom: 1px solid #e2e8f0;
      font-size: 11.5px;
      vertical-align: middle;
    }
    table.data-table tr:nth-child(even) td { background: #fafafa; }
    table.data-table tr.total-row td {
      background: #eff6ff;
      border-top: 2px solid #2563eb;
      border-bottom: 2px solid #2563eb;
      font-size: 12px;
      font-weight: 800;
      color: #1e3a8a;
    }
    .subtotal-row td {
      background: #f8fafc;
      font-weight: 700;
      border-top: 1px dashed #cbd5e1;
    }

    /* Alignment */
    .text-left { text-align: left; }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .text-success { color: #16a34a !important; }
    .text-danger { color: #dc2626 !important; }
    .text-warning { color: #d97706 !important; }
    .text-info { color: #0284c7 !important; }
    .text-muted { color: #64748b; font-size: 10.5px; }

    /* Section Headings */
    .section-title {
      font-size: 13px;
      font-weight: 800;
      color: #1e293b;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin: 18px 0 8px 0;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    /* Dual Column Layout (for Balance Sheet, T-Accounts, P&L) */
    .dual-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
      margin-bottom: 22px;
    }
    .side-box {
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      overflow: hidden;
      background: #ffffff;
    }
    .side-box-header {
      background: #1e3a8a;
      color: #ffffff;
      padding: 9px 14px;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      display: flex;
      justify-content: space-between;
    }
    .side-box-header.credit {
      background: #15803d;
    }

    /* Footer */
    .footer {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 28px;
      padding-top: 14px;
      border-top: 1px solid #e2e8f0;
      font-size: 10.5px;
      color: #64748b;
    }

    @media print {
      body { background: #ffffff; padding: 0; }
      .report-card { border: none; box-shadow: none; padding: 0; max-width: 100%; }
      .no-print { display: none !important; }
      @page { size: A4 portrait; margin: 10mm; }
    }

    ${extraStyles ?? ''}
  </style>
</head>
<body>
  <div class="report-card">
    $bodyContent
  </div>
</body>
</html>
''';
  }

  static String buildHeader({
    required ShopModel? shop,
    required String title,
    String? subtitle,
    String? period,
    String? extraMeta,
  }) {
    final shopName = shop?.shopName.isNotEmpty == true ? shop!.shopName : 'SaafHisaab Business';
    final shopCity = shop?.city ?? '';
    final shopPhone = shop?.phone ?? '';
    final shopGst = shop?.gstNumber ?? '';
    final generatedOn = formatDateTime(DateTime.now());

    return '''
    <div class="header-row">
      <div class="shop-info">
        <h1>${escape(shopName)}</h1>
        ${shopCity.isNotEmpty ? '<p>Location: ' + escape(shopCity) + '</p>' : ''}
        ${shopPhone.isNotEmpty ? '<p>Phone: +91 ' + escape(shopPhone) + '</p>' : ''}
        ${shopGst.isNotEmpty ? '<p><strong>GSTIN: ' + escape(shopGst) + '</strong></p>' : ''}
      </div>
      <div class="report-meta">
        <h2>${escape(title)}</h2>
        ${subtitle != null && subtitle.isNotEmpty ? '<p><strong>$subtitle</strong></p>' : ''}
        ${period != null && period.isNotEmpty ? '<p><strong>Period:</strong> ' + escape(period) + '</p>' : ''}
        <p><strong>Generated:</strong> $generatedOn</p>
        ${extraMeta ?? ''}
      </div>
    </div>
    ''';
  }

  static String buildKpiStrip(List<ReportKpi> kpis) {
    if (kpis.isEmpty) return '';
    final boxesHtml = kpis.map((kpi) {
      String colorClass = '';
      switch (kpi.type) {
        case ReportKpiType.success:
          colorClass = 'text-success';
          break;
        case ReportKpiType.danger:
          colorClass = 'text-danger';
          break;
        case ReportKpiType.warning:
          colorClass = 'text-warning';
          break;
        case ReportKpiType.info:
          colorClass = 'text-info';
          break;
        case ReportKpiType.neutral:
          colorClass = '';
          break;
      }
      return '''
      <div class="kpi-box">
        <div class="kpi-label">${escape(kpi.label)}</div>
        <div class="kpi-value $colorClass">${escape(kpi.value)}</div>
        ${kpi.subtext != null ? '<div class="kpi-subtext">' + escape(kpi.subtext) + '</div>' : ''}
      </div>
      ''';
    }).join('\n');

    return '<div class="kpi-strip">$boxesHtml</div>';
  }

  static String buildTable({
    required List<ReportColumn> columns,
    required List<List<String>> rows,
    List<String>? totalRow,
    String? emptyMessage,
  }) {
    final ths = columns.map((col) {
      final alignClass = col.align == TextAlign.right
          ? 'text-right'
          : col.align == TextAlign.center
              ? 'text-center'
              : 'text-left';
      return '<th style="width: ${col.width};" class="$alignClass">${escape(col.title)}</th>';
    }).join('');

    String tbody = '';
    if (rows.isEmpty) {
      tbody = '<tr><td colspan="${columns.length}" class="text-center" style="padding: 24px; color: #64748b;">${escape(emptyMessage ?? "No records found.")}</td></tr>';
    } else {
      tbody = rows.map((row) {
        final tds = row.asMap().entries.map((entry) {
          final idx = entry.key;
          final cell = entry.value;
          final col = idx < columns.length ? columns[idx] : columns.last;
          final alignClass = col.align == TextAlign.right
              ? 'text-right'
              : col.align == TextAlign.center
                  ? 'text-center'
                  : 'text-left';
          return '<td class="$alignClass">$cell</td>';
        }).join('');
        return '<tr>$tds</tr>';
      }).join('\n');
    }

    String tfoot = '';
    if (totalRow != null && totalRow.isNotEmpty) {
      final tds = totalRow.asMap().entries.map((entry) {
        final idx = entry.key;
        final cell = entry.value;
        final col = idx < columns.length ? columns[idx] : columns.last;
        final alignClass = col.align == TextAlign.right
            ? 'text-right'
            : col.align == TextAlign.center
                ? 'text-center'
                : 'text-left';
        return '<td class="$alignClass"><strong>$cell</strong></td>';
      }).join('');
      tfoot = '<tr class="total-row">$tds</tr>';
    }

    return '''
    <table class="data-table">
      <thead><tr>$ths</tr></thead>
      <tbody>
        $tbody
        $tfoot
      </tbody>
    </table>
    ''';
  }

  static String buildFooter(ShopModel? shop) {
    final shopName = shop?.shopName.isNotEmpty == true ? shop!.shopName : 'SaafHisaab Merchant';
    return '''
    <div class="footer">
      <div>Generated automatically via SaafHisaab Business Reporting Engine</div>
      <div style="font-weight: 700; color: #1e3a8a;">Authorized Report • For ${escape(shopName)}</div>
    </div>
    ''';
  }

  static String buildBadge(String text, ReportKpiType type) {
    String typeClass = 'badge-neutral';
    switch (type) {
      case ReportKpiType.success:
        typeClass = 'badge-success';
        break;
      case ReportKpiType.danger:
        typeClass = 'badge-danger';
        break;
      case ReportKpiType.warning:
        typeClass = 'badge-warning';
        break;
      case ReportKpiType.info:
        typeClass = 'badge-info';
        break;
      case ReportKpiType.neutral:
        typeClass = 'badge-neutral';
        break;
    }
    return '<span class="badge $typeClass">${escape(text)}</span>';
  }
}

/// Unified High-Quality PDF Reports Generator for all Reports in SaafHisaab
class ReportsHtmlTemplate {
  // ─────────────────────────────────────────────────────────────
  // 1. Outstanding Receivable Master Report
  // ─────────────────────────────────────────────────────────────
  static String generateOutstandingReceivables({
    required ShopModel? shop,
    required List<UdharCustomerModel> items,
  }) {
    final totalDue = items.fold(0.0, (sum, i) => sum + i.totalDue);
    final totalAdvance = items.fold(0.0, (sum, i) => sum + i.tobeadjustAmount);
    final sorted = List<UdharCustomerModel>.from(items)
      ..sort((a, b) => b.totalDue.compareTo(a.totalDue));

    final columns = [
      const ReportColumn(title: '#', width: '35px', align: TextAlign.center),
      const ReportColumn(title: 'Customer Name', align: TextAlign.left),
      const ReportColumn(title: 'Phone Number', width: '130px', align: TextAlign.center),
      const ReportColumn(title: 'Advance / Adjusted', width: '130px', align: TextAlign.right),
      const ReportColumn(title: 'Outstanding Due', width: '140px', align: TextAlign.right),
      const ReportColumn(title: 'Status', width: '100px', align: TextAlign.center),
    ];

    final rows = sorted.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final c = entry.value;
      final statusBadge = c.totalDue > 0
          ? ReportHtmlBuilder.buildBadge('Pending Due', ReportKpiType.danger)
          : ReportHtmlBuilder.buildBadge('Cleared', ReportKpiType.success);

      return [
        '$idx',
        '<strong>${ReportHtmlBuilder.escape(c.customerName)}</strong>',
        c.customerPhone.isNotEmpty ? '+91 ${ReportHtmlBuilder.escape(c.customerPhone)}' : '-',
        c.tobeadjustAmount > 0
            ? '<span class="text-success">${ReportHtmlBuilder.formatCurrency(c.tobeadjustAmount)}</span>'
            : '₹0',
        '<strong class="text-danger">${ReportHtmlBuilder.formatCurrency(c.totalDue)}</strong>',
        statusBadge,
      ];
    }).toList();

    final totalRow = [
      '',
      'Grand Total (${items.length} Customers)',
      '',
      '<span class="text-success">${ReportHtmlBuilder.formatCurrency(totalAdvance)}</span>',
      '<span class="text-danger">${ReportHtmlBuilder.formatCurrency(totalDue)}</span>',
      '',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Outstanding Receivables Report', subtitle: 'Customer Credit Balances')}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Outstanding Due', value: ReportHtmlBuilder.formatCurrency(totalDue), type: ReportKpiType.danger),
        ReportKpi(label: 'Customers with Due', value: '${items.where((c) => c.totalDue > 0).length}', type: ReportKpiType.warning),
        ReportKpi(label: 'Total Advance / Adjusted', value: ReportHtmlBuilder.formatCurrency(totalAdvance), type: ReportKpiType.success),
        ReportKpi(label: 'Total Parties', value: '${items.length}', type: ReportKpiType.info),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No outstanding receivables found.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Outstanding Receivables Report', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Customer Statement / Receivable Party Detail Report
  // ─────────────────────────────────────────────────────────────
  static String generateReceivablePartyStatement({
    required ShopModel? shop,
    required UdharCustomerModel customer,
    required List<UdharEntryModel> entries,
    required double currentDue,
    required double totalCredit,
    required double totalReceived,
  }) {
    final sortedEntries = List<UdharEntryModel>.from(entries)
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    final columns = [
      const ReportColumn(title: '#', width: '35px', align: TextAlign.center),
      const ReportColumn(title: 'Date', width: '90px', align: TextAlign.center),
      const ReportColumn(title: 'Type', width: '90px', align: TextAlign.center),
      const ReportColumn(title: 'Notes / Ref', align: TextAlign.left),
      const ReportColumn(title: 'Credit (Gave)', width: '120px', align: TextAlign.right),
      const ReportColumn(title: 'Received (Paid)', width: '120px', align: TextAlign.right),
    ];

    final rows = sortedEntries.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final e = entry.value;
      final isCredit = e.entryType == 'credit';
      final badge = isCredit
          ? ReportHtmlBuilder.buildBadge('Credit / Sale', ReportKpiType.danger)
          : ReportHtmlBuilder.buildBadge('Payment Received', ReportKpiType.success);

      final cleanNote = e.note.contains('__saafhisaab_') ? 'Payment Receipt' : e.note;

      return [
        '$idx',
        ReportHtmlBuilder.formatDate(e.entryDate),
        badge,
        ReportHtmlBuilder.escape(cleanNote.isNotEmpty ? cleanNote : '-'),
        isCredit ? '<strong>${ReportHtmlBuilder.formatCurrency(e.amount)}</strong>' : '-',
        !isCredit ? '<strong class="text-success">${ReportHtmlBuilder.formatCurrency(e.amount)}</strong>' : '-',
      ];
    }).toList();

    final totalRow = [
      '',
      'Total',
      '',
      'Current Due: <strong class="text-danger">${ReportHtmlBuilder.formatCurrency(currentDue)}</strong>',
      '<span class="text-danger">${ReportHtmlBuilder.formatCurrency(totalCredit)}</span>',
      '<span class="text-success">${ReportHtmlBuilder.formatCurrency(totalReceived)}</span>',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Customer Statement', subtitle: customer.customerName)}
      <div style="background:#eff6ff; border:1px solid #bfdbfe; border-radius:8px; padding:14px; margin-bottom:18px; display:flex; justify-content:space-between; align-items:center;">
        <div>
          <div style="font-size:16px; font-weight:800; color:#1e3a8a;">${ReportHtmlBuilder.escape(customer.customerName)}</div>
          <div style="font-size:11.5px; color:#475569; margin-top:2px;">
            ${customer.customerPhone.isNotEmpty ? '📞 +91 ' + ReportHtmlBuilder.escape(customer.customerPhone) : 'Registered Customer'}
          </div>
        </div>
        <div style="text-align:right;">
          <div style="font-size:11px; text-transform:uppercase; font-weight:700; color:#64748b;">Current Outstanding Due</div>
          <div style="font-size:20px; font-weight:800; color:#dc2626;">${ReportHtmlBuilder.formatCurrency(currentDue)}</div>
        </div>
      </div>
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Credit Given', value: ReportHtmlBuilder.formatCurrency(totalCredit), type: ReportKpiType.danger),
        ReportKpi(label: 'Total Payment Received', value: ReportHtmlBuilder.formatCurrency(totalReceived), type: ReportKpiType.success),
        ReportKpi(label: 'Current Balance Due', value: ReportHtmlBuilder.formatCurrency(currentDue), type: currentDue > 0 ? ReportKpiType.danger : ReportKpiType.success),
        ReportKpi(label: 'Total Transactions', value: '${entries.length}', type: ReportKpiType.info),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No transactions recorded for this customer.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Customer Statement - ${customer.customerName}', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Outstanding Payable Master Report
  // ─────────────────────────────────────────────────────────────
  static String generateOutstandingPayables({
    required ShopModel? shop,
    required List<OutstandingPayableItem> items,
  }) {
    final totalPending = items.fold(0.0, (sum, i) => sum + i.pendingAmount);
    final sorted = List<OutstandingPayableItem>.from(items)
      ..sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));

    final columns = [
      const ReportColumn(title: '#', width: '35px', align: TextAlign.center),
      const ReportColumn(title: 'Supplier / Party Name', align: TextAlign.left),
      const ReportColumn(title: 'Station / City', width: '110px', align: TextAlign.left),
      const ReportColumn(title: 'Phone', width: '120px', align: TextAlign.center),
      const ReportColumn(title: 'GSTIN', width: '130px', align: TextAlign.center),
      const ReportColumn(title: 'Pending Payable', width: '140px', align: TextAlign.right),
    ];

    final rows = sorted.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final p = entry.value;
      return [
        '$idx',
        '<strong>${ReportHtmlBuilder.escape(p.partyName)}</strong>',
        ReportHtmlBuilder.escape(p.partyStation.isNotEmpty ? p.partyStation : '-'),
        p.partyPhone.isNotEmpty ? '+91 ${ReportHtmlBuilder.escape(p.partyPhone)}' : '-',
        ReportHtmlBuilder.escape(p.partyGst.isNotEmpty ? p.partyGst : '-'),
        '<strong class="text-danger">${ReportHtmlBuilder.formatCurrency(p.pendingAmount)}</strong>',
      ];
    }).toList();

    final totalRow = [
      '',
      'Grand Total (${items.length} Suppliers)',
      '',
      '',
      '',
      '<span class="text-danger">${ReportHtmlBuilder.formatCurrency(totalPending)}</span>',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Outstanding Payables Report', subtitle: 'Supplier Pending Payments')}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Pending Payable', value: ReportHtmlBuilder.formatCurrency(totalPending), type: ReportKpiType.danger),
        ReportKpi(label: 'Suppliers with Pending', value: '${items.where((i) => i.pendingAmount > 0).length}', type: ReportKpiType.warning),
        ReportKpi(label: 'Total Suppliers', value: '${items.length}', type: ReportKpiType.info),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No pending supplier payables.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Outstanding Payables Report', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Supplier Statement / Payable Party Detail Report
  // ─────────────────────────────────────────────────────────────
  static String generatePayablePartyStatement({
    required ShopModel? shop,
    required String partyName,
    required String partyPhone,
    required String partyStation,
    required double pendingAmount,
    required double totalPurchased,
    required double totalPaid,
    required List<Map<String, dynamic>> entries,
  }) {
    final columns = [
      const ReportColumn(title: '#', width: '35px', align: TextAlign.center),
      const ReportColumn(title: 'Date', width: '90px', align: TextAlign.center),
      const ReportColumn(title: 'Ref / Bill No', width: '120px', align: TextAlign.center),
      const ReportColumn(title: 'Transaction Type', width: '130px', align: TextAlign.center),
      const ReportColumn(title: 'Bill Amount', width: '120px', align: TextAlign.right),
      const ReportColumn(title: 'Paid / Return', width: '120px', align: TextAlign.right),
    ];

    final rows = entries.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final e = entry.value;
      final date = e['date'] is DateTime ? ReportHtmlBuilder.formatDate(e['date'] as DateTime) : (e['date']?.toString() ?? '');
      final isPayment = e['isPayment'] == true;
      final isReturn = e['isReturn'] == true;

      String badgeText = 'Purchase';
      ReportKpiType badgeType = ReportKpiType.neutral;
      if (isPayment) {
        badgeText = 'Payment Paid';
        badgeType = ReportKpiType.success;
      } else if (isReturn) {
        badgeText = 'Purchase Return';
        badgeType = ReportKpiType.warning;
      }

      final billAmt = (e['billAmount'] as num?)?.toDouble() ?? 0.0;
      final paidAmt = (e['paidAmount'] as num?)?.toDouble() ?? 0.0;

      return [
        '$idx',
        date,
        ReportHtmlBuilder.escape(e['refNo']?.toString() ?? '-'),
        ReportHtmlBuilder.buildBadge(badgeText, badgeType),
        billAmt > 0 ? ReportHtmlBuilder.formatCurrency(billAmt) : '-',
        paidAmt > 0 ? '<strong class="text-success">${ReportHtmlBuilder.formatCurrency(paidAmt)}</strong>' : '-',
      ];
    }).toList();

    final totalRow = [
      '',
      'Total',
      '',
      'Pending: <strong class="text-danger">${ReportHtmlBuilder.formatCurrency(pendingAmount)}</strong>',
      ReportHtmlBuilder.formatCurrency(totalPurchased),
      '<strong class="text-success">${ReportHtmlBuilder.formatCurrency(totalPaid)}</strong>',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Supplier Purchase Statement', subtitle: partyName)}
      <div style="background:#fef2f2; border:1px solid #fecaca; border-radius:8px; padding:14px; margin-bottom:18px; display:flex; justify-content:space-between; align-items:center;">
        <div>
          <div style="font-size:16px; font-weight:800; color:#991b1b;">${ReportHtmlBuilder.escape(partyName)}</div>
          <div style="font-size:11.5px; color:#475569; margin-top:2px;">
            ${partyStation.isNotEmpty ? ReportHtmlBuilder.escape(partyStation) + ' • ' : ''}
            ${partyPhone.isNotEmpty ? '📞 +91 ' + ReportHtmlBuilder.escape(partyPhone) : 'Supplier Account'}
          </div>
        </div>
        <div style="text-align:right;">
          <div style="font-size:11px; text-transform:uppercase; font-weight:700; color:#64748b;">Pending Payable Balance</div>
          <div style="font-size:20px; font-weight:800; color:#dc2626;">${ReportHtmlBuilder.formatCurrency(pendingAmount)}</div>
        </div>
      </div>
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Purchases', value: ReportHtmlBuilder.formatCurrency(totalPurchased), type: ReportKpiType.neutral),
        ReportKpi(label: 'Total Paid / Settled', value: ReportHtmlBuilder.formatCurrency(totalPaid), type: ReportKpiType.success),
        ReportKpi(label: 'Pending Balance', value: ReportHtmlBuilder.formatCurrency(pendingAmount), type: ReportKpiType.danger),
        ReportKpi(label: 'Total Entries', value: '${entries.length}', type: ReportKpiType.info),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No purchase records found for this supplier.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Supplier Statement - $partyName', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Daily Cash & Bank Balance Report
  // ─────────────────────────────────────────────────────────────
  static String generateDailyBalances({
    required ShopModel? shop,
    required DateTime month,
    required List<DailyBalanceModel> balances,
  }) {
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    double totalCashIn = 0;
    double totalCashOut = 0;
    double totalBankIn = 0;
    double totalBankOut = 0;
    double totalNetCash = 0;
    double totalNetBank = 0;

    for (final b in balances) {
      totalCashIn += b.cashIn;
      totalCashOut += b.cashOut;
      totalBankIn += b.bankIn;
      totalBankOut += b.bankOut;
      totalNetCash += b.netCash;
      totalNetBank += b.netBank;
    }

    final totalNetFlow = totalNetCash + totalNetBank;

    final columns = [
      const ReportColumn(title: 'Date', width: '90px', align: TextAlign.center),
      const ReportColumn(title: 'Cash In (+)', width: '100px', align: TextAlign.right),
      const ReportColumn(title: 'Cash Out (-)', width: '100px', align: TextAlign.right),
      const ReportColumn(title: 'Net Cash', width: '100px', align: TextAlign.right),
      const ReportColumn(title: 'Bank In (+)', width: '100px', align: TextAlign.right),
      const ReportColumn(title: 'Bank Out (-)', width: '100px', align: TextAlign.right),
      const ReportColumn(title: 'Net Bank', width: '100px', align: TextAlign.right),
      const ReportColumn(title: 'Day Total', width: '110px', align: TextAlign.right),
    ];

    final rows = balances.map((b) {
      final dayTotal = b.netCash + b.netBank;
      return [
        ReportHtmlBuilder.formatDate(b.balanceDate),
        b.cashIn > 0 ? '<span class="text-success">${ReportHtmlBuilder.formatCurrency(b.cashIn)}</span>' : '-',
        b.cashOut > 0 ? '<span class="text-danger">${ReportHtmlBuilder.formatCurrency(b.cashOut)}</span>' : '-',
        '<strong>${ReportHtmlBuilder.formatCurrency(b.netCash)}</strong>',
        b.bankIn > 0 ? '<span class="text-success">${ReportHtmlBuilder.formatCurrency(b.bankIn)}</span>' : '-',
        b.bankOut > 0 ? '<span class="text-danger">${ReportHtmlBuilder.formatCurrency(b.bankOut)}</span>' : '-',
        '<strong>${ReportHtmlBuilder.formatCurrency(b.netBank)}</strong>',
        '<strong class="${dayTotal >= 0 ? 'text-success' : 'text-danger'}">${ReportHtmlBuilder.formatCurrency(dayTotal)}</strong>',
      ];
    }).toList();

    final totalRow = [
      'Total',
      '<span class="text-success">${ReportHtmlBuilder.formatCurrency(totalCashIn)}</span>',
      '<span class="text-danger">${ReportHtmlBuilder.formatCurrency(totalCashOut)}</span>',
      '<strong>${ReportHtmlBuilder.formatCurrency(totalNetCash)}</strong>',
      '<span class="text-success">${ReportHtmlBuilder.formatCurrency(totalBankIn)}</span>',
      '<span class="text-danger">${ReportHtmlBuilder.formatCurrency(totalBankOut)}</span>',
      '<strong>${ReportHtmlBuilder.formatCurrency(totalNetBank)}</strong>',
      '<strong class="${totalNetFlow >= 0 ? 'text-success' : 'text-danger'}">${ReportHtmlBuilder.formatCurrency(totalNetFlow)}</strong>',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Daily Cash & Bank Balance', period: monthLabel)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Net Cash Balance', value: ReportHtmlBuilder.formatCurrency(totalNetCash), type: totalNetCash >= 0 ? ReportKpiType.success : ReportKpiType.danger, subtext: 'In: ₹${totalCashIn.toStringAsFixed(0)} | Out: ₹${totalCashOut.toStringAsFixed(0)}'),
        ReportKpi(label: 'Net Bank Balance', value: ReportHtmlBuilder.formatCurrency(totalNetBank), type: totalNetBank >= 0 ? ReportKpiType.info : ReportKpiType.danger, subtext: 'In: ₹${totalBankIn.toStringAsFixed(0)} | Out: ₹${totalBankOut.toStringAsFixed(0)}'),
        ReportKpi(label: 'Total Net Movement', value: ReportHtmlBuilder.formatCurrency(totalNetFlow), type: totalNetFlow >= 0 ? ReportKpiType.success : ReportKpiType.danger),
        ReportKpi(label: 'Days Tracked', value: '${balances.length} Days', type: ReportKpiType.neutral),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No daily balance entries found for $monthLabel.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Daily Cash & Bank - $monthLabel', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Cash Received from Party Report
  // ─────────────────────────────────────────────────────────────
  static String generateCashReceived({
    required ShopModel? shop,
    required String periodLabel,
    required List<PartyCashSummary> summaries,
    List<CashTransaction>? transactions,
  }) {
    final totalReceived = summaries.fold(0.0, (sum, s) => sum + s.totalCashReceived);
    final totalPayments = summaries.fold(0, (sum, s) => sum + s.paymentCount);

    final partyColumns = [
      const ReportColumn(title: 'Rank', width: '45px', align: TextAlign.center),
      const ReportColumn(title: 'Party / Customer Name', align: TextAlign.left),
      const ReportColumn(title: 'Phone Number', width: '120px', align: TextAlign.center),
      const ReportColumn(title: 'Payment Count', width: '100px', align: TextAlign.center),
      const ReportColumn(title: 'Last Payment Date', width: '120px', align: TextAlign.center),
      const ReportColumn(title: 'Total Cash Received', width: '140px', align: TextAlign.right),
    ];

    final partyRows = summaries.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final s = entry.value;
      return [
        '$idx',
        '<strong>${ReportHtmlBuilder.escape(s.partyName)}</strong>',
        s.phone.isNotEmpty ? '+91 ${ReportHtmlBuilder.escape(s.phone)}' : '-',
        '${s.paymentCount} payments',
        s.lastPaymentFormatted,
        '<strong class="text-success">${ReportHtmlBuilder.formatCurrency(s.totalCashReceived)}</strong>',
      ];
    }).toList();

    final partyTotalRow = [
      '',
      'Grand Total (${summaries.length} Parties)',
      '',
      '$totalPayments payments',
      '',
      '<span class="text-success">${ReportHtmlBuilder.formatCurrency(totalReceived)}</span>',
    ];

    String txTableHtml = '';
    if (transactions != null && transactions.isNotEmpty) {
      final txColumns = [
        const ReportColumn(title: 'Date', width: '90px', align: TextAlign.center),
        const ReportColumn(title: 'Party Name', align: TextAlign.left),
        const ReportColumn(title: 'Type', width: '110px', align: TextAlign.center),
        const ReportColumn(title: 'Note / Ref', align: TextAlign.left),
        const ReportColumn(title: 'Amount', width: '120px', align: TextAlign.right),
      ];

      final txRows = transactions.take(100).map((t) {
        return [
          ReportHtmlBuilder.formatDate(t.date),
          ReportHtmlBuilder.escape(t.partyName),
          ReportHtmlBuilder.buildBadge(t.type, ReportKpiType.info),
          ReportHtmlBuilder.escape(t.note.isNotEmpty ? t.note : '-'),
          '<strong class="text-success">${ReportHtmlBuilder.formatCurrency(t.amount)}</strong>',
        ];
      }).toList();

      txTableHtml = '''
        <div class="section-title"><span>Recent Cash Transactions</span></div>
        ${ReportHtmlBuilder.buildTable(columns: txColumns, rows: txRows, emptyMessage: 'No cash transactions recorded.')}
      ''';
    }

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Cash Received from Parties', period: periodLabel)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Cash Received', value: ReportHtmlBuilder.formatCurrency(totalReceived), type: ReportKpiType.success),
        ReportKpi(label: 'Total Transactions', value: '$totalPayments', type: ReportKpiType.info),
        ReportKpi(label: 'Total Parties', value: '${summaries.length}', type: ReportKpiType.neutral),
        ReportKpi(label: 'Top Paying Party', value: summaries.isNotEmpty ? summaries.first.partyName : '-', type: ReportKpiType.warning, subtext: summaries.isNotEmpty ? ReportHtmlBuilder.formatCurrency(summaries.first.totalCashReceived) : null),
      ])}
      <div class="section-title"><span>Party-Wise Cash Rankings</span></div>
      ${ReportHtmlBuilder.buildTable(columns: partyColumns, rows: partyRows, totalRow: partyTotalRow, emptyMessage: 'No cash collections in this period.')}
      $txTableHtml
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Cash Received - $periodLabel', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 7. Daily Item Wise Sale Report
  // ─────────────────────────────────────────────────────────────
  static String generateDailyItemWiseSale({
    required ShopModel? shop,
    required DateTime date,
    required List<DailyItemSale> items,
  }) {
    final dateStr = ReportHtmlBuilder.formatDate(date);
    final totalAmount = items.fold(0.0, (sum, i) => sum + i.totalAmount);
    final totalQty = items.fold(0.0, (sum, i) => sum + i.quantity);

    final columns = [
      const ReportColumn(title: 'Rank', width: '45px', align: TextAlign.center),
      const ReportColumn(title: 'Item Name', align: TextAlign.left),
      const ReportColumn(title: 'Category', width: '120px', align: TextAlign.center),
      const ReportColumn(title: 'Quantity Sold', width: '110px', align: TextAlign.center),
      const ReportColumn(title: 'Avg Rate', width: '100px', align: TextAlign.right),
      const ReportColumn(title: 'Bills', width: '70px', align: TextAlign.center),
      const ReportColumn(title: 'Total Sale (₹)', width: '120px', align: TextAlign.right),
      const ReportColumn(title: 'Share %', width: '75px', align: TextAlign.center),
    ];

    final rows = items.map((i) {
      final qtyStr = i.quantity.truncateToDouble() == i.quantity ? i.quantity.toInt().toString() : i.quantity.toStringAsFixed(1);
      return [
        '${i.rank}',
        '<strong>${ReportHtmlBuilder.escape(i.itemName)}</strong>',
        ReportHtmlBuilder.escape(i.category),
        '$qtyStr ${ReportHtmlBuilder.escape(i.unit)}',
        ReportHtmlBuilder.formatCurrency(i.avgRate),
        '${i.billCount}',
        '<strong>${ReportHtmlBuilder.formatCurrency(i.totalAmount)}</strong>',
        '${i.sharePercent.toStringAsFixed(1)}%',
      ];
    }).toList();

    final totalRow = [
      '',
      'Total (${items.length} Items)',
      '',
      '${totalQty.toStringAsFixed(0)} units',
      '',
      '',
      '<strong>${ReportHtmlBuilder.formatCurrency(totalAmount)}</strong>',
      '100%',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Daily Item-Wise Sale Report', period: dateStr)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Sales Revenue', value: ReportHtmlBuilder.formatCurrency(totalAmount), type: ReportKpiType.success),
        ReportKpi(label: 'Total Units Sold', value: '${totalQty.toStringAsFixed(0)} units', type: ReportKpiType.info),
        ReportKpi(label: 'Unique Items Sold', value: '${items.length}', type: ReportKpiType.neutral),
        ReportKpi(label: 'Top Selling Item', value: items.isNotEmpty ? items.first.itemName : '-', type: ReportKpiType.warning, subtext: items.isNotEmpty ? ReportHtmlBuilder.formatCurrency(items.first.totalAmount) : null),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No items sold on this date.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Daily Item Sale - $dateStr', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 8. Goods Trading Accounts Report (Inventory & Profitability)
  // ─────────────────────────────────────────────────────────────
  static String generateGoodsTradingAccounts({
    required ShopModel? shop,
    required String periodLabel,
    required List<ItemTradingSummary> items,
  }) {
    final totalRevenue = items.fold(0.0, (sum, i) => sum + i.salesRevenue);
    final totalCost = items.fold(0.0, (sum, i) => sum + i.costOfUnitsSold);
    final totalProfit = items.fold(0.0, (sum, i) => sum + i.grossProfit);
    final totalStockValue = items.fold(0.0, (sum, i) => sum + i.stockValue);

    final columns = [
      const ReportColumn(title: '#', width: '35px', align: TextAlign.center),
      const ReportColumn(title: 'Item Name', align: TextAlign.left),
      const ReportColumn(title: 'Category', width: '100px', align: TextAlign.center),
      const ReportColumn(title: 'Stock Qty', width: '85px', align: TextAlign.center),
      const ReportColumn(title: 'Stock Value', width: '95px', align: TextAlign.right),
      const ReportColumn(title: 'Sold Qty', width: '75px', align: TextAlign.center),
      const ReportColumn(title: 'Revenue', width: '95px', align: TextAlign.right),
      const ReportColumn(title: 'COGS', width: '90px', align: TextAlign.right),
      const ReportColumn(title: 'Gross Profit', width: '95px', align: TextAlign.right),
      const ReportColumn(title: 'Margin', width: '65px', align: TextAlign.center),
    ];

    final rows = items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final i = entry.value;
      final marginColor = i.profitMargin >= 20 ? 'text-success' : (i.profitMargin > 0 ? 'text-warning' : 'text-danger');
      return [
        '$idx',
        '<strong>${ReportHtmlBuilder.escape(i.itemName)}</strong>',
        ReportHtmlBuilder.escape(i.category),
        '${i.currentStock.toStringAsFixed(0)} ${i.unit}',
        ReportHtmlBuilder.formatCurrency(i.stockValue),
        '${i.unitsSold.toStringAsFixed(0)}',
        ReportHtmlBuilder.formatCurrency(i.salesRevenue),
        ReportHtmlBuilder.formatCurrency(i.costOfUnitsSold),
        '<strong class="${i.grossProfit >= 0 ? 'text-success' : 'text-danger'}">${ReportHtmlBuilder.formatCurrency(i.grossProfit)}</strong>',
        '<span class="$marginColor"><strong>${i.profitMargin.toStringAsFixed(1)}%</strong></span>',
      ];
    }).toList();

    final overallMargin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
    final totalRow = [
      '',
      'Total (${items.length} Products)',
      '',
      '',
      ReportHtmlBuilder.formatCurrency(totalStockValue),
      '',
      ReportHtmlBuilder.formatCurrency(totalRevenue),
      ReportHtmlBuilder.formatCurrency(totalCost),
      '<strong class="${totalProfit >= 0 ? 'text-success' : 'text-danger'}">${ReportHtmlBuilder.formatCurrency(totalProfit)}</strong>',
      '<strong>${overallMargin.toStringAsFixed(1)}%</strong>',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Goods Trading Accounts Report', subtitle: 'Item-Wise Stock & Trading Profitability', period: periodLabel)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Sales Revenue', value: ReportHtmlBuilder.formatCurrency(totalRevenue), type: ReportKpiType.success),
        ReportKpi(label: 'Cost of Goods Sold', value: ReportHtmlBuilder.formatCurrency(totalCost), type: ReportKpiType.neutral),
        ReportKpi(label: 'Gross Profit', value: ReportHtmlBuilder.formatCurrency(totalProfit), type: totalProfit >= 0 ? ReportKpiType.success : ReportKpiType.danger, subtext: 'Avg Margin: ${overallMargin.toStringAsFixed(1)}%'),
        ReportKpi(label: 'Current Stock Valuation', value: ReportHtmlBuilder.formatCurrency(totalStockValue), type: ReportKpiType.info),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No item trading records available.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Goods Trading Accounts - $periodLabel', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 9. Dump Stock Report
  // ─────────────────────────────────────────────────────────────
  static String generateDumpStock({
    required ShopModel? shop,
    required List<DumpStockItem> items,
  }) {
    final totalLoss = items.fold(0.0, (sum, i) => sum + i.totalLoss);
    final totalQty = items.fold(0.0, (sum, i) => sum + i.quantity);

    final columns = [
      const ReportColumn(title: '#', width: '35px', align: TextAlign.center),
      const ReportColumn(title: 'Date', width: '90px', align: TextAlign.center),
      const ReportColumn(title: 'Item Name', align: TextAlign.left),
      const ReportColumn(title: 'Category', width: '100px', align: TextAlign.center),
      const ReportColumn(title: 'Quantity', width: '90px', align: TextAlign.center),
      const ReportColumn(title: 'Rate', width: '85px', align: TextAlign.right),
      const ReportColumn(title: 'Total Loss (₹)', width: '110px', align: TextAlign.right),
      const ReportColumn(title: 'Reason / Notes', width: '140px', align: TextAlign.left),
    ];

    final rows = items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final i = entry.value;
      return [
        '$idx',
        ReportHtmlBuilder.formatDate(i.date),
        '<strong>${ReportHtmlBuilder.escape(i.itemName)}</strong>',
        ReportHtmlBuilder.escape(i.category),
        '${i.quantity.toStringAsFixed(0)} ${ReportHtmlBuilder.escape(i.unit)}',
        ReportHtmlBuilder.formatCurrency(i.rate),
        '<strong class="text-danger">${ReportHtmlBuilder.formatCurrency(i.totalLoss)}</strong>',
        '${ReportHtmlBuilder.buildBadge(i.reason, ReportKpiType.danger)} ${i.notes.isNotEmpty ? '<br><small class="text-muted">' + ReportHtmlBuilder.escape(i.notes) + '</small>' : ''}',
      ];
    }).toList();

    final totalRow = [
      '',
      'Total (${items.length} Records)',
      '',
      '',
      '${totalQty.toStringAsFixed(0)} units',
      '',
      '<strong class="text-danger">${ReportHtmlBuilder.formatCurrency(totalLoss)}</strong>',
      '',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Dump Stock & Damage Report', subtitle: 'Damaged / Expired / Unusable Inventory')}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Damage Loss', value: ReportHtmlBuilder.formatCurrency(totalLoss), type: ReportKpiType.danger),
        ReportKpi(label: 'Total Dumped Qty', value: '${totalQty.toStringAsFixed(0)} units', type: ReportKpiType.warning),
        ReportKpi(label: 'Dump Incident Records', value: '${items.length}', type: ReportKpiType.neutral),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No dump stock or damaged inventory recorded.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Dump Stock Report', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 10. Top Trending Report
  // ─────────────────────────────────────────────────────────────
  static String generateTopTrending({
    required ShopModel? shop,
    required String tabTitle,
    required String periodLabel,
    required List<TrendingRecord> records,
  }) {
    final totalAmount = records.fold(0.0, (sum, r) => sum + r.amount);
    final totalBills = records.fold(0, (sum, r) => sum + r.billCount);

    final columns = [
      const ReportColumn(title: 'Rank', width: '45px', align: TextAlign.center),
      ReportColumn(title: tabTitle, align: TextAlign.left),
      const ReportColumn(title: 'Details', align: TextAlign.left),
      const ReportColumn(title: 'Transactions', width: '100px', align: TextAlign.center),
      const ReportColumn(title: 'Quantity', width: '90px', align: TextAlign.center),
      const ReportColumn(title: 'Total Amount (₹)', width: '130px', align: TextAlign.right),
      const ReportColumn(title: 'Share %', width: '75px', align: TextAlign.center),
    ];

    final rows = records.map((r) {
      return [
        '#${r.rank}',
        '<strong>${ReportHtmlBuilder.escape(r.title)}</strong>',
        ReportHtmlBuilder.escape(r.subtitle),
        '${r.billCount} bills',
        r.quantity > 0 ? '${r.quantity.toStringAsFixed(0)} ${r.unit}' : '-',
        '<strong class="text-success">${ReportHtmlBuilder.formatCurrency(r.amount)}</strong>',
        '<strong>${r.sharePercent.toStringAsFixed(1)}%</strong>',
      ];
    }).toList();

    final totalRow = [
      '',
      'Total (${records.length} records)',
      '',
      '$totalBills bills',
      '',
      '<strong class="text-success">${ReportHtmlBuilder.formatCurrency(totalAmount)}</strong>',
      '100%',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Top Trending Report - $tabTitle', subtitle: 'Business Performance Analytics', period: periodLabel)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Volume / Sales', value: ReportHtmlBuilder.formatCurrency(totalAmount), type: ReportKpiType.success),
        ReportKpi(label: 'Total Bill Invoices', value: '$totalBills', type: ReportKpiType.info),
        ReportKpi(label: '#1 Top Ranker', value: records.isNotEmpty ? records.first.title : '-', type: ReportKpiType.warning, subtext: records.isNotEmpty ? '${records.first.sharePercent.toStringAsFixed(1)}% share' : null),
        ReportKpi(label: 'Rankings Analyzed', value: '${records.length}', type: ReportKpiType.neutral),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No trending records found for $periodLabel.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Top Trending - $tabTitle ($periodLabel)', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 11. Top Re-Order Items Report
  // ─────────────────────────────────────────────────────────────
  static String generateTopReorderItems({
    required ShopModel? shop,
    required String filterLabel,
    required List<ReorderItem> items,
  }) {
    final outOfStockCount = items.where((i) => i.isOutOfStock).length;
    final lowStockCount = items.where((i) => i.isLowStock).length;
    final totalReorderUnits = items.fold(0.0, (sum, i) => sum + i.suggestedReorderQty);

    final columns = [
      const ReportColumn(title: 'Rank', width: '45px', align: TextAlign.center),
      const ReportColumn(title: 'Item Name', align: TextAlign.left),
      const ReportColumn(title: 'Category', width: '100px', align: TextAlign.center),
      const ReportColumn(title: 'Current Stock', width: '95px', align: TextAlign.center),
      const ReportColumn(title: 'Stock Status', width: '110px', align: TextAlign.center),
      const ReportColumn(title: 'Sold Qty', width: '80px', align: TextAlign.center),
      const ReportColumn(title: 'Selling Price', width: '95px', align: TextAlign.right),
      const ReportColumn(title: 'Last Sold', width: '95px', align: TextAlign.center),
      const ReportColumn(title: 'Suggested Reorder', width: '120px', align: TextAlign.center),
    ];

    final rows = items.map((i) {
      ReportKpiType badgeType = ReportKpiType.success;
      String statusText = 'Normal';
      if (i.isOutOfStock) {
        badgeType = ReportKpiType.danger;
        statusText = 'OUT OF STOCK';
      } else if (i.isLowStock) {
        badgeType = ReportKpiType.warning;
        statusText = 'LOW STOCK';
      }

      return [
        '#${i.rank}',
        '<strong>${ReportHtmlBuilder.escape(i.name)}</strong>',
        ReportHtmlBuilder.escape(i.category),
        '<strong class="${i.currentStock <= 0 ? 'text-danger' : ''}">${i.currentStock.toStringAsFixed(0)} ${i.unit}</strong>',
        ReportHtmlBuilder.buildBadge(statusText, badgeType),
        '${i.totalSoldQty.toStringAsFixed(0)}',
        ReportHtmlBuilder.formatCurrency(i.sellingPrice),
        i.lastSoldDateFormatted,
        '<strong class="text-info">${i.suggestedReorderQty.toStringAsFixed(0)} ${i.unit}</strong>',
      ];
    }).toList();

    final totalRow = [
      '',
      'Total (${items.length} Re-Order Items)',
      '',
      '',
      '',
      '',
      '',
      '',
      '<strong class="text-info">${totalReorderUnits.toStringAsFixed(0)} units</strong>',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Top Re-Order Items Report', subtitle: 'Replenishment & Demand Forecast', period: filterLabel)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Out of Stock Items', value: '$outOfStockCount', type: ReportKpiType.danger),
        ReportKpi(label: 'Low Stock Items', value: '$lowStockCount', type: ReportKpiType.warning),
        ReportKpi(label: 'Total Reorder Need', value: '${totalReorderUnits.toStringAsFixed(0)} units', type: ReportKpiType.info),
        ReportKpi(label: 'Total Items Monitored', value: '${items.length}', type: ReportKpiType.neutral),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No re-order items found for $filterLabel.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Top Re-Order Items - $filterLabel', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 12. Transaction Voucher Report
  // ─────────────────────────────────────────────────────────────
  static String generateTransactionVouchers({
    required ShopModel? shop,
    required String periodLabel,
    required String typeFilterLabel,
    required List<VoucherItem> vouchers,
  }) {
    final totalInflow = vouchers.where((v) => v.isInflow).fold(0.0, (sum, v) => sum + v.amount);
    final totalOutflow = vouchers.where((v) => !v.isInflow).fold(0.0, (sum, v) => sum + v.amount);
    final netFlow = totalInflow - totalOutflow;

    final columns = [
      const ReportColumn(title: 'Date', width: '85px', align: TextAlign.center),
      const ReportColumn(title: 'Voucher No', width: '100px', align: TextAlign.center),
      const ReportColumn(title: 'Type', width: '90px', align: TextAlign.center),
      const ReportColumn(title: 'Party / Ledger Head', align: TextAlign.left),
      const ReportColumn(title: 'Payment Mode', width: '95px', align: TextAlign.center),
      const ReportColumn(title: 'Inflow (+)', width: '110px', align: TextAlign.right),
      const ReportColumn(title: 'Outflow (-)', width: '110px', align: TextAlign.right),
    ];

    final rows = vouchers.map((v) {
      ReportKpiType badgeType = ReportKpiType.neutral;
      if (v.voucherType.toLowerCase() == 'sale' || v.voucherType.toLowerCase() == 'receipt') {
        badgeType = ReportKpiType.success;
      } else if (v.voucherType.toLowerCase() == 'purchase' || v.voucherType.toLowerCase() == 'payment' || v.voucherType.toLowerCase() == 'expense') {
        badgeType = ReportKpiType.danger;
      }

      return [
        ReportHtmlBuilder.formatDate(v.date),
        '<strong>${ReportHtmlBuilder.escape(v.voucherNo)}</strong>',
        ReportHtmlBuilder.buildBadge(v.voucherType, badgeType),
        '<strong>${ReportHtmlBuilder.escape(v.partyName)}</strong>${v.notes.isNotEmpty ? '<br><small class="text-muted">' + ReportHtmlBuilder.escape(v.notes) + '</small>' : ''}',
        ReportHtmlBuilder.escape(v.paymentMode),
        v.isInflow ? '<strong class="text-success">${ReportHtmlBuilder.formatCurrency(v.amount)}</strong>' : '-',
        !v.isInflow ? '<strong class="text-danger">${ReportHtmlBuilder.formatCurrency(v.amount)}</strong>' : '-',
      ];
    }).toList();

    final totalRow = [
      'Total',
      '',
      '',
      '${vouchers.length} Vouchers',
      '',
      '<strong class="text-success">${ReportHtmlBuilder.formatCurrency(totalInflow)}</strong>',
      '<strong class="text-danger">${ReportHtmlBuilder.formatCurrency(totalOutflow)}</strong>',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Transaction Voucher Register', subtitle: 'Filter: $typeFilterLabel', period: periodLabel)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Inflow (Dr)', value: ReportHtmlBuilder.formatCurrency(totalInflow), type: ReportKpiType.success),
        ReportKpi(label: 'Total Outflow (Cr)', value: ReportHtmlBuilder.formatCurrency(totalOutflow), type: ReportKpiType.danger),
        ReportKpi(label: 'Net Balance Flow', value: ReportHtmlBuilder.formatCurrency(netFlow), type: netFlow >= 0 ? ReportKpiType.success : ReportKpiType.danger),
        ReportKpi(label: 'Total Vouchers', value: '${vouchers.length}', type: ReportKpiType.info),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No transaction vouchers found for this period.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Transaction Vouchers - $periodLabel', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 13. Trial Balance Report
  // ─────────────────────────────────────────────────────────────
  static String generateTrialBalance({
    required ShopModel? shop,
    required DateTime asOnDate,
    required List<TrialBalanceEntry> entries,
  }) {
    final asOnDateStr = ReportHtmlBuilder.formatDate(asOnDate);
    final totalDebit = entries.fold(0.0, (sum, e) => sum + e.debitAmount);
    final totalCredit = entries.fold(0.0, (sum, e) => sum + e.creditAmount);
    final diff = (totalDebit - totalCredit).abs();
    final isBalanced = diff < 0.01;

    final columns = [
      const ReportColumn(title: '#', width: '35px', align: TextAlign.center),
      const ReportColumn(title: 'Account Particulars / Head', align: TextAlign.left),
      const ReportColumn(title: 'Accounting Group', width: '130px', align: TextAlign.center),
      const ReportColumn(title: 'Debit Amount (₹)', width: '150px', align: TextAlign.right),
      const ReportColumn(title: 'Credit Amount (₹)', width: '150px', align: TextAlign.right),
    ];

    final rows = entries.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final e = entry.value;
      return [
        '$idx',
        '<strong>${ReportHtmlBuilder.escape(e.accountHead)}</strong>',
        ReportHtmlBuilder.buildBadge(e.group, ReportKpiType.neutral),
        e.debitAmount > 0 ? ReportHtmlBuilder.formatCurrency(e.debitAmount) : '-',
        e.creditAmount > 0 ? ReportHtmlBuilder.formatCurrency(e.creditAmount) : '-',
      ];
    }).toList();

    final totalRow = [
      '',
      'Grand Total (${entries.length} Accounts)',
      isBalanced ? ReportHtmlBuilder.buildBadge('Balanced', ReportKpiType.success) : ReportHtmlBuilder.buildBadge('Diff: ₹${diff.toStringAsFixed(2)}', ReportKpiType.danger),
      '<strong class="text-primary">${ReportHtmlBuilder.formatCurrency(totalDebit)}</strong>',
      '<strong class="text-primary">${ReportHtmlBuilder.formatCurrency(totalCredit)}</strong>',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Trial Balance Report', period: 'As on $asOnDateStr')}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Debit (Dr)', value: ReportHtmlBuilder.formatCurrency(totalDebit), type: ReportKpiType.info),
        ReportKpi(label: 'Total Credit (Cr)', value: ReportHtmlBuilder.formatCurrency(totalCredit), type: ReportKpiType.info),
        ReportKpi(label: 'Balancing Status', value: isBalanced ? 'BALANCED' : 'OUT OF BALANCE', type: isBalanced ? ReportKpiType.success : ReportKpiType.danger, subtext: isBalanced ? '0.00 discrepancy' : 'Diff: ₹${diff.toStringAsFixed(2)}'),
        ReportKpi(label: 'Ledger Heads', value: '${entries.length}', type: ReportKpiType.neutral),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No trial balance accounts available.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Trial Balance - As on $asOnDateStr', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 14. Trading Account Report (T-Account Format)
  // ─────────────────────────────────────────────────────────────
  static String generateTradingAccount({
    required ShopModel? shop,
    required String periodLabel,
    required double openingStock,
    required double purchases,
    required double directExpenses,
    required double sales,
    required double closingStock,
    required double grossProfit,
    required Map<String, double> purchaseCategories,
    required Map<String, double> directExpenseCategories,
  }) {
    final isGrossProfit = grossProfit >= 0;
    final totalCreditSide = sales + closingStock + (isGrossProfit ? 0 : grossProfit.abs());
    final totalDebitSide = openingStock + purchases + directExpenses + (isGrossProfit ? grossProfit : 0);

    // Build Debit Side Lines
    final debitRows = <String>[];
    debitRows.add('<tr><td><strong>To Opening Stock</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(openingStock)}</strong></td></tr>');
    debitRows.add('<tr><td><strong>To Purchases</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(purchases)}</strong></td></tr>');
    for (final entry in purchaseCategories.entries) {
      if (entry.value > 0) {
        debitRows.add('<tr><td style="padding-left:20px; color:#475569;"><small>• ${ReportHtmlBuilder.escape(entry.key)}</small></td><td class="text-right" style="color:#475569;"><small>${ReportHtmlBuilder.formatCurrency(entry.value)}</small></td></tr>');
      }
    }

    debitRows.add('<tr><td><strong>To Direct Expenses</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(directExpenses)}</strong></td></tr>');
    for (final entry in directExpenseCategories.entries) {
      if (entry.value > 0) {
        debitRows.add('<tr><td style="padding-left:20px; color:#475569;"><small>• ${ReportHtmlBuilder.escape(entry.key)}</small></td><td class="text-right" style="color:#475569;"><small>${ReportHtmlBuilder.formatCurrency(entry.value)}</small></td></tr>');
      }
    }

    if (isGrossProfit) {
      debitRows.add('<tr style="background:#dcfce7;"><td><strong class="text-success">To Gross Profit c/d</strong></td><td class="text-right"><strong class="text-success">${ReportHtmlBuilder.formatCurrency(grossProfit)}</strong></td></tr>');
    }

    // Build Credit Side Lines
    final creditRows = <String>[];
    creditRows.add('<tr><td><strong>By Sales Revenue</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(sales)}</strong></td></tr>');
    creditRows.add('<tr><td><strong>By Closing Stock</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(closingStock)}</strong></td></tr>');
    if (!isGrossProfit) {
      creditRows.add('<tr style="background:#fee2e2;"><td><strong class="text-danger">By Gross Loss c/d</strong></td><td class="text-right"><strong class="text-danger">${ReportHtmlBuilder.formatCurrency(grossProfit.abs())}</strong></td></tr>');
    }

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Trading Account Report', period: periodLabel)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Sales Revenue', value: ReportHtmlBuilder.formatCurrency(sales), type: ReportKpiType.success),
        ReportKpi(label: 'Total Purchases', value: ReportHtmlBuilder.formatCurrency(purchases), type: ReportKpiType.neutral),
        ReportKpi(label: isGrossProfit ? 'Gross Profit' : 'Gross Loss', value: ReportHtmlBuilder.formatCurrency(grossProfit.abs()), type: isGrossProfit ? ReportKpiType.success : ReportKpiType.danger, subtext: sales > 0 ? 'Margin: ${((grossProfit / sales) * 100).toStringAsFixed(1)}%' : null),
        ReportKpi(label: 'Closing Stock Asset', value: ReportHtmlBuilder.formatCurrency(closingStock), type: ReportKpiType.info),
      ])}
      <div class="dual-grid">
        <div class="side-box">
          <div class="side-box-header"><span>Debit (Expenses & Stock)</span><span>Amount (₹)</span></div>
          <table class="data-table" style="margin-bottom:0;">
            <tbody>
              ${debitRows.join('\n')}
              <tr class="total-row"><td><strong>Total Debit</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(totalDebitSide)}</strong></td></tr>
            </tbody>
          </table>
        </div>
        <div class="side-box">
          <div class="side-box-header credit"><span>Credit (Revenue & Stock)</span><span>Amount (₹)</span></div>
          <table class="data-table" style="margin-bottom:0;">
            <tbody>
              ${creditRows.join('\n')}
              <tr class="total-row"><td><strong>Total Credit</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(totalCreditSide)}</strong></td></tr>
            </tbody>
          </table>
        </div>
      </div>
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Trading Account - $periodLabel', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 15. Profit & Loss Account Report
  // ─────────────────────────────────────────────────────────────
  static String generateProfitLoss({
    required ShopModel? shop,
    required String periodLabel,
    required double totalSales,
    required double totalPurchases,
    required double grossProfit,
    required double otherIncome,
    required double totalIndirectExpenses,
    required List<ExpenseCategoryItem> expenseCategories,
  }) {
    final netProfit = grossProfit + otherIncome - totalIndirectExpenses;
    final isNetProfit = netProfit >= 0;

    final expenseRows = expenseCategories.map((ec) {
      return '''
        <tr>
          <td>${ReportHtmlBuilder.escape(ec.category)}</td>
          <td class="text-center">${ec.percentage.toStringAsFixed(1)}%</td>
          <td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(ec.amount)}</strong></td>
        </tr>
      ''';
    }).join('\n');

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Profit & Loss Statement', period: periodLabel)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Gross Profit', value: ReportHtmlBuilder.formatCurrency(grossProfit), type: grossProfit >= 0 ? ReportKpiType.success : ReportKpiType.danger),
        ReportKpi(label: 'Indirect Expenses', value: ReportHtmlBuilder.formatCurrency(totalIndirectExpenses), type: ReportKpiType.danger),
        ReportKpi(label: 'Other Income', value: ReportHtmlBuilder.formatCurrency(otherIncome), type: ReportKpiType.info),
        ReportKpi(label: isNetProfit ? 'Net Profit' : 'Net Loss', value: ReportHtmlBuilder.formatCurrency(netProfit.abs()), type: isNetProfit ? ReportKpiType.success : ReportKpiType.danger, subtext: totalSales > 0 ? 'Net Margin: ${((netProfit / totalSales) * 100).toStringAsFixed(1)}%' : null),
      ])}

      <div class="dual-grid">
        <div class="side-box">
          <div class="side-box-header"><span>Operating Incomes</span><span>Amount (₹)</span></div>
          <table class="data-table" style="margin-bottom:0;">
            <tbody>
              <tr><td>Gross Profit (from Trading A/C)</td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(grossProfit)}</strong></td></tr>
              ${otherIncome > 0 ? '<tr><td>Other Incomes / Receipts</td><td class="text-right"><strong>' + ReportHtmlBuilder.formatCurrency(otherIncome) + '</strong></td></tr>' : ''}
              <tr class="total-row"><td><strong>Total Operating Incomes</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(grossProfit + otherIncome)}</strong></td></tr>
            </tbody>
          </table>
        </div>
        <div class="side-box">
          <div class="side-box-header credit" style="background:#dc2626;"><span>Indirect Expenses Breakdown</span><span>Amount (₹)</span></div>
          <table class="data-table" style="margin-bottom:0;">
            <thead>
              <tr><th>Category</th><th class="text-center">Share</th><th class="text-right">Amount</th></tr>
            </thead>
            <tbody>
              ${expenseRows.isNotEmpty ? expenseRows : '<tr><td colspan="3" class="text-center" style="padding:14px; color:#64748b;">No indirect expenses recorded.</td></tr>'}
              <tr class="total-row"><td><strong>Total Indirect Expenses</strong></td><td class="text-center">100%</td><td class="text-right"><strong class="text-danger">${ReportHtmlBuilder.formatCurrency(totalIndirectExpenses)}</strong></td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <div style="background:${isNetProfit ? '#dcfce7' : '#fee2e2'}; border:1px solid ${isNetProfit ? '#86efac' : '#fca5a5'}; border-radius:8px; padding:16px; margin:20px 0; display:flex; justify-content:space-between; align-items:center;">
        <div>
          <div style="font-size:16px; font-weight:800; color:${isNetProfit ? '#15803d' : '#991b1b'};">Final ${isNetProfit ? 'Net Profit' : 'Net Loss'} for the Period</div>
          <div style="font-size:11.5px; color:#475569;">Gross Profit (₹${grossProfit.toStringAsFixed(0)}) + Other Income (₹${otherIncome.toStringAsFixed(0)}) - Indirect Expenses (₹${totalIndirectExpenses.toStringAsFixed(0)})</div>
        </div>
        <div style="text-align:right;">
          <div style="font-size:22px; font-weight:900; color:${isNetProfit ? '#15803d' : '#dc2626'};">${ReportHtmlBuilder.formatCurrency(netProfit.abs())}</div>
          <div style="font-size:11px; font-weight:700; color:${isNetProfit ? '#15803d' : '#dc2626'};">${isNetProfit ? 'SURPLUS TRANSFERRED TO CAPITAL' : 'DEFICIT DEDUCTED FROM CAPITAL'}</div>
        </div>
      </div>

      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Profit & Loss Statement - $periodLabel', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 16. Balance Sheet Report
  // ─────────────────────────────────────────────────────────────
  static String generateBalanceSheet({
    required ShopModel? shop,
    required DateTime asOnDate,
    required double cashInHand,
    required double bankBalance,
    required double sundryDebtors,
    required double closingStock,
    required double sundryCreditors,
    required double outstandingExpenses,
    required double proprietorCapital,
  }) {
    final asOnDateStr = ReportHtmlBuilder.formatDate(asOnDate);
    final totalAssets = cashInHand + bankBalance + sundryDebtors + closingStock;
    final totalLiabilitiesAndCapital = sundryCreditors + outstandingExpenses + proprietorCapital;
    final diff = (totalAssets - totalLiabilitiesAndCapital).abs();
    final isTally = diff < 1.0;

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Balance Sheet Statement', period: 'As on $asOnDateStr')}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Total Assets', value: ReportHtmlBuilder.formatCurrency(totalAssets), type: ReportKpiType.success),
        ReportKpi(label: 'Total Liabilities & Capital', value: ReportHtmlBuilder.formatCurrency(totalLiabilitiesAndCapital), type: ReportKpiType.info),
        ReportKpi(label: 'Proprietor Equity / Capital', value: ReportHtmlBuilder.formatCurrency(proprietorCapital), type: ReportKpiType.warning),
        ReportKpi(label: 'Tally Verification', value: isTally ? 'TALLIED' : 'DIFF: ₹${diff.toStringAsFixed(0)}', type: isTally ? ReportKpiType.success : ReportKpiType.danger),
      ])}

      <div class="dual-grid">
        <!-- Liabilities Side -->
        <div class="side-box">
          <div class="side-box-header"><span>Liabilities & Capital</span><span>Amount (₹)</span></div>
          <table class="data-table" style="margin-bottom:0;">
            <tbody>
              <tr><td colspan="2" style="background:#f1f5f9; font-weight:700; color:#334155; font-size:10.5px; text-transform:uppercase;">Current Liabilities</td></tr>
              <tr><td style="padding-left:16px;">Sundry Creditors (Suppliers Payable)</td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(sundryCreditors)}</strong></td></tr>
              <tr><td style="padding-left:16px;">Outstanding Expenses & Other Due</td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(outstandingExpenses)}</strong></td></tr>
              <tr><td colspan="2" style="background:#f1f5f9; font-weight:700; color:#334155; font-size:10.5px; text-transform:uppercase;">Owner Equity</td></tr>
              <tr><td style="padding-left:16px;"><strong>Proprietor's Capital Account</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(proprietorCapital)}</strong></td></tr>
              <tr class="total-row"><td><strong>Total Liabilities & Capital</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(totalLiabilitiesAndCapital)}</strong></td></tr>
            </tbody>
          </table>
        </div>

        <!-- Assets Side -->
        <div class="side-box">
          <div class="side-box-header credit"><span>Assets (Resources & Stocks)</span><span>Amount (₹)</span></div>
          <table class="data-table" style="margin-bottom:0;">
            <tbody>
              <tr><td colspan="2" style="background:#f1f5f9; font-weight:700; color:#334155; font-size:10.5px; text-transform:uppercase;">Current Assets</td></tr>
              <tr><td style="padding-left:16px;">Cash in Hand</td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(cashInHand)}</strong></td></tr>
              <tr><td style="padding-left:16px;">Bank Balances</td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(bankBalance)}</strong></td></tr>
              <tr><td style="padding-left:16px;">Sundry Debtors (Receivable Udhar)</td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(sundryDebtors)}</strong></td></tr>
              <tr><td style="padding-left:16px;">Closing Stock in Hand</td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(closingStock)}</strong></td></tr>
              <tr class="total-row"><td><strong>Total Assets</strong></td><td class="text-right"><strong>${ReportHtmlBuilder.formatCurrency(totalAssets)}</strong></td></tr>
            </tbody>
          </table>
        </div>
      </div>

      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Balance Sheet - As on $asOnDateStr', bodyContent: body);
  }

  // ─────────────────────────────────────────────────────────────
  // 17. Ledger Particular Month Report
  // ─────────────────────────────────────────────────────────────
  static String generateLedgerParticularMonth({
    required ShopModel? shop,
    required String partyName,
    required bool isReceivable,
    required String monthLabel,
    required double openingBalance,
    required List<Map<String, dynamic>> entries,
    required double closingBalance,
  }) {
    double totalDebit = 0;
    double totalCredit = 0;

    for (final e in entries) {
      totalDebit += (e['debit'] as num?)?.toDouble() ?? 0.0;
      totalCredit += (e['credit'] as num?)?.toDouble() ?? 0.0;
    }

    final columns = [
      const ReportColumn(title: 'Date', width: '90px', align: TextAlign.center),
      const ReportColumn(title: 'Particulars / Description', align: TextAlign.left),
      const ReportColumn(title: 'Ref / Bill', width: '100px', align: TextAlign.center),
      const ReportColumn(title: 'Debit (Dr)', width: '110px', align: TextAlign.right),
      const ReportColumn(title: 'Credit (Cr)', width: '110px', align: TextAlign.right),
      const ReportColumn(title: 'Running Balance', width: '120px', align: TextAlign.right),
    ];

    final rows = <List<String>>[];
    // Opening balance row
    rows.add([
      '',
      '<strong>Opening Balance b/f</strong>',
      '-',
      openingBalance > 0 && isReceivable ? ReportHtmlBuilder.formatCurrency(openingBalance) : '-',
      openingBalance > 0 && !isReceivable ? ReportHtmlBuilder.formatCurrency(openingBalance) : '-',
      '<strong>${ReportHtmlBuilder.formatCurrency(openingBalance)}</strong>',
    ]);

    for (final e in entries) {
      final debit = (e['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (e['credit'] as num?)?.toDouble() ?? 0.0;
      final bal = (e['balance'] as num?)?.toDouble() ?? 0.0;
      final date = e['date'] is DateTime ? ReportHtmlBuilder.formatDate(e['date'] as DateTime) : (e['date']?.toString() ?? '');

      rows.add([
        date,
        '<strong>${ReportHtmlBuilder.escape(e['particulars']?.toString() ?? '-')}</strong>',
        ReportHtmlBuilder.escape(e['ref']?.toString() ?? '-'),
        debit > 0 ? ReportHtmlBuilder.formatCurrency(debit) : '-',
        credit > 0 ? ReportHtmlBuilder.formatCurrency(credit) : '-',
        '<strong>${ReportHtmlBuilder.formatCurrency(bal)}</strong>',
      ]);
    }

    final totalRow = [
      'Total',
      'Closing Balance: <strong>${ReportHtmlBuilder.formatCurrency(closingBalance)}</strong>',
      '',
      '<strong class="text-primary">${ReportHtmlBuilder.formatCurrency(totalDebit)}</strong>',
      '<strong class="text-primary">${ReportHtmlBuilder.formatCurrency(totalCredit)}</strong>',
      '<strong class="${closingBalance > 0 ? 'text-danger' : 'text-success'}">${ReportHtmlBuilder.formatCurrency(closingBalance)}</strong>',
    ];

    final body = '''
      ${ReportHtmlBuilder.buildHeader(shop: shop, title: 'Party Ledger Account Report', subtitle: '$partyName (${isReceivable ? "Customer / Debtor" : "Supplier / Creditor"})', period: monthLabel)}
      ${ReportHtmlBuilder.buildKpiStrip([
        ReportKpi(label: 'Opening Balance', value: ReportHtmlBuilder.formatCurrency(openingBalance), type: ReportKpiType.neutral),
        ReportKpi(label: 'Total Debit (Dr)', value: ReportHtmlBuilder.formatCurrency(totalDebit), type: ReportKpiType.info),
        ReportKpi(label: 'Total Credit (Cr)', value: ReportHtmlBuilder.formatCurrency(totalCredit), type: ReportKpiType.info),
        ReportKpi(label: 'Closing Balance', value: ReportHtmlBuilder.formatCurrency(closingBalance), type: closingBalance > 0 ? ReportKpiType.danger : ReportKpiType.success),
      ])}
      ${ReportHtmlBuilder.buildTable(columns: columns, rows: rows, totalRow: totalRow, emptyMessage: 'No transactions in this month.')}
      ${ReportHtmlBuilder.buildFooter(shop)}
    ''';

    return ReportHtmlBuilder.buildDocument(title: 'Ledger - $partyName ($monthLabel)', bodyContent: body);
  }
}
