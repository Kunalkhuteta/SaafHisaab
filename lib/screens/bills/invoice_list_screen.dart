import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../models/bill_model.dart';
import '../../models/stock_model.dart';
import '../../globalVar.dart';
import '../../services/ai_ocr_service.dart';
import 'bill_review_screen.dart';
import '../sales/sale_entry_screen.dart';
import '../sales/sale_detail_screen.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  final String billType; // 'sale', 'purchase', 'sale_return', 'purchase_return'
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, widget.title, widget.titleHi), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Header Actions & Filters ──
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                // Scan
                _headerBtn(Icons.document_scanner_rounded,
                    AppLang.tr(isEn, 'Scan', 'स्कैन'), () {
                  if (!_isProcessing) _showImageSourceDialog(context, isEn);
                }),
                const SizedBox(width: 8),
                // Add Bill
                _headerBtn(Icons.add_rounded, AppLang.tr(isEn, 'Add', 'जोड़ें'),
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
                    Text(AppLang.tr(isEn, 'No records found', 'कोई रिकॉर्ड नहीं मिला'), style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
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
          Text(AppLang.tr(isEn, 'Scan Document', 'दस्तावेज़ स्कैन करें'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
      try { ocrData = await AiOcrService.extractBillData(bytes); } catch (e) { debugPrint('OCR failed: $e'); }
      setState(() => _isProcessing = false);

      if (ocrData.containsKey('error') && (ocrData['error'] as String).isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('AI OCR Error: ${ocrData['error']}\nPlease ensure your API Key is correct and app is fully restarted.', maxLines: 3),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ));
        }
      }

      if (mounted) {
        final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => BillReviewScreen(imageBytes: bytes, ocrData: ocrData, lockedBillType: widget.billType)));
        if (saved == true) { 
          ref.invalidate(filteredBillsProvider); 
          ref.invalidate(todayBillsProvider); 
          ref.invalidate(dashboardStatsProvider); 
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  Widget _billCard(BillModel bill, bool isEn) {
    // If it's a sale, maybe we can open SaleDetailScreen, but for others, maybe we need a generic detail screen or we can just let SaleDetailScreen handle it if it supports it.
    // We will just open SaleDetailScreen for all of them for now, or just show a bottom sheet if SaleDetailScreen isn't suitable.
    return GestureDetector(
      onTap: () async {
        // We can just push SaleDetailScreen which currently handles viewing bill details nicely.
        // If it's a 'sale' type we might want to edit it via SaleEntryScreen, but only 'sale' has SaleEntryScreen.
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => bill.billType == 'sale'
                ? SaleEntryScreen(bill: bill)
                : SaleDetailScreen(bill: bill),
          ),
        );
        if (result == true) {
          ref.invalidate(filteredBillsProvider);
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(stockItemsProvider);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bill.vendorName.isEmpty ? AppLang.tr(isEn, widget.title, widget.titleHi) : bill.vendorName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Row(children: [
              Text('${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ]),
          ])),
          Text('₹${bill.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
        ]),
      ),
    );
  }

  // ── Manual Add Dialog ──
  void _showAddBillDialog(BuildContext context, bool isEn) {
    final vendorCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final newItemNameCtrl = TextEditingController();
    final newItemSellingPriceCtrl = TextEditingController();
    
    StockItemModel? selectedStockItem;
    bool isNewItem = false;
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
            Text(AppLang.tr(isEn, 'Add ${widget.title}', '${widget.titleHi} जोड़ें'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            
            // Stock Update Logic based on bill type
            if (widget.billType == 'sale' || widget.billType == 'purchase_return') ...[
              // Deduct Stock
              Text(AppLang.tr(isEn, 'Deduct from Stock (Optional)', 'स्टॉक से कटौती (वैकल्पिक)'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ref.watch(stockItemsProvider).when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (stockItems) => DropdownButtonFormField<StockItemModel>(
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
              const SizedBox(height: 12),
            ] else if (widget.billType == 'purchase' || widget.billType == 'sale_return') ...[
              // Add to Stock
              Text(AppLang.tr(isEn, 'Add to Stock (Optional)', 'स्टॉक में जोड़ें (वैकल्पिक)'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: RadioListTile<bool>(
                  title: Text(AppLang.tr(isEn, 'Existing Item', 'मौजूदा आइटम'), style: const TextStyle(fontSize: 13)),
                  value: false, groupValue: isNewItem,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => isNewItem = v!),
                )),
                Expanded(child: RadioListTile<bool>(
                  title: Text(AppLang.tr(isEn, 'New Item', 'नया आइटम'), style: const TextStyle(fontSize: 13)),
                  value: true, groupValue: isNewItem,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => isNewItem = v!),
                )),
              ]),
              if (!isNewItem) ...[
                ref.watch(stockItemsProvider).when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (stockItems) => DropdownButtonFormField<StockItemModel>(
                    value: selectedStockItem,
                    decoration: _inputDeco(AppLang.tr(isEn, 'Choose Stock Item', 'स्टॉक आइटम चुनें')),
                    items: stockItems.cast<StockItemModel>().map((StockItemModel item) => DropdownMenuItem<StockItemModel>(
                      value: item,
                      child: Text('${item.itemName} (${item.currentQuantity.toStringAsFixed(0)} ${item.unit})'),
                    )).toList(),
                    onChanged: (StockItemModel? item) => setDialogState(() => selectedStockItem = item),
                  ),
                ),
              ] else ...[
                TextField(controller: newItemNameCtrl, decoration: _inputDeco(AppLang.tr(isEn, 'New Item Name', 'नए आइटम का नाम'))),
                const SizedBox(height: 12),
                TextField(controller: newItemSellingPriceCtrl, keyboardType: TextInputType.number, decoration: _inputDeco(AppLang.tr(isEn, 'Selling Price per unit', 'बिक्री मूल्य'))),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDeco(AppLang.tr(isEn, 'Quantity to add', 'मात्रा जोड़ें')),
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

                  // Stock logic
                  final qty = double.tryParse(qtyCtrl.text) ?? 1;

                  if (widget.billType == 'sale' || widget.billType == 'purchase_return') {
                    if (selectedStockItem != null) {
                      await SupabaseService.deductStockById(selectedStockItem!.id, qty);
                    }
                  } else if (widget.billType == 'purchase' || widget.billType == 'sale_return') {
                    if (isNewItem && newItemNameCtrl.text.isNotEmpty) {
                      // Create new stock item
                      final buyingPrice = qty > 0 ? (amt / qty) : 0.0;
                      final sellingPrice = double.tryParse(newItemSellingPriceCtrl.text) ?? buyingPrice;
                      
                      final newItem = StockItemModel(
                        id: '', shopId: shop.id, userId: userId, 
                        itemName: newItemNameCtrl.text.trim(),
                        currentQuantity: qty,
                        buyingPrice: buyingPrice, sellingPrice: sellingPrice,
                        createdAt: DateTime.now(),
                      );
                      await SupabaseService.saveStockItem(newItem);
                    } else if (!isNewItem && selectedStockItem != null) {
                      // Add to existing stock item
                      await SupabaseService.addStockById(selectedStockItem!.id, qty);
                    }
                  }

                  // Save Bill
                  await SupabaseService.saveBill(BillModel(
                    id: '', shopId: shop.id, userId: userId, 
                    amount: amt, billDate: DateTime.now(), 
                    vendorName: vendorCtrl.text.trim(), billType: widget.billType, 
                    createdAt: DateTime.now()
                  ));

                  ref.invalidate(filteredBillsProvider);
                  ref.invalidate(todayBillsProvider);
                  ref.invalidate(dashboardStatsProvider);
                  ref.invalidate(stockItemsProvider);
                  
                  if (ctx.mounted) { 
                    Navigator.pop(ctx); 
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(isEn, 'Saved successfully!', 'सफलतापूर्वक सहेजा गया!')), backgroundColor: AppColors.success)); 
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: isSaving ? AppColors.textHint : AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(AppLang.tr(isEn, 'Save', 'सहेजें'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            )),
          ])),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
