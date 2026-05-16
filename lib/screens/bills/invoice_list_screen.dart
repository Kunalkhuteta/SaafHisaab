import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../models/bill_model.dart';
import '../../globalVar.dart';
import '../../services/ai_ocr_service.dart';
import 'bill_review_screen.dart';
import '../sales/sale_entry_screen.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  final String billType;
  final String title;
  final String titleHi;

  const InvoiceListScreen({
    super.key,
    required this.billType,
    required this.title,
    required this.titleHi,
  });

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final dateFilter = ref.watch(billsDateFilterProvider);
    final billsAsync = ref.watch(filteredBillsProvider(widget.billType));
    final typeColor = InvType.color(widget.billType);
    final code = InvType.shortCode(widget.billType);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(children: [
          Text(AppLang.tr(isEn, widget.title, widget.titleHi),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(code, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
          ),
        ]),
        backgroundColor: typeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntryForm(context),
        backgroundColor: typeColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(AppLang.tr(isEn, 'Add $code', '$code जोड़ें'),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        // Header filters
        Container(
          color: typeColor,
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _headerBtn(Icons.document_scanner_rounded,
                AppLang.tr(isEn, 'Scan', 'स्कैन'),
                () { if (!_isProcessing) _showImageSourceDialog(context, isEn); }),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _filterChip(AppLang.tr(isEn, 'Today', 'आज'), 'today', dateFilter),
              const SizedBox(width: 8),
              _filterChip(AppLang.tr(isEn, 'Week', 'सप्ताह'), 'week', dateFilter),
              const SizedBox(width: 8),
              _filterChip(AppLang.tr(isEn, 'Month', 'महीना'), 'month', dateFilter),
            ]),
          ]),
        ),

        if (_isProcessing)
          Container(
            color: AppColors.primaryBg,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
              const SizedBox(width: 10),
              Text(AppLang.tr(isEn, 'Processing bill...', 'बिल प्रोसेस हो रहा है...'),
                style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
            ]),
          ),

        // Bill List
        Expanded(
          child: billsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (bills) => bills.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(InvType.icon(widget.billType), color: AppColors.textHint, size: 48),
                  const SizedBox(height: 12),
                  Text(AppLang.tr(isEn, 'No $code records found', 'कोई $code रिकॉर्ड नहीं मिला'),
                    style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                ]))
              : RefreshIndicator(
                  color: typeColor,
                  onRefresh: () async {
                    ref.invalidate(filteredBillsProvider);
                    ref.invalidate(dashboardStatsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bills.length,
                    itemBuilder: (_, i) => _billCard(bills[i], isEn, typeColor),
                  ),
                ),
          ),
        ),
      ]),
    );
  }

  void _openEntryForm(BuildContext context) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => SaleEntryScreen(billType: widget.billType),
    ));
    if (result == true) {
      ref.invalidate(filteredBillsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(stockItemsProvider);
    }
  }

  void _openEditForm(BillModel bill) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => SaleEntryScreen(billType: bill.billType, bill: bill),
    ));
    if (result == true) {
      ref.invalidate(filteredBillsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(stockItemsProvider);
    }
  }

  Widget _headerBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, String value, String current) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => ref.read(billsDateFilterProvider.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: sel ? InvType.color(widget.billType) : Colors.white)),
      ),
    );
  }

  // ── Image Source Dialog ──
  void _showImageSourceDialog(BuildContext context, bool isEn) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(AppLang.tr(isEn, 'Scan Document', 'दस्तावेज़ स्कैन करें'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _sourceOption(icon: Icons.camera_alt_rounded,
              label: AppLang.tr(isEn, 'Camera', 'कैमरा'), color: AppColors.primary,
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera, isEn); })),
            const SizedBox(width: 12),
            Expanded(child: _sourceOption(icon: Icons.photo_library_rounded,
              label: AppLang.tr(isEn, 'Gallery', 'गैलरी'), color: AppColors.purple,
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery, isEn); })),
          ]),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
        ]),
      ),
    );
  }

  Widget _sourceOption({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, bool isEn) async {
    try {
      final XFile? xfile = await _picker.pickImage(source: source, imageQuality: 85);
      if (xfile == null) return;
      setState(() => _isProcessing = true);
      final bytes = await xfile.readAsBytes();
      Map<String, dynamic> ocrData = {
        'raw_text': '', 'amount': 0.0, 'vendor_name': '',
        'bill_date': DateTime.now().toIso8601String().split('T')[0],
        'is_gst_bill': false, 'gst_amount': 0.0,
      };
      try { ocrData = await AiOcrService.extractBillData(bytes); } catch (e) { debugPrint('OCR failed: $e'); }
      setState(() => _isProcessing = false);

      if (ocrData.containsKey('error') && (ocrData['error'] as String).isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('AI OCR Error: ${ocrData['error']}', maxLines: 3),
            backgroundColor: AppColors.error, duration: const Duration(seconds: 4),
          ));
        }
      }

      if (mounted) {
        final saved = await Navigator.push<bool>(context, MaterialPageRoute(
          builder: (_) => BillReviewScreen(imageBytes: bytes, ocrData: ocrData, lockedBillType: widget.billType)));
        if (saved == true) {
          ref.invalidate(filteredBillsProvider);
          ref.invalidate(todayBillsProvider);
          ref.invalidate(dashboardStatsProvider);
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  Widget _billCard(BillModel bill, bool isEn, Color typeColor) {
    final code = InvType.shortCode(bill.billType);
    return GestureDetector(
      onTap: () => _openEditForm(bill),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(InvType.icon(bill.billType), color: typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              bill.vendorName.isEmpty
                ? AppLang.tr(isEn, widget.title, widget.titleHi)
                : bill.vendorName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(code, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: typeColor)),
              ),
              const SizedBox(width: 6),
              Text('${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ]),
          ])),
          Text('₹${bill.amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: typeColor)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
        ]),
      ),
    );
  }
}
