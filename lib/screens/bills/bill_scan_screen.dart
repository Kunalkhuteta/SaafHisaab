import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../models/bill_model.dart';
import '../../globalVar.dart';

class BillScanScreen extends ConsumerStatefulWidget {
  const BillScanScreen({super.key});
  @override
  ConsumerState<BillScanScreen> createState() => _BillScanScreenState();
}

class _BillScanScreenState extends ConsumerState<BillScanScreen> {
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
              GestureDetector(
                onTap: () => _showAddBillDialog(context, isEn),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(AppLang.tr(isEn, 'Add Bill', 'बिल जोड़ें'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
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
                    Text(AppLang.tr(isEn, 'Click + Add Bill to insert', '+ Add Bill से नया बिल जोड़ें'), style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
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
                final userId = AuthService.currentUserId;
                final shop = await ref.read(shopProvider.future);
                if (userId == null || shop == null) return;
                await SupabaseService.saveBill(BillModel(
                  id: '', shopId: shop.id, userId: userId,
                  amount: double.tryParse(amountCtrl.text) ?? 0,
                  billDate: DateTime.now(), vendorName: vendorCtrl.text.trim(),
                  billType: billType, createdAt: DateTime.now(),
                ));
                ref.invalidate(todayBillsProvider);
                ref.invalidate(dashboardStatsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
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
