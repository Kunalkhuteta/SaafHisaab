import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../models/bill_model.dart';
import '../../models/stock_model.dart';
import '../../globalVar.dart';
import 'bill_review_screen.dart';
import '../sales/sale_entry_screen.dart';

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
    final dateFilter = ref.watch(billsDateFilterProvider);
    final billsAsync = ref.watch(filteredBillsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const SaleEntryScreen()),
          );
          if (result == true) {
            ref.invalidate(filteredBillsProvider);
            ref.invalidate(todayBillsProvider);
            ref.invalidate(dashboardStatsProvider);
          }
        },
        backgroundColor: AppColors.success,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: Text(
          AppLang.tr(isEn, 'New Sale', 'नई बिक्री'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ── Header ──
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                bottom: 12),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Text(
                    AppLang.tr(isEn, 'Bills & Sales', 'बिल और बिक्री'),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                // Scan
                _headerBtn(Icons.document_scanner_rounded,
                    AppLang.tr(isEn, 'Scan', 'स्कैन'), () {
                  if (!_isProcessing) _showImageSourceDialog(context, isEn);
                }),
                const SizedBox(width: 8),
                // Add Bill
                _headerBtn(Icons.add_rounded, AppLang.tr(isEn, 'Bill', 'बिल'),
                    () => _showAddBillDialog(context, isEn)),
              ]),
              const SizedBox(height: 12),
              // ── Date Filter Chips ──
              Row(children: [
                _filterChip(AppLang.tr(isEn, 'Today', 'आज'), 'today', dateFilter),
                const SizedBox(width: 8),
                _filterChip(AppLang.tr(isEn, 'Week', 'सप्ताह'), 'week', dateFilter),
                const SizedBox(width: 8),
                _filterChip(AppLang.tr(isEn, 'Month', 'महीना'), 'month', dateFilter),
              ]),
            ]),
          ),

        // Processing indicator
        if (_isProcessing)
          Container(
            color: AppColors.primaryBg,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
              const SizedBox(width: 10),
              Text(AppLang.tr(isEn, 'Processing bill...', 'बिल प्रोसेस हो रहा है...'),
                  style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
            ]),
          ),

        // ── Bill List ──
        Expanded(
          child: billsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (bills) => bills.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.receipt_long_outlined, color: AppColors.textHint, size: 48),
                    const SizedBox(height: 12),
                    Text(AppLang.tr(isEn, 'No bills found', 'कोई बिल नहीं मिला'), style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(AppLang.tr(isEn, 'Scan a bill, add manually, or create a sale', 'बिल स्कैन करें, मैन्युअल जोड़ें, या बिक्री बनाएं'),
                        style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                  ]))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(filteredBillsProvider);
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
      ),
    );
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
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? AppColors.primary : Colors.white)),
      ),
    );
  }

  // ── Image Source Dialog ──
  void _showImageSourceDialog(BuildContext context, bool isEn) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(AppLang.tr(isEn, 'Scan Bill', 'बिल स्कैन करें'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _sourceOption(icon: Icons.camera_alt_rounded, label: AppLang.tr(isEn, 'Camera', 'कैमरा'), color: AppColors.primary, onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera, isEn); })),
            const SizedBox(width: 12),
            Expanded(child: _sourceOption(icon: Icons.photo_library_rounded, label: AppLang.tr(isEn, 'Gallery', 'गैलरी'), color: AppColors.purple, onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery, isEn); })),
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
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
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
      Map<String, dynamic> ocrData = { 'raw_text': '', 'amount': 0.0, 'vendor_name': '', 'bill_date': DateTime.now().toIso8601String().split('T')[0], 'is_gst_bill': false, 'gst_amount': 0.0 };
      if (!kIsWeb) { try { ocrData = await OcrService.extractBillData(File(xfile.path)); } catch (e) { debugPrint('OCR failed: $e'); } }
      setState(() => _isProcessing = false);
      if (mounted) {
        final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => BillReviewScreen(imageBytes: bytes, ocrData: ocrData)));
        if (saved == true) { ref.invalidate(filteredBillsProvider); ref.invalidate(todayBillsProvider); ref.invalidate(dashboardStatsProvider); }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  Widget _billCard(BillModel bill, bool isEn) {
    final isSale = bill.billType == 'sale';
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: isSale ? AppColors.success.withOpacity(0.1) : AppColors.primaryBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(isSale ? Icons.trending_up_rounded : Icons.receipt_rounded, color: isSale ? AppColors.success : AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bill.vendorName.isEmpty ? AppLang.tr(isEn, isSale ? 'Sale' : 'Bill', isSale ? 'बिक्री' : 'बिल') : bill.vendorName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: isSale ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(isSale ? AppLang.tr(isEn, 'Sale', 'बिक्री') : AppLang.tr(isEn, 'Purchase', 'खरीद'),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSale ? AppColors.success : AppColors.primary)),
            ),
            const SizedBox(width: 6),
            Text('${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ]),
        ])),
        Text('₹${bill.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSale ? AppColors.success : AppColors.primary)),
      ]),
    );
  }

  // ── Manual Add Bill Dialog ──
  void _showAddBillDialog(BuildContext context, bool isEn) {
    final vendorCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String billType = 'purchase';
    StockItemModel? selectedStockItem;
    bool isSaving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(AppLang.tr(isEn, 'Add New Bill', 'नया बिल जोड़ें'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            Row(children: [
              _typeChip(AppLang.tr(isEn, 'Purchase', 'खरीद'), billType == 'purchase', () => setDialogState(() => billType = 'purchase')),
              const SizedBox(width: 10),
              _typeChip(AppLang.tr(isEn, 'Sale', 'बिक्री'), billType == 'sale', () => setDialogState(() => billType = 'sale')),
            ]),
            
            const SizedBox(height: 16),
            
            if (billType == 'sale') ...[
              // Stock Item selection for manual bill
              ref.watch(stockItemsProvider).when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (stockItems) => Column(
                  children: [
                    DropdownButtonFormField<StockItemModel>(
                      value: selectedStockItem,
                      decoration: _inputDeco(AppLang.tr(isEn, 'Choose Stock Item', 'स्टॉक आइटम चुनें')),
                      items: stockItems.cast<StockItemModel>().map((StockItemModel item) => DropdownMenuItem<StockItemModel>(
                        value: item,
                        child: Text('${item.itemName} (${item.currentQuantity.toStringAsFixed(0)} ${item.unit})'),
                      )).toList(),
                      onChanged: (StockItemModel? item) {
                        setDialogState(() {
                          selectedStockItem = item;
                          if (item != null) {
                            amountCtrl.text = (item.sellingPrice * (double.tryParse(qtyCtrl.text) ?? 1)).toStringAsFixed(0);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco(AppLang.tr(isEn, 'Quantity to deduct', 'कटौती मात्रा')),
                      onChanged: (v) {
                        if (selectedStockItem != null) {
                          final q = double.tryParse(v) ?? 1;
                          amountCtrl.text = (selectedStockItem!.sellingPrice * q).toStringAsFixed(0);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(controller: vendorCtrl, decoration: _inputDeco(AppLang.tr(isEn, 'Vendor / Party name', 'वेंडर / पार्टी का नाम'))),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco(AppLang.tr(isEn, 'Amount (₹) *', 'राशि (₹) *'))),
            const SizedBox(height: 24),
            
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              onPressed: isSaving ? null : () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amt <= 0) return;
                
                setDialogState(() => isSaving = true);
                try {
                  final userId = AuthService.currentUserId;
                  final shop = await ref.read(shopProvider.future);
                  if (userId == null || shop == null) throw Exception('Not found');

                  // 1. Save Bill
                  await SupabaseService.saveBill(BillModel(
                    id: '', shopId: shop.id, userId: userId, 
                    amount: amt, billDate: DateTime.now(), 
                    vendorName: vendorCtrl.text.trim(), billType: billType, 
                    createdAt: DateTime.now()
                  ));

                  // 2. Deduct Stock if selected
                  if (billType == 'sale' && selectedStockItem != null) {
                    final qty = double.tryParse(qtyCtrl.text) ?? 1;
                    await SupabaseService.deductStockById(selectedStockItem!.id, qty);
                  }

                  ref.invalidate(filteredBillsProvider);
                  ref.invalidate(todayBillsProvider);
                  ref.invalidate(dashboardStatsProvider);
                  ref.invalidate(stockItemsProvider);
                  
                  if (ctx.mounted) { 
                    Navigator.pop(ctx); 
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(isEn, 'Bill saved and stock updated!', 'बिल सहेजा गया और स्टॉक अपडेट हुआ!')), backgroundColor: AppColors.success)); 
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: isSaving ? AppColors.textHint : AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(AppLang.tr(isEn, 'Save Bill', 'बिल सहेजें'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
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
        decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? AppColors.primary : AppColors.border)),
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
