import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/shop_model.dart';
import '../../providers/app_providers.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/party_wise_sales_html_template.dart';
import '../bills/invoice_preview_screen.dart';

class PartySaleDetailScreen extends ConsumerStatefulWidget {
  final PartySaleSummary party;
  final String dateFilterLabel;
  final DateTime fromDate;
  final DateTime toDate;

  const PartySaleDetailScreen({
    super.key,
    required this.party,
    required this.dateFilterLabel,
    required this.fromDate,
    required this.toDate,
  });

  @override
  ConsumerState<PartySaleDetailScreen> createState() => _PartySaleDetailScreenState();
}

class _PartySaleDetailScreenState extends ConsumerState<PartySaleDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handlePdfAction(String action) async {
    final isEn = ref.read(appLanguageProvider);
    final shop = ref.read(shopProvider).valueOrNull;

    final html = PartyWiseSalesHtmlTemplate.generatePartyDetailReport(
      shop: shop,
      party: widget.party,
      filterPeriodLabel: widget.dateFilterLabel,
      fromDate: widget.fromDate,
      toDate: widget.toDate,
    );

    final title = 'Statement_${widget.party.partyName.replaceAll(' ', '_')}_${widget.dateFilterLabel.replaceAll(' ', '_')}';

    if (action == 'browser') {
      InvoicePdfService.openHtmlInBrowser(htmlContent: html, invoiceTitle: title);
      return;
    }

    if (action == 'print') {
      await InvoicePdfService.printOrSavePdf(htmlContent: html, invoiceTitle: title);
      return;
    }

    if (action == 'share') {
      await InvoicePdfService.shareInvoice(
        htmlContent: html,
        filename: title,
        invoiceTitle: 'Sales Statement - ${widget.party.partyName}',
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.party.partyName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('${widget.dateFilterLabel} • ${widget.party.invoiceCount} Bills',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: AppLang.tr(isEn, 'Print / Save Statement PDF', 'स्टेटमेंट PDF बनाएं / प्रिंट करें'),
            onPressed: () => _handlePdfAction('print'),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: AppLang.tr(isEn, 'Preview in Browser', 'ब्राउज़र में देखें'),
            onPressed: () => _handlePdfAction('browser'),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: AppLang.tr(isEn, 'Share Statement', 'शेयर करें'),
            onPressed: () => _handlePdfAction('share'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory_2_rounded, size: 18),
              text: AppLang.tr(isEn, 'Items Purchased (${widget.party.items.length})', 'खरीदे गए सामान (${widget.party.items.length})'),
            ),
            Tab(
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              text: AppLang.tr(isEn, 'Invoices (${widget.party.invoiceCount})', 'इनवॉइस बिल (${widget.party.invoiceCount})'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handlePdfAction('browser'),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: Text(AppLang.tr(isEn, 'Browser View', 'ब्राउज़र में देखें'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  onPressed: () => _handlePdfAction('print'),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(AppLang.tr(isEn, 'Statement PDF', 'स्टेटमेंट PDF'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Financial Summary Box
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLang.tr(isEn, 'Total Purchases', 'कुल बिक्री'),
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('₹${widget.party.totalSales.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${widget.party.invoiceCount} Bills',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF86EFAC), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${AppLang.tr(isEn, 'Received', 'प्राप्त')}: ₹${widget.party.totalPaid.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF86EFAC), fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFFCA5A5), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${AppLang.tr(isEn, 'Credit/Due', 'उधार/बाकी')}: ₹${widget.party.totalCredit.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Items Purchased
                _buildItemsList(isEn),

                // Tab 2: Invoices List
                _buildInvoicesList(isEn, dateFormat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(bool isEn) {
    if (widget.party.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(AppLang.tr(isEn, 'No item line-records found in this period', 'इस अवधि में कोई सामान रिकॉर्ड नहीं मिला'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.party.items.length,
      itemBuilder: (context, index) {
        final item = widget.party.items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.unit}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Text('•  Avg Rate: ₹${item.avgRate.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${item.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 2),
                  Text('${item.orderCount} order${item.orderCount > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoicesList(bool isEn, DateFormat dateFormat) {
    if (widget.party.bills.isEmpty) {
      return Center(
        child: Text(AppLang.tr(isEn, 'No bills found', 'कोई बिल नहीं मिला')),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.party.bills.length,
      itemBuilder: (context, index) {
        final bill = widget.party.bills[index];
        final invRef = bill.id.length >= 8 ? bill.id.substring(0, 8).toUpperCase() : bill.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_rounded, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice #$invRef',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(dateFormat.format(bill.billDate),
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: bill.isGstBill ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(bill.isGstBill ? 'GST' : 'Regular',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: bill.isGstBill ? AppColors.primary : Colors.black54,
                            )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${bill.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InvoicePreviewScreen(bill: bill)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(AppLang.tr(isEn, 'View Bill PDF', 'बिल PDF देखें'),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
