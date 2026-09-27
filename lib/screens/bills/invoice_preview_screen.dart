import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../models/bill_model.dart';
import '../../services/invoice_pdf_service.dart';
import '../../providers/app_providers.dart';

class InvoicePreviewScreen extends ConsumerStatefulWidget {
  final BillModel bill;

  const InvoicePreviewScreen({
    super.key,
    required this.bill,
  });

  @override
  ConsumerState<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  bool _isLoading = true;
  String _htmlContent = '';
  String? _errorMessage;
  bool _showCodeView = false;

  @override
  void initState() {
    super.initState();
    _loadInvoiceHtml();
  }

  Future<void> _loadInvoiceHtml() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final html = await InvoicePdfService.loadAndBuildInvoiceHtml(
        ref: ref,
        bill: widget.bill,
      );
      if (mounted) {
        setState(() {
          _htmlContent = html;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String get _invoiceTitle => 'Invoice_${widget.bill.vendorName.replaceAll(' ', '_')}_${widget.bill.billDate.day}_${widget.bill.billDate.month}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Sale Invoice PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading && _htmlContent.isNotEmpty) ...[
            IconButton(
              icon: Icon(_showCodeView ? Icons.visibility_rounded : Icons.code_rounded),
              tooltip: _showCodeView ? 'View Preview' : 'View HTML/CSS Code',
              onPressed: () => setState(() => _showCodeView = !_showCodeView),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: 'Open in Browser Tab',
              onPressed: () => InvoicePdfService.openHtmlInBrowser(
                htmlContent: _htmlContent,
                invoiceTitle: _invoiceTitle,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share Invoice',
              onPressed: () => InvoicePdfService.shareInvoice(
                htmlContent: _htmlContent,
                filename: _invoiceTitle,
                invoiceTitle: 'Tax Invoice - ${widget.bill.vendorName}',
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _isLoading || _htmlContent.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => InvoicePdfService.openHtmlInBrowser(
                        htmlContent: _htmlContent,
                        invoiceTitle: _invoiceTitle,
                      ),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                      label: const Text('Open in Browser', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1,
                      ),
                      onPressed: () => InvoicePdfService.printOrSavePdf(
                        htmlContent: _htmlContent,
                        invoiceTitle: _invoiceTitle,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                      label: const Text('Print / Save PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Building dynamic HTML & PDF invoice...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text('Failed to build invoice: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInvoiceHtml,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _showCodeView
                  ? _buildHtmlCodeViewer()
                  : _buildVisualPreview(),
    );
  }

  Widget _buildHtmlCodeViewer() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Generated HTML / CSS Template', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _htmlContent));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('HTML code copied to clipboard!'), duration: Duration(seconds: 2)),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white70),
                label: const Text('Copy HTML', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _htmlContent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF38BDF8),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Live HTML template filled with dynamic data. Click "Print / Save PDF" to generate the PDF file or print.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => InvoicePdfService.openHtmlInBrowser(
                        htmlContent: _htmlContent,
                        invoiceTitle: _invoiceTitle,
                      ),
                      child: const Text('Browser View', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),

              // Visual representation of the invoice
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final shop = ref.watch(shopProvider).valueOrNull;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shop?.shopName ?? 'SaafHisaab Store',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                ),
                                if (shop?.ownerName.isNotEmpty == true)
                                  Text('Proprietor: ${shop!.ownerName}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                if (shop?.city.isNotEmpty == true)
                                  Text('Location: ${shop!.city}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                if (shop?.phone.isNotEmpty == true)
                                  Text('Phone: +91 ${shop!.phone}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                if (shop?.gstNumber.isNotEmpty == true)
                                  Text('GSTIN: ${shop!.gstNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                        child: const Text('TAX INVOICE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                      ),
                      const SizedBox(height: 6),
                      Text('Bill Date: ${widget.bill.billDate.day}/${widget.bill.billDate.month}/${widget.bill.billDate.year}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      Text('Amount: ₹${widget.bill.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                    ],
                  ),
                ],
              ),

              const Divider(height: 32, thickness: 1.5, color: Color(0xFFE2E8F0)),

              // Buyer details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BILL TO (CUSTOMER)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45)),
                          const SizedBox(height: 2),
                          Text(widget.bill.vendorName.isEmpty ? 'Walk-in Customer' : widget.bill.vendorName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('BILL TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45)),
                        const SizedBox(height: 2),
                        Text(widget.bill.isGstBill ? 'GST Sale Invoice' : 'Non-GST Invoice',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Total box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invoice Amount', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        if (widget.bill.isGstBill)
                          Text('Includes GST: ₹${widget.bill.gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                    Text(
                      '₹${widget.bill.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Quick Actions in-body
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => InvoicePdfService.printOrSavePdf(
                        htmlContent: _htmlContent,
                        invoiceTitle: _invoiceTitle,
                      ),
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Generate / Print PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _showCodeView = true),
                    icon: const Icon(Icons.code_rounded),
                    label: const Text('HTML Code'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
