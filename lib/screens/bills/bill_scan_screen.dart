import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../models/bill_model.dart';
import '../../globalVar.dart';
import 'bill_review_screen.dart';

import 'dart:io';
import '../../services/ocr_service.dart';

class BillScanScreen extends ConsumerStatefulWidget {
  const BillScanScreen({super.key});
  @override
  ConsumerState<BillScanScreen> createState() => _BillScanScreenState();
}

class _BillScanScreenState extends ConsumerState<BillScanScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final billsAsync = ref.watch(todayBillsProvider);
    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(AppLang.tr(isEn, 'Bills', 'बिल'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              // Scan Bill button
              GestureDetector(
                onTap: _isProcessing ? null : () => _showImageSourceDialog(context, isEn),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(AppLang.tr(isEn, 'Scan', 'स्कैन'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              // Add Bill button
              GestureDetector(
                onTap: () => _showAddBillDialog(context, isEn),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(AppLang.tr(isEn, 'Add', 'जोड़ें'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        // Processing indicator
        if (_isProcessing)
          Container(
            color: AppColors.primaryBg,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(AppLang.tr(ref.read(appLanguageProvider), 'Processing bill...', 'बिल प्रोसेस हो रहा है...'),
                    style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        Expanded(
          child: billsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (bills) => bills.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.receipt_long_outlined, color: AppColors.textHint, size: 48),
                    const SizedBox(height: 12),
                    Text(AppLang.tr(isEn, 'No bills today', 'आज कोई बिल नहीं'), style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(AppLang.tr(isEn, 'Scan a bill or add manually', 'बिल स्कैन करें या मैन्युअल जोड़ें'), style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                  ]))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(todayBillsProvider);
                      ref.invalidate(dashboardStatsProvider);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bills.length,
                      itemBuilder: (_, i) => _billCard(bills[i], isEn),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Image Source Dialog ──
  void _showImageSourceDialog(BuildContext context, bool isEn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(AppLang.tr(isEn, 'Scan Bill', 'बिल स्कैन करें'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(AppLang.tr(isEn, 'Choose image source', 'इमेज सोर्स चुनें'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _sourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: AppLang.tr(isEn, 'Camera', 'कैमरा'),
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera, isEn);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sourceOption(
                    icon: Icons.photo_library_rounded,
                    label: AppLang.tr(isEn, 'Gallery', 'गैलरी'),
                    color: AppColors.purple,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery, isEn);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _sourceOption({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Pick Image & Process ──
  Future<void> _pickImage(ImageSource source, bool isEn) async {
    try {
      final XFile? xfile = await _picker.pickImage(source: source, imageQuality: 85);
      if (xfile == null) return;

      setState(() => _isProcessing = true);

      // Read image bytes for display
      final bytes = await xfile.readAsBytes();

      // Run OCR on mobile, skip on web
      Map<String, dynamic> ocrData = {
        'raw_text': '',
        'amount': 0.0,
        'vendor_name': '',
        'bill_date': DateTime.now().toIso8601String().split('T')[0],
        'is_gst_bill': false,
        'gst_amount': 0.0,
      };

      if (!kIsWeb) {
        try {
          ocrData = await OcrService.extractBillData(File(xfile.path));
        } catch (e) {
          debugPrint('OCR failed: $e');
          // Continue with empty data — user can fill manually
        }
      }

      setState(() => _isProcessing = false);

      if (mounted) {
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => BillReviewScreen(imageBytes: bytes, ocrData: ocrData),
          ),
        );
        if (saved == true) {
          ref.invalidate(todayBillsProvider);
          ref.invalidate(dashboardStatsProvider);
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLang.tr(isEn, 'Failed to pick image: $e', 'इमेज लेने में विफल: $e')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Existing Bill Card ──
  Widget _billCard(BillModel bill, bool isEn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(bill.billType == 'sale' ? Icons.trending_up_rounded : Icons.receipt_rounded, color: bill.billType == 'sale' ? AppColors.success : AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bill.vendorName.isEmpty ? AppLang.tr(isEn, 'Bill', 'बिल') : bill.vendorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('${bill.category} • ${bill.billType}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Text('₹${bill.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: bill.billType == 'sale' ? AppColors.success : AppColors.primary)),
      ]),
    );
  }

  // ── Manual Add Bill Dialog ──
  void _showAddBillDialog(BuildContext context, bool isEn) {
    final vendorCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String billType = 'purchase';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLang.tr(isEn, 'Add New Bill', 'नया बिल जोड़ें'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            Row(children: [
              _typeChip(AppLang.tr(isEn, 'Purchase', 'खरीद'), billType == 'purchase', () => setDialogState(() => billType = 'purchase')),
              const SizedBox(width: 10),
              _typeChip(AppLang.tr(isEn, 'Sale', 'बिक्री'), billType == 'sale', () => setDialogState(() => billType = 'sale')),
            ]),
            const SizedBox(height: 16),
            TextField(controller: vendorCtrl, decoration: _inputDeco(AppLang.tr(isEn, 'Vendor / Party name', 'वेंडर / पार्टी का नाम'))),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco(AppLang.tr(isEn, 'Amount (₹) *', 'राशि (₹) *'))),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              onPressed: () async {
                if (amountCtrl.text.trim().isEmpty) return;
                try {
                  final userId = AuthService.currentUserId;
                  final shop = await ref.read(shopProvider.future);
                  if (userId == null || shop == null) throw Exception('User or shop not found');
                  await SupabaseService.saveBill(BillModel(
                    id: '', shopId: shop.id, userId: userId,
                    amount: double.tryParse(amountCtrl.text) ?? 0,
                    billDate: DateTime.now(), vendorName: vendorCtrl.text.trim(),
                    billType: billType, createdAt: DateTime.now(),
                  ));
                  ref.invalidate(todayBillsProvider);
                  ref.invalidate(dashboardStatsProvider);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(AppLang.tr(isEn, 'Bill saved successfully!', 'बिल सफलतापूर्वक सहेजा गया!')),
                      backgroundColor: AppColors.success,
                    ));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Save failed: $e'),
                      backgroundColor: AppColors.error,
                    ));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: Text(AppLang.tr(isEn, 'Save Bill', 'बिल सहेजें'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            )),
          ])),
        ),
      ),
    );
  }

  Widget _typeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
