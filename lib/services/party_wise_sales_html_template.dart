import 'package:intl/intl.dart';
import '../../models/shop_model.dart';
import '../../models/bill_model.dart';

class PartyItemSale {
  final String itemName;
  final double quantity;
  final String unit;
  final double totalAmount;
  final double avgRate;
  final int orderCount;
  final DateTime? lastDate;

  PartyItemSale({
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.totalAmount,
    required this.avgRate,
    required this.orderCount,
    this.lastDate,
  });
}

class PartySaleSummary {
  final String partyName;
  final String phone;
  final String address;
  final List<BillModel> bills;
  final List<PartyItemSale> items;
  final double totalSales;
  final double totalPaid;
  final double totalCredit;
  final Set<String> paymentModes;

  PartySaleSummary({
    required this.partyName,
    this.phone = '',
    this.address = '',
    required this.bills,
    required this.items,
    required this.totalSales,
    required this.totalPaid,
    required this.totalCredit,
    required this.paymentModes,
  });

  int get invoiceCount => bills.length;
}

class PartyWiseSalesHtmlTemplate {
  /// Master One-Stop PDF Report of every party in the data area with total amount, paid, credit, payment modes
  static String generateMasterReport({
    required ShopModel? shop,
    required String filterPeriodLabel,
    required DateTime fromDate,
    required DateTime toDate,
    required List<PartySaleSummary> parties,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateRangeStr = '${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}';
    final generatedOn = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());

    final shopName = shop?.shopName.isNotEmpty == true ? shop!.shopName : 'SaafHisaab Merchant';
    final shopCity = shop?.city ?? '';
    final shopPhone = shop?.phone ?? '';
    final shopGst = shop?.gstNumber ?? '';

    double grandTotalSales = 0.0;
    double grandTotalPaid = 0.0;
    double grandTotalCredit = 0.0;
    int grandTotalBills = 0;

    for (final p in parties) {
      grandTotalSales += p.totalSales;
      grandTotalPaid += p.totalPaid;
      grandTotalCredit += p.totalCredit;
      grandTotalBills += p.invoiceCount;
    }

    final rowsHtml = parties.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final p = entry.value;

      final modes = p.paymentModes.map((m) {
        final upper = m.toUpperCase();
        if (upper.contains('CASH')) return 'Cash';
        if (upper.contains('UPI') || upper.contains('ONLINE') || upper.contains('E-PAY')) return 'UPI';
        if (upper.contains('CREDIT') || upper.contains('UDHAR')) return 'Credit';
        return m;
      }).toSet().join(', ');

      String statusBadge = '<span class="badge badge-paid">Paid</span>';
      if (p.totalCredit > 0 && p.totalPaid > 0) {
        statusBadge = '<span class="badge badge-partial">Partial</span>';
      } else if (p.totalCredit > 0) {
        statusBadge = '<span class="badge badge-due">Credit / Due</span>';
      }

      return '''
        <tr>
          <td class="text-center">$index</td>
          <td>
            <strong>${_escapeHtml(p.partyName)}</strong>
            ${p.phone.isNotEmpty ? '<br><small class="text-muted">📞 +91 ${_escapeHtml(p.phone)}</small>' : ''}
          </td>
          <td class="text-center">${p.invoiceCount}</td>
          <td class="text-right"><strong>₹${p.totalSales.toStringAsFixed(2)}</strong></td>
          <td class="text-right text-success">₹${p.totalPaid.toStringAsFixed(2)}</td>
          <td class="text-right ${p.totalCredit > 0 ? 'text-danger' : ''}">₹${p.totalCredit.toStringAsFixed(2)}</td>
          <td class="text-center"><small>${_escapeHtml(modes.isNotEmpty ? modes : 'Cash')}</small></td>
          <td class="text-center">$statusBadge</td>
        </tr>
      ''';
    }).join('\n');

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Party-Wise Sales Summary - $filterPeriodLabel</title>
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
      font-size: 13px;
      color: #1e293b;
      background: #f8fafc;
      padding: 24px;
    }
    .report-card {
      max-width: 900px;
      margin: 0 auto;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.04);
      padding: 32px;
    }
    .header-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      border-bottom: 2px solid #2563eb;
      padding-bottom: 20px;
      margin-bottom: 20px;
    }
    .shop-info h1 {
      font-size: 24px;
      font-weight: 800;
      color: #1e3a8a;
      letter-spacing: -0.5px;
      margin-bottom: 4px;
    }
    .shop-info p {
      font-size: 12px;
      color: #475569;
      line-height: 1.5;
    }
    .report-meta {
      text-align: right;
    }
    .report-meta h2 {
      font-size: 18px;
      font-weight: 800;
      color: #2563eb;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 4px;
    }
    .report-meta p {
      font-size: 12px;
      color: #64748b;
      line-height: 1.5;
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      font-size: 10px;
      font-weight: 700;
      border-radius: 4px;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .badge-paid { background: #dcfce7; color: #15803d; border: 1px solid #86efac; }
    .badge-partial { background: #fef3c7; color: #b45309; border: 1px solid #fde68a; }
    .badge-due { background: #fee2e2; color: #b91c1c; border: 1px solid #fca5a5; }

    /* KPI Summary Strip */
    .kpi-strip {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 12px;
      margin-bottom: 24px;
    }
    .kpi-box {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 12px 14px;
      text-align: center;
    }
    .kpi-label {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      color: #64748b;
      margin-bottom: 4px;
    }
    .kpi-value {
      font-size: 18px;
      font-weight: 800;
      color: #1e3a8a;
    }
    .text-success { color: #16a34a !important; }
    .text-danger { color: #dc2626 !important; }

    /* Tables */
    table.data-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 24px;
    }
    table.data-table th {
      background: #f1f5f9;
      color: #334155;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      padding: 10px 8px;
      border-top: 1px solid #cbd5e1;
      border-bottom: 2px solid #cbd5e1;
    }
    table.data-table td {
      padding: 9px 8px;
      border-bottom: 1px solid #e2e8f0;
      font-size: 12px;
      vertical-align: middle;
    }
    table.data-table tr:nth-child(even) td { background: #fafafa; }
    table.data-table tr.total-row td {
      background: #eff6ff;
      border-top: 2px solid #2563eb;
      border-bottom: 2px solid #2563eb;
      font-size: 13px;
      font-weight: 800;
      color: #1e3a8a;
    }

    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .text-muted { color: #64748b; font-size: 11px; }

    .footer {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 32px;
      padding-top: 16px;
      border-top: 1px solid #e2e8f0;
      font-size: 11px;
      color: #64748b;
    }

    @media print {
      body { background: #ffffff; padding: 0; }
      .report-card { border: none; box-shadow: none; padding: 0; max-width: 100%; }
      .no-print { display: none !important; }
      @page { size: A4 portrait; margin: 10mm; }
    }
  </style>
</head>
<body>
  <div class="report-card">
    <div class="header-row">
      <div class="shop-info">
        <h1>${_escapeHtml(shopName)}</h1>
        ${shopCity.isNotEmpty ? '<p>Location: ' + _escapeHtml(shopCity) + '</p>' : ''}
        ${shopPhone.isNotEmpty ? '<p>Phone: +91 ' + _escapeHtml(shopPhone) + '</p>' : ''}
        ${shopGst.isNotEmpty ? '<p><strong>GSTIN: ' + _escapeHtml(shopGst) + '</strong></p>' : ''}
      </div>
      <div class="report-meta">
        <h2>Party-Wise Sales Summary</h2>
        <p><strong>Filter:</strong> ${_escapeHtml(filterPeriodLabel)}</p>
        <p><strong>Date Range:</strong> $dateRangeStr</p>
        <p><strong>Generated On:</strong> $generatedOn</p>
      </div>
    </div>

    <!-- KPI Summary Strip -->
    <div class="kpi-strip">
      <div class="kpi-box">
        <div class="kpi-label">Total Sales</div>
        <div class="kpi-value">₹${grandTotalSales.toStringAsFixed(2)}</div>
      </div>
      <div class="kpi-box">
        <div class="kpi-label">Total Received</div>
        <div class="kpi-value text-success">₹${grandTotalPaid.toStringAsFixed(2)}</div>
      </div>
      <div class="kpi-box">
        <div class="kpi-label">Total Credit / Due</div>
        <div class="kpi-value text-danger">₹${grandTotalCredit.toStringAsFixed(2)}</div>
      </div>
      <div class="kpi-box">
        <div class="kpi-label">Parties / Bills</div>
        <div class="kpi-value">${parties.length} / $grandTotalBills</div>
      </div>
    </div>

    <!-- Data Table -->
    <table class="data-table">
      <thead>
        <tr>
          <th style="width: 35px;" class="text-center">#</th>
          <th>Party / Customer Name</th>
          <th style="width: 55px;" class="text-center">Bills</th>
          <th style="width: 110px;" class="text-right">Total Sale</th>
          <th style="width: 110px;" class="text-right">Amount Paid</th>
          <th style="width: 110px;" class="text-right">Credit (Due)</th>
          <th style="width: 85px;" class="text-center">Mode</th>
          <th style="width: 75px;" class="text-center">Status</th>
        </tr>
      </thead>
      <tbody>
        $rowsHtml
        <tr class="total-row">
          <td colspan="2" class="text-right"><strong>Grand Total:</strong></td>
          <td class="text-center"><strong>$grandTotalBills</strong></td>
          <td class="text-right"><strong>₹${grandTotalSales.toStringAsFixed(2)}</strong></td>
          <td class="text-right text-success"><strong>₹${grandTotalPaid.toStringAsFixed(2)}</strong></td>
          <td class="text-right text-danger"><strong>₹${grandTotalCredit.toStringAsFixed(2)}</strong></td>
          <td colspan="2" class="text-center"><strong>${parties.length} Parties</strong></td>
        </tr>
      </tbody>
    </table>

    <div class="footer">
      <div>Generated automatically via SaafHisaab Business Reporting Engine</div>
      <div style="font-weight: 700; color: #1e3a8a;">Authorized Report • For ${_escapeHtml(shopName)}</div>
    </div>
  </div>
</body>
</html>
''';
  }

  /// Individual Party Statement PDF report showing all items purchased and bills during the period
  static String generatePartyDetailReport({
    required ShopModel? shop,
    required PartySaleSummary party,
    required String filterPeriodLabel,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateRangeStr = '${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}';
    final generatedOn = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());

    final shopName = shop?.shopName.isNotEmpty == true ? shop!.shopName : 'SaafHisaab Merchant';
    final shopCity = shop?.city ?? '';
    final shopPhone = shop?.phone ?? '';
    final shopGst = shop?.gstNumber ?? '';

    // Item Rows
    final itemRowsHtml = party.items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final it = entry.value;
      return '''
        <tr>
          <td class="text-center">$index</td>
          <td><strong>${_escapeHtml(it.itemName)}</strong></td>
          <td class="text-center">${it.quantity.toStringAsFixed(it.quantity.truncateToDouble() == it.quantity ? 0 : 2)} ${it.unit}</td>
          <td class="text-right">₹${it.avgRate.toStringAsFixed(2)}</td>
          <td class="text-center">${it.orderCount}</td>
          <td class="text-right"><strong>₹${it.totalAmount.toStringAsFixed(2)}</strong></td>
        </tr>
      ''';
    }).join('\n');

    // Invoice Rows
    final billRowsHtml = party.bills.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final b = entry.value;
      return '''
        <tr>
          <td class="text-center">$index</td>
          <td class="text-center">${dateFormat.format(b.billDate)}</td>
          <td>${b.id.length >= 8 ? b.id.substring(0, 8).toUpperCase() : b.id}</td>
          <td class="text-center">${b.isGstBill ? 'GST' : 'Regular'}</td>
          <td class="text-right"><strong>₹${b.amount.toStringAsFixed(2)}</strong></td>
        </tr>
      ''';
    }).join('\n');

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sales Statement - ${_escapeHtml(party.partyName)}</title>
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
      font-size: 13px;
      color: #1e293b;
      background: #f8fafc;
      padding: 24px;
    }
    .report-card {
      max-width: 860px;
      margin: 0 auto;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.04);
      padding: 32px;
    }
    .header-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      border-bottom: 2px solid #2563eb;
      padding-bottom: 18px;
      margin-bottom: 20px;
    }
    .shop-info h1 {
      font-size: 22px;
      font-weight: 800;
      color: #1e3a8a;
      letter-spacing: -0.5px;
      margin-bottom: 4px;
    }
    .shop-info p {
      font-size: 12px;
      color: #475569;
      line-height: 1.5;
    }
    .report-meta { text-align: right; }
    .report-meta h2 {
      font-size: 17px;
      font-weight: 800;
      color: #2563eb;
      text-transform: uppercase;
      margin-bottom: 4px;
    }
    .report-meta p {
      font-size: 12px;
      color: #64748b;
      line-height: 1.5;
    }

    /* Party Details Banner */
    .party-banner {
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: #eff6ff;
      border: 1px solid #bfdbfe;
      border-radius: 8px;
      padding: 16px;
      margin-bottom: 20px;
    }
    .party-title {
      font-size: 18px;
      font-weight: 800;
      color: #1e3a8a;
      margin-bottom: 2px;
    }
    .party-subtitle {
      font-size: 12px;
      color: #475569;
    }
    .financial-totals {
      text-align: right;
    }
    .financial-totals .amount {
      font-size: 20px;
      font-weight: 800;
      color: #1e3a8a;
    }
    .financial-totals .sub {
      font-size: 12px;
      font-weight: 600;
    }

    h3.section-heading {
      font-size: 13px;
      font-weight: 800;
      color: #1e293b;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin: 20px 0 8px 0;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    table.data-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 16px;
    }
    table.data-table th {
      background: #f1f5f9;
      color: #334155;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      padding: 9px 8px;
      border-top: 1px solid #cbd5e1;
      border-bottom: 2px solid #cbd5e1;
    }
    table.data-table td {
      padding: 8px;
      border-bottom: 1px solid #e2e8f0;
      font-size: 12px;
      vertical-align: middle;
    }
    table.data-table tr:nth-child(even) td { background: #fafafa; }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .text-success { color: #16a34a !important; }
    .text-danger { color: #dc2626 !important; }

    .footer {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 36px;
      padding-top: 16px;
      border-top: 1px solid #e2e8f0;
      font-size: 11px;
      color: #64748b;
    }

    @media print {
      body { background: #ffffff; padding: 0; }
      .report-card { border: none; box-shadow: none; padding: 0; max-width: 100%; }
      .no-print { display: none !important; }
      @page { size: A4 portrait; margin: 10mm; }
    }
  </style>
</head>
<body>
  <div class="report-card">
    <div class="header-row">
      <div class="shop-info">
        <h1>${_escapeHtml(shopName)}</h1>
        ${shopCity.isNotEmpty ? '<p>Location: ' + _escapeHtml(shopCity) + '</p>' : ''}
        ${shopPhone.isNotEmpty ? '<p>Phone: +91 ' + _escapeHtml(shopPhone) + '</p>' : ''}
        ${shopGst.isNotEmpty ? '<p><strong>GSTIN: ' + _escapeHtml(shopGst) + '</strong></p>' : ''}
      </div>
      <div class="report-meta">
        <h2>Customer Sales Statement</h2>
        <p><strong>Period:</strong> ${_escapeHtml(filterPeriodLabel)}</p>
        <p><strong>Range:</strong> $dateRangeStr</p>
        <p><strong>Date:</strong> $generatedOn</p>
      </div>
    </div>

    <!-- Party Details Banner -->
    <div class="party-banner">
      <div>
        <div class="party-title">${_escapeHtml(party.partyName)}</div>
        <div class="party-subtitle">
          ${party.phone.isNotEmpty ? '📞 +91 ' + _escapeHtml(party.phone) : 'Customer Statement'}
          • Total Invoices: <strong>${party.invoiceCount}</strong>
        </div>
      </div>
      <div class="financial-totals">
        <div class="amount">₹${party.totalSales.toStringAsFixed(2)}</div>
        <div class="sub">
          <span class="text-success">Paid: ₹${party.totalPaid.toStringAsFixed(2)}</span>
          ${party.totalCredit > 0 ? ' • <span class="text-danger">Due: ₹' + party.totalCredit.toStringAsFixed(2) + '</span>' : ''}
        </div>
      </div>
    </div>

    <!-- Section 1: All Items Purchased -->
    <h3 class="section-heading">📦 Purchased Items Summary</h3>
    <table class="data-table">
      <thead>
        <tr>
          <th style="width: 35px;" class="text-center">#</th>
          <th>Item Name</th>
          <th style="width: 120px;" class="text-center">Total Quantity</th>
          <th style="width: 90px;" class="text-right">Avg Rate</th>
          <th style="width: 60px;" class="text-center">Orders</th>
          <th style="width: 110px;" class="text-right">Total Amount</th>
        </tr>
      </thead>
      <tbody>
        ${itemRowsHtml.isNotEmpty ? itemRowsHtml : '<tr><td colspan="6" class="text-center" style="padding:16px;">No item line-records available for this period.</td></tr>'}
      </tbody>
    </table>

    <!-- Section 2: Invoices List -->
    <h3 class="section-heading">🧾 Invoices in this Period</h3>
    <table class="data-table">
      <thead>
        <tr>
          <th style="width: 35px;" class="text-center">#</th>
          <th style="width: 100px;" class="text-center">Date</th>
          <th>Invoice Ref</th>
          <th style="width: 80px;" class="text-center">Type</th>
          <th style="width: 110px;" class="text-right">Amount</th>
        </tr>
      </thead>
      <tbody>
        $billRowsHtml
      </tbody>
    </table>

    <div class="footer">
      <div>SaafHisaab • Party-Wise Customer Statement</div>
      <div style="font-weight: 700; color: #1e3a8a;">For ${_escapeHtml(shopName)} (Authorized Signatory)</div>
    </div>
  </div>
</body>
</html>
''';
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
