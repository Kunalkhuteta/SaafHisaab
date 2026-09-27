import 'package:intl/intl.dart';
import '../../models/bill_model.dart';
import '../../models/shop_model.dart';

class InvoiceHtmlTemplate {
  /// Converts a numeric amount to Indian Currency in Words (Rupees and Paise)
  static String numberToWords(double amount) {
    if (amount <= 0) return 'Zero Rupees Only';

    final int wholePart = amount.floor();
    final int decimalPart = ((amount - wholePart) * 100).round();

    final String words = _convertIndianNumber(wholePart);
    String result = '$words Rupees';

    if (decimalPart > 0) {
      final String paiseWords = _convertIndianNumber(decimalPart);
      result += ' and $paiseWords Paise';
    }

    return '$result Only';
  }

  static const List<String> _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  static String _convertTwoDigits(int n) {
    if (n < 20) return _ones[n];
    final t = _tens[n ~/ 10];
    final o = _ones[n % 10];
    return o.isEmpty ? t : '$t $o';
  }

  static String _convertThreeDigits(int n) {
    final h = n ~/ 100;
    final rem = n % 100;
    String res = '';
    if (h > 0) {
      res += '${_ones[h]} Hundred';
    }
    if (rem > 0) {
      if (res.isNotEmpty) res += ' and ';
      res += _convertTwoDigits(rem);
    }
    return res;
  }

  static String _convertIndianNumber(int n) {
    if (n == 0) return 'Zero';

    // Indian format: Crores (10,000,000), Lakhs (100,000), Thousands (1,000), Hundreds (100)
    final cr = n ~/ 10000000;
    var rem = n % 10000000;

    final lk = rem ~/ 100000;
    rem = rem % 100000;

    final th = rem ~/ 1000;
    rem = rem % 1000;

    final hd = rem;

    final List<String> parts = [];
    if (cr > 0) {
      parts.add('${_convertIndianNumber(cr)} Crore');
    }
    if (lk > 0) {
      parts.add('${_convertTwoDigits(lk)} Lakh');
    }
    if (th > 0) {
      parts.add('${_convertTwoDigits(th)} Thousand');
    }
    if (hd > 0) {
      parts.add(_convertThreeDigits(hd));
    }

    return parts.join(' ');
  }

  /// Generates the full HTML/CSS invoice document
  static String generate({
    required ShopModel? shop,
    required BillModel bill,
    Map<String, dynamic>? invoiceData,
    String? creatorName,
  }) {
    final invTran = (invoiceData?['InvTranTbl'] as Map<String, dynamic>?) ?? {};
    final sihdr = (invoiceData?['SIHDR'] as Map<String, dynamic>?) ?? {};
    final stockList = (invoiceData?['StockDtlList'] as List<dynamic>?) ?? [];

    // 1. Shop details
    final shopName = (shop?.shopName.isNotEmpty == true) ? shop!.shopName : 'SaafHisaab Merchant';
    final shopCity = shop?.city ?? '';
    final shopPhone = shop?.phone ?? '';
    final shopGst = shop?.gstNumber ?? '';
    final shopOwner = shop?.ownerName ?? '';

    // 2. Invoice Meta
    final invNoRaw = invTran['EIDocNo']?.toString() ?? invTran['InvSeqNo']?.toString() ?? '';
    final invoiceNumber = invNoRaw.isNotEmpty && invNoRaw != '0' && invNoRaw != 'AUTO'
        ? invNoRaw
        : 'INV-${bill.id.length >= 6 ? bill.id.substring(0, 6).toUpperCase() : bill.id}';

    final dateFormat = DateFormat('dd/MM/yyyy');
    final invoiceDate = dateFormat.format(bill.billDate);
    final invoiceTime = invTran['InvTime']?.toString() ?? DateFormat('hh:mm a').format(bill.createdAt);

    // 3. Customer Details
    final buyerName = (invTran['BuyerName']?.toString().isNotEmpty == true)
        ? invTran['BuyerName'].toString()
        : (bill.vendorName.isNotEmpty ? bill.vendorName : 'Cash Customer');
    final buyerGst = invTran['BuyerGstNo']?.toString() ?? '';
    final buyerState = invTran['PosStateName']?.toString() ?? (invTran['PosStateId'] != null ? 'State ID: ${invTran['PosStateId']}' : '');

    // 4. Payment Info
    final rawMode = (sihdr['PymtMode'] ?? sihdr['PymtFlag'] ?? 'cash').toString().toUpperCase();
    String paymentModeDisplay = 'Cash';
    if (rawMode.contains('E') || rawMode.contains('UPI') || rawMode.contains('ONLINE')) {
      paymentModeDisplay = 'UPI / Online';
    } else if (rawMode.contains('R') || rawMode.contains('CREDIT')) {
      paymentModeDisplay = 'Credit (Udhar)';
    } else if (rawMode.contains('D') || rawMode.contains('SPLIT')) {
      paymentModeDisplay = 'Cash + Online';
    }

    final netAmount = (invTran['EIInvAmt'] ?? sihdr['NetAmt'] ?? bill.amount) as num;
    final cashRecd = (invTran['CashReceived'] ?? invTran['RecdAmt'] ?? sihdr['CashReceived'] ?? 0.0) as num;
    final epayAmt = (sihdr['EPymtAmt'] ?? 0.0) as num;
    final totalAdvance = cashRecd + epayAmt;
    final balanceDue = (netAmount - totalAdvance).clamp(0.0, netAmount.toDouble());

    String paymentStatusBadge = '<span class="badge badge-paid">PAID</span>';
    if (balanceDue > 0 && totalAdvance > 0) {
      paymentStatusBadge = '<span class="badge badge-partial">PARTIAL DUE: ₹${balanceDue.toStringAsFixed(2)}</span>';
    } else if (balanceDue > 0) {
      paymentStatusBadge = '<span class="badge badge-due">CREDIT / UNPAID</span>';
    }

    // 5. Items Extraction
    final List<_HtmlInvoiceItem> items = [];

    if (stockList.isNotEmpty) {
      for (int i = 0; i < stockList.length; i++) {
        final row = stockList[i];
        final stockDtl = (row['StockDtl'] as Map<String, dynamic>?) ?? (row is Map<String, dynamic> ? row : <String, dynamic>{});
        final itemName = row['ItemName']?.toString() ?? stockDtl['ItemName']?.toString() ?? stockDtl['itemName']?.toString() ?? 'Item ${i + 1}';
        final qty = ((stockDtl['STQty'] ?? stockDtl['qty'] ?? 1.0) as num).toDouble();
        final bags = ((stockDtl['STBag'] ?? stockDtl['bag'] ?? 0) as num).toInt();
        final rate = ((stockDtl['Rate'] ?? stockDtl['rate'] ?? stockDtl['selling_price'] ?? 0.0) as num).toDouble();
        final disc = ((stockDtl['DiscPr'] ?? stockDtl['discPrice'] ?? 0.0) as num).toDouble();
        final cgst = ((stockDtl['CGSTAmt'] ?? stockDtl['cgstAmt'] ?? 0.0) as num).toDouble();
        final sgst = ((stockDtl['SGSTAmt'] ?? stockDtl['sgstAmt'] ?? 0.0) as num).toDouble();
        final igst = ((stockDtl['IGSTAmt'] ?? stockDtl['igstAmt'] ?? 0.0) as num).toDouble();
        final totalGst = cgst + sgst + igst;
        final taxable = ((stockDtl['TaxOnAmt'] ?? stockDtl['taxOnAmt'] ?? (qty * rate - disc)) as num).toDouble();
        final total = ((stockDtl['Amount'] ?? stockDtl['amount'] ?? stockDtl['total_amount'] ?? (taxable + totalGst)) as num).toDouble();
        final unit = stockDtl['CalUnit']?.toString() ?? stockDtl['calUnit']?.toString() ?? 'Pcs';

        items.add(_HtmlInvoiceItem(
          sNo: i + 1,
          name: itemName,
          hsn: stockDtl['HSNCode']?.toString() ?? stockDtl['hsn']?.toString() ?? '',
          qty: qty,
          bags: bags,
          unit: unit,
          rate: rate,
          discount: disc,
          taxable: taxable,
          gstRate: (stockDtl['TaxRate'] as num?)?.toDouble() ?? (taxable > 0 ? ((totalGst / taxable) * 100) : 0.0),
          cgst: cgst,
          sgst: sgst,
          igst: igst,
          total: total,
        ));
      }
    } else {
      // Fallback single item from bill
      items.add(_HtmlInvoiceItem(
        sNo: 1,
        name: bill.vendorName.isNotEmpty ? 'Sale - ${bill.vendorName}' : 'General Sale Items',
        hsn: '',
        qty: 1,
        bags: 0,
        unit: 'Lumpsum',
        rate: bill.amount,
        discount: 0,
        taxable: bill.isGstBill ? (bill.amount - bill.gstAmount) : bill.amount,
        gstRate: (bill.isGstBill && bill.amount > bill.gstAmount) ? ((bill.gstAmount / (bill.amount - bill.gstAmount)) * 100) : 0,
        cgst: bill.isGstBill ? bill.gstAmount / 2 : 0,
        sgst: bill.isGstBill ? bill.gstAmount / 2 : 0,
        igst: 0,
        total: bill.amount,
      ));
    }

    // 6. Tax Totals
    double totalTaxable = 0.0;
    double totalCgst = ((invTran['TotalCGST'] ?? sihdr['TotalCGST'] ?? 0.0) as num).toDouble();
    double totalSgst = ((invTran['TotalSGST'] ?? sihdr['TotalSGST'] ?? 0.0) as num).toDouble();
    double totalIgst = ((invTran['TotalIGST'] ?? sihdr['TotalIGST'] ?? 0.0) as num).toDouble();
    double totalQty = 0;
    int totalBags = 0;

    for (final it in items) {
      totalTaxable += it.taxable;
      totalQty += it.qty;
      totalBags += it.bags;
      if (totalCgst == 0 && it.cgst > 0) totalCgst += it.cgst;
      if (totalSgst == 0 && it.sgst > 0) totalSgst += it.sgst;
      if (totalIgst == 0 && it.igst > 0) totalIgst += it.igst;
    }

    final double roundDiff = ((invTran['RndAmt'] ?? sihdr['RndAmt'] ?? 0.0) as num).toDouble();
    final double freightAmt = ((sihdr['FreightAmt'] ?? sihdr['FrieghtAmt'] ?? 0.0) as num).toDouble();
    final double grandTotal = netAmount.toDouble();
    final String grandTotalInWords = numberToWords(grandTotal);

    // 7. Render Item Rows HTML
    final itemRowsHtml = items.map((it) {
      return '''
        <tr>
          <td class="text-center">${it.sNo}</td>
          <td>
            <strong>${_escapeHtml(it.name)}</strong>
            ${it.hsn.isNotEmpty ? '<br><small class="text-muted">HSN: ${_escapeHtml(it.hsn)}</small>' : ''}
          </td>
          <td class="text-center">${it.bags > 0 ? '${it.bags} Bgs / ' : ''}${it.qty.toStringAsFixed(it.qty.truncateToDouble() == it.qty ? 0 : 2)} ${it.unit}</td>
          <td class="text-right">₹${it.rate.toStringAsFixed(2)}</td>
          <td class="text-right">${it.discount > 0 ? '₹${it.discount.toStringAsFixed(2)}' : '-'}</td>
          <td class="text-right">₹${it.taxable.toStringAsFixed(2)}</td>
          <td class="text-center">${it.gstRate > 0 ? '${it.gstRate.toStringAsFixed(1)}%' : '0%'}</td>
          <td class="text-right"><strong>₹${it.total.toStringAsFixed(2)}</strong></td>
        </tr>
      ''';
    }).join('\n');

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Tax Invoice - $invoiceNumber</title>
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
      font-size: 13px;
      color: #1e293b;
      background: #f8fafc;
      padding: 24px;
    }
    .invoice-card {
      max-width: 820px;
      margin: 0 auto;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.04);
      padding: 32px;
    }
    /* Header */
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
    .invoice-badge-box {
      text-align: right;
    }
    .invoice-badge-box h2 {
      font-size: 20px;
      font-weight: 800;
      color: #2563eb;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 6px;
    }
    .invoice-badge-box .inv-meta {
      font-size: 12px;
      color: #64748b;
      line-height: 1.6;
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      font-size: 10px;
      font-weight: 700;
      border-radius: 4px;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      margin-top: 4px;
    }
    .badge-paid {
      background: #dcfce7;
      color: #15803d;
      border: 1px solid #86efac;
    }
    .badge-partial {
      background: #fef3c7;
      color: #b45309;
      border: 1px solid #fde68a;
    }
    .badge-due {
      background: #fee2e2;
      color: #b91c1c;
      border: 1px solid #fca5a5;
    }

    /* Meta Columns */
    .bill-details-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 20px;
      background: #f8fafc;
      padding: 16px;
      border-radius: 8px;
      border: 1px solid #e2e8f0;
      margin-bottom: 24px;
    }
    .section-title {
      font-size: 11px;
      font-weight: 700;
      color: #94a3b8;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin-bottom: 6px;
    }
    .party-name {
      font-size: 15px;
      font-weight: 700;
      color: #0f172a;
      margin-bottom: 4px;
    }
    .detail-item {
      font-size: 12px;
      color: #475569;
      line-height: 1.5;
    }

    /* Table */
    table.items-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
    }
    table.items-table th {
      background: #f1f5f9;
      color: #334155;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      padding: 10px 12px;
      border-top: 1px solid #cbd5e1;
      border-bottom: 2px solid #cbd5e1;
    }
    table.items-table td {
      padding: 10px 12px;
      border-bottom: 1px solid #e2e8f0;
      font-size: 12px;
      vertical-align: middle;
    }
    table.items-table tr:nth-child(even) td {
      background: #fafafa;
    }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .text-muted { color: #64748b; }

    /* Summary Layout */
    .summary-grid {
      display: grid;
      grid-template-columns: 1.2fr 0.8fr;
      gap: 24px;
      margin-top: 12px;
      align-items: start;
    }
    .words-box {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 14px;
      font-size: 12px;
      line-height: 1.6;
    }
    .words-box strong {
      color: #1e3a8a;
    }
    .terms-box {
      margin-top: 14px;
      font-size: 11px;
      color: #64748b;
      line-height: 1.5;
    }
    .terms-box ol {
      padding-left: 16px;
      margin-top: 4px;
    }

    /* Calculation Table */
    .calc-table {
      width: 100%;
      border-collapse: collapse;
    }
    .calc-table td {
      padding: 6px 8px;
      font-size: 12px;
    }
    .calc-table tr.total-row td {
      border-top: 2px solid #2563eb;
      border-bottom: 2px solid #2563eb;
      font-size: 15px;
      font-weight: 800;
      color: #1e3a8a;
      background: #eff6ff;
      padding: 10px 8px;
    }

    /* Signatory */
    .sign-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #e2e8f0;
    }
    .sign-box {
      text-align: right;
    }
    .sign-line {
      width: 180px;
      border-bottom: 1px dashed #94a3b8;
      margin-bottom: 6px;
      display: inline-block;
    }
    .footer-note {
      font-size: 10px;
      color: #94a3b8;
      text-align: center;
      margin-top: 24px;
    }

    /* Print styles */
    @media print {
      body {
        background: #ffffff;
        padding: 0;
      }
      .invoice-card {
        border: none;
        box-shadow: none;
        padding: 0;
        max-width: 100%;
      }
      .no-print {
        display: none !important;
      }
      @page {
        size: A4 portrait;
        margin: 10mm;
      }
    }
  </style>
</head>
<body>
  <div class="invoice-card">
    <!-- Header -->
    <div class="header-row">
      <div class="shop-info">
        <h1>${_escapeHtml(shopName)}</h1>
        ${shopOwner.isNotEmpty ? '<p>Proprietor: ' + _escapeHtml(shopOwner) + '</p>' : ''}
        ${shopCity.isNotEmpty ? '<p>Location: ' + _escapeHtml(shopCity) + '</p>' : ''}
        ${shopPhone.isNotEmpty ? '<p>Phone: +91 ' + _escapeHtml(shopPhone) + '</p>' : ''}
        ${shopGst.isNotEmpty ? '<p><strong>GSTIN: ' + _escapeHtml(shopGst) + '</strong></p>' : ''}
      </div>
      <div class="invoice-badge-box">
        <h2>TAX INVOICE</h2>
        <div class="inv-meta">
          <strong>Invoice No:</strong> ${_escapeHtml(invoiceNumber)}<br>
          <strong>Date:</strong> $invoiceDate<br>
          <strong>Time:</strong> $invoiceTime<br>
          <strong>Payment Mode:</strong> $paymentModeDisplay<br>
          $paymentStatusBadge
        </div>
      </div>
    </div>

    <!-- Customer & Meta Section -->
    <div class="bill-details-grid">
      <div>
        <div class="section-title">Bill To (Buyer)</div>
        <div class="party-name">${_escapeHtml(buyerName)}</div>
        ${buyerGst.isNotEmpty ? '<div class="detail-item"><strong>GSTIN:</strong> ' + _escapeHtml(buyerGst) + '</div>' : ''}
        ${buyerState.isNotEmpty ? '<div class="detail-item"><strong>Place of Supply:</strong> ' + _escapeHtml(buyerState) + '</div>' : ''}
      </div>
      <div>
        <div class="section-title">Invoice Details</div>
        <div class="detail-item"><strong>Invoice Type:</strong> Regular GST Sale</div>
        <div class="detail-item"><strong>Billed By:</strong> ${_escapeHtml(creatorName?.isNotEmpty == true ? creatorName! : (shopOwner.isNotEmpty ? shopOwner : 'Store'))}</div>
        ${totalBags > 0 ? '<div class="detail-item"><strong>Total Bags:</strong> ' + totalBags.toString() + '</div>' : ''}
      </div>
    </div>

    <!-- Items Table -->
    <table class="items-table">
      <thead>
        <tr>
          <th style="width: 40px;" class="text-center">#</th>
          <th>Item Description</th>
          <th style="width: 100px;" class="text-center">Qty / Unit</th>
          <th style="width: 80px;" class="text-right">Rate</th>
          <th style="width: 70px;" class="text-right">Disc</th>
          <th style="width: 85px;" class="text-right">Taxable</th>
          <th style="width: 60px;" class="text-center">GST %</th>
          <th style="width: 95px;" class="text-right">Amount</th>
        </tr>
      </thead>
      <tbody>
        $itemRowsHtml
      </tbody>
    </table>

    <!-- Summary & Totals -->
    <div class="summary-grid">
      <div>
        <div class="words-box">
          <div><strong>Amount in Words:</strong></div>
          <div style="font-style: italic; color: #334155; margin-top: 2px;">$grandTotalInWords</div>
        </div>

        <div class="terms-box">
          <strong>Terms & Conditions:</strong>
          <ol>
            <li>Goods once sold will not be accepted back or exchanged without this original bill.</li>
            <li>All disputes are subject to local jurisdiction only.</li>
            <li>Payment is due according to agreed credit terms.</li>
          </ol>
        </div>
      </div>

      <div>
        <table class="calc-table">
          <tr>
            <td>Taxable Subtotal:</td>
            <td class="text-right">₹${totalTaxable.toStringAsFixed(2)}</td>
          </tr>
          ${totalCgst > 0 ? '<tr><td>CGST:</td><td class="text-right">₹' + totalCgst.toStringAsFixed(2) + '</td></tr>' : ''}
          ${totalSgst > 0 ? '<tr><td>SGST:</td><td class="text-right">₹' + totalSgst.toStringAsFixed(2) + '</td></tr>' : ''}
          ${totalIgst > 0 ? '<tr><td>IGST:</td><td class="text-right">₹' + totalIgst.toStringAsFixed(2) + '</td></tr>' : ''}
          ${freightAmt > 0 ? '<tr><td>Freight / Shipping:</td><td class="text-right">₹' + freightAmt.toStringAsFixed(2) + '</td></tr>' : ''}
          ${roundDiff != 0 ? '<tr><td>Round Off:</td><td class="text-right">' + (roundDiff > 0 ? '+' : '') + '₹' + roundDiff.toStringAsFixed(2) + '</td></tr>' : ''}
          <tr class="total-row">
            <td><strong>Grand Total:</strong></td>
            <td class="text-right"><strong>₹${grandTotal.toStringAsFixed(2)}</strong></td>
          </tr>
          ${totalAdvance > 0 ? '<tr><td style="color:#16a34a;">Amount Received:</td><td class="text-right" style="color:#16a34a; font-weight:600;">₹' + totalAdvance.toStringAsFixed(2) + '</td></tr>' : ''}
          ${balanceDue > 0 ? '<tr><td style="color:#dc2626;">Balance Due:</td><td class="text-right" style="color:#dc2626; font-weight:700;">₹' + balanceDue.toStringAsFixed(2) + '</td></tr>' : ''}
        </table>
      </div>
    </div>

    <!-- Signatory Row -->
    <div class="sign-row">
      <div style="font-size: 11px; color: #64748b;">
        Thank you for doing business with us!
      </div>
      <div class="sign-box">
        <div class="sign-line"></div>
        <div style="font-size: 11px; font-weight: 700; color: #1e293b;">For ${_escapeHtml(shopName)}</div>
        <div style="font-size: 10px; color: #64748b;">Authorized Signatory</div>
      </div>
    </div>

    <!-- Footer Note -->
    <div class="footer-note">
      This is a Computer Generated Invoice • Generated via SaafHisaab
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

class _HtmlInvoiceItem {
  final int sNo;
  final String name;
  final String hsn;
  final double qty;
  final int bags;
  final String unit;
  final double rate;
  final double discount;
  final double taxable;
  final double gstRate;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  _HtmlInvoiceItem({
    required this.sNo,
    required this.name,
    required this.hsn,
    required this.qty,
    required this.bags,
    required this.unit,
    required this.rate,
    required this.discount,
    required this.taxable,
    required this.gstRate,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
  });
}
