import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../models/udhar_model.dart';

class UdharScreen extends ConsumerStatefulWidget {
  const UdharScreen({super.key});
  @override
  ConsumerState<UdharScreen> createState() => _UdharScreenState();
}

class _UdharScreenState extends ConsumerState<UdharScreen> {
  @override
  Widget build(BuildContext context) {
    final udharAsync = ref.watch(udharCustomersProvider);
    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20, right: 20, bottom: 16,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text('Udhar Khata',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              GestureDetector(
                onTap: () => _showAddCustomerDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [
                    Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
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
                    const Text('Koi udhar nahi', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  ]))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(udharCustomersProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: customers.length,
                      itemBuilder: (_, i) => _customerCard(customers[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _customerCard(UdharCustomerModel customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
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
        Text('₹${customer.totalDue.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint, size: 20),
          onSelected: (val) async {
            if (val == 'paid') {
              await SupabaseService.markUdharPaid(customer.id);
              ref.invalidate(udharCustomersProvider);
              ref.invalidate(dashboardStatsProvider);
            }
          },
          itemBuilder: (_) => [const PopupMenuItem(value: 'paid', child: Text('✅ Poora paid'))],
        ),
      ]),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Naya Udhar Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl, decoration: _inputDeco('Customer ka naam *')),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: _inputDeco('Phone number')),
          const SizedBox(height: 12),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Udhar amount (₹) *')),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
              final userId = AuthService.currentUserId;
              final shop = await ref.read(shopProvider.future);
              if (userId == null || shop == null) return;
              await SupabaseService.saveUdharCustomer(UdharCustomerModel(
                id: '', shopId: shop.id, userId: userId,
                customerName: nameCtrl.text.trim(), customerPhone: phoneCtrl.text.trim(),
                totalDue: double.tryParse(amountCtrl.text) ?? 0, createdAt: DateTime.now(),
              ));
              ref.invalidate(udharCustomersProvider);
              ref.invalidate(dashboardStatsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
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
