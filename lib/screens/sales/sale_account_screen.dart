import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../models/udhar_model.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../providers/app_providers.dart';

class SaleAccountScreen extends ConsumerStatefulWidget {
  final UdharCustomerModel? party;
  
  const SaleAccountScreen({super.key, this.party});

  @override
  ConsumerState<SaleAccountScreen> createState() => _SaleAccountScreenState();
}

class _SaleAccountScreenState extends ConsumerState<SaleAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _pendingAmountController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.party != null) {
      final p = widget.party!;
      _nameController.text = p.customerName;
      _numberController.text = p.customerPhone;
      _pendingAmountController.text = p.totalDue.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _pendingAmountController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = AuthService.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final shop = await ref.read(shopProvider.future);
      if (shop == null) throw Exception('Shop not found');

      final double totalDue = double.tryParse(_pendingAmountController.text) ?? 0.0;

      final udharData = UdharCustomerModel(
        id: widget.party?.id ?? '',
        shopId: shop.id,
        userId: userId,
        customerName: _nameController.text.trim(),
        customerPhone: _numberController.text.trim(),
        totalDue: totalDue,
        createdAt: widget.party?.createdAt ?? DateTime.now(),
      );

      if (widget.party != null) {
        await SupabaseService.updateUdharCustomer(udharData);
      } else {
        await SupabaseService.saveUdharCustomer(udharData);
      }

      // Invalidate relevant providers to refresh lists/stats
      ref.invalidate(udharCustomersProvider);
      ref.invalidate(dashboardStatsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.party != null
                ? AppLang.tr(ref.read(appLanguageProvider), 'Sale party updated successfully!', 'बिक्री पार्टी सफलतापूर्वक अपडेट की गई!')
                : AppLang.tr(ref.read(appLanguageProvider), 'Sale party created successfully!', 'बिक्री पार्टी सफलतापूर्वक बनाई गई!')
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, widget.party != null ? 'Edit Sale Party' : 'Sale Party', widget.party != null ? 'बिक्री पार्टी संपादित करें' : 'बिक्री पार्टी')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: AppLang.tr(isEn, 'Party Name', 'पार्टी का नाम'),
                      icon: Icons.person_rounded,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _numberController,
                      label: AppLang.tr(isEn, 'Phone Number', 'फ़ोन नंबर'),
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _pendingAmountController,
                      label: AppLang.tr(isEn, 'Initial Balance (₹)', 'प्रारंभिक शेष (₹)'),
                      icon: Icons.currency_rupee_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLang.tr(isEn, 'Save Party', 'पार्टी सहेजें'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
