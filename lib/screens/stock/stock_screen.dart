import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../models/stock_model.dart';
import '../../globalVar.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});
  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final stockAsync = ref.watch(stockItemsProvider);

    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(AppLang.tr(isEn, 'Stock Items', 'स्टॉक आइटम'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              GestureDetector(
                onTap: () => _showAddStockDialog(context, isEn),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text(AppLang.tr(isEn, 'Add', 'जोड़ें'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: stockAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) => items.isEmpty
                ? _emptyState(isEn)
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(stockItemsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _stockCard(items[i], isEn),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(bool isEn) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 16),
          Text(AppLang.tr(isEn, 'No stock items', 'कोई स्टॉक आइटम नहीं'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(AppLang.tr(isEn, 'Click + Add to insert items', '+ Add बटन से आइटम जोड़ें'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _stockCard(StockItemModel item, bool isEn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: item.isLowStock ? AppColors.error.withOpacity(0.3) : AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: item.isLowStock ? AppColors.error.withOpacity(0.1) : AppColors.primaryBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(item.isLowStock ? Icons.warning_rounded : Icons.inventory_2_rounded, color: item.isLowStock ? AppColors.error : AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('${item.currentQuantity.toStringAsFixed(0)} ${item.unit} • ₹${item.sellingPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (item.isLowStock)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(AppLang.tr(isEn, 'Low', 'कम'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.error)),
            ),
        ],
      ),
    );
  }

  void _showAddStockDialog(BuildContext context, bool isEn) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    String unit = 'piece';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(AppLang.tr(isEn, 'Add New Item', 'नया आइटम जोड़ें'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              _dialogField(AppLang.tr(isEn, 'Item Name *', 'आइटम का नाम *'), nameCtrl),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _dialogField(AppLang.tr(isEn, 'Quantity *', 'मात्रा *'), qtyCtrl, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (_, setDialogState) => DropdownButtonFormField<String>(
                        value: unit,
                        decoration: InputDecoration(
                          labelText: AppLang.tr(isEn, 'Unit', 'इकाई'), filled: true, fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        items: ['piece', 'kg', 'litre', 'meter', 'box', 'dozen'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setDialogState(() => unit = v!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _dialogField(AppLang.tr(isEn, 'Buying Price', 'खरीद मूल्य'), buyCtrl, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _dialogField(AppLang.tr(isEn, 'Selling Price', 'बिक्री मूल्य'), sellCtrl, isNumber: true)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => _saveItem(ctx, isEn, nameCtrl.text, qtyCtrl.text, buyCtrl.text, sellCtrl.text, unit),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: Text(AppLang.tr(isEn, 'Save Item', 'आइटम सहेजें'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return TextField(
      controller: ctrl, keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, filled: true, fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Future<void> _saveItem(BuildContext ctx, bool isEn, String name, String qty, String buy, String sell, String unit) async {
    if (name.trim().isEmpty || qty.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(isEn, 'Name and quantity are required', 'नाम और मात्रा ज़रूरी है')), backgroundColor: AppColors.error));
      return;
    }
    try {
      final userId = AuthService.currentUserId;
      final shop = await ref.read(shopProvider.future);
      if (userId == null || shop == null) throw Exception('User or shop not found');
      await SupabaseService.saveStockItem(StockItemModel(
        id: '', shopId: shop.id, userId: userId, itemName: name.trim(),
        currentQuantity: double.tryParse(qty) ?? 0, unit: unit,
        buyingPrice: double.tryParse(buy) ?? 0, sellingPrice: double.tryParse(sell) ?? 0,
        createdAt: DateTime.now(),
      ));
      ref.invalidate(stockItemsProvider);
      ref.invalidate(dashboardStatsProvider);
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLang.tr(isEn, 'Item saved successfully!', 'आइटम सफलतापूर्वक सहेजा गया!')),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error));
    }
  }
}
