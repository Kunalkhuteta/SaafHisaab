import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../models/udhar_model.dart';
import '../../globalVar.dart';

class UdharScreen extends ConsumerStatefulWidget {
  const UdharScreen({super.key});
  @override
  ConsumerState<UdharScreen> createState() => _UdharScreenState();
}

class _UdharScreenState extends ConsumerState<UdharScreen> {
  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final udharAsync = ref.watch(udharCustomersProvider);
    
    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(AppLang.tr(isEn, 'Credit Account', 'उधार खाता'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              GestureDetector(
                onTap: () => _showAddCustomerDialog(context, isEn),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(AppLang.tr(isEn, 'Add', 'जोड़ें'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: udharAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (customers) => customers.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.people_outline_rounded, color: AppColors.textHint, size: 48),
                    const SizedBox(height: 12),
                    Text(AppLang.tr(isEn, 'No credit records', 'कोई उधार नहीं'), style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  ]))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(udharCustomersProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: customers.length,
                      itemBuilder: (_, i) => _customerCard(customers[i], isEn),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _customerCard(UdharCustomerModel customer, bool isEn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(
            customer.customerName.isNotEmpty ? customer.customerName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.warning),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customer.customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (customer.customerPhone.isNotEmpty)
            Text(customer.customerPhone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Text('₹${customer.totalDue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint, size: 20),
          onSelected: (val) async {
            if (val == 'paid') {
              await SupabaseService.markUdharPaid(customer.id);
              ref.invalidate(udharCustomersProvider);
              ref.invalidate(dashboardStatsProvider);
            }
          },
          itemBuilder: (_) => [PopupMenuItem(value: 'paid', child: Text(AppLang.tr(isEn, '✅ Mark as Paid', '✅ पूरा चुकाया')))],
        ),
      ]),
    );
  }

  void _showAddCustomerDialog(BuildContext context, bool isEn) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppLang.tr(isEn, 'New Credit Customer', 'नया उधार ग्राहक'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl, decoration: _inputDeco(AppLang.tr(isEn, 'Customer Name *', 'ग्राहक का नाम *'))),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: _inputDeco(AppLang.tr(isEn, 'Phone number', 'फ़ोन नंबर'))),
          const SizedBox(height: 12),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco(AppLang.tr(isEn, 'Credit amount (₹) *', 'उधार राशि (₹) *'))),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
              try {
                final userId = AuthService.currentUserId;
                final shop = await ref.read(shopProvider.future);
                if (userId == null || shop == null) throw Exception('User or shop not found');
                await SupabaseService.saveUdharCustomer(UdharCustomerModel(
                  id: '', shopId: shop.id, userId: userId,
                  customerName: nameCtrl.text.trim(), customerPhone: phoneCtrl.text.trim(),
                  totalDue: double.tryParse(amountCtrl.text) ?? 0, createdAt: DateTime.now(),
                ));
                ref.invalidate(udharCustomersProvider);
                ref.invalidate(dashboardStatsProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppLang.tr(isEn, 'Customer saved successfully!', 'ग्राहक सफलतापूर्वक सहेजा गया!')),
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
            child: Text(AppLang.tr(isEn, 'Save', 'सहेजें'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          )),
        ])),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
