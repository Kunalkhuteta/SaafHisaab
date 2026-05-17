import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../sys_param.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';

class PurchaseAccountScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? party;
  
  const PurchaseAccountScreen({super.key, this.party});

  @override
  ConsumerState<PurchaseAccountScreen> createState() => _PurchaseAccountScreenState();
}

class _PurchaseAccountScreenState extends ConsumerState<PurchaseAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _gstController = TextEditingController();
  final _pendingAmountController = TextEditingController();
  final _stockController = TextEditingController();
  final _stationController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.party != null) {
      final p = widget.party!;
      _nameController.text = p['name'] ?? '';
      _numberController.text = p['phone_number'] ?? '';
      _gstController.text = p['gst_number'] ?? '';
      _pendingAmountController.text = (p['pending_amount'] ?? 0).toString();
      _stockController.text = p['related_stock'] ?? '';
      _stationController.text = p['station'] ?? '';
      _addressController.text = p['address'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _gstController.dispose();
    _pendingAmountController.dispose();
    _stockController.dispose();
    _stationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = AuthService.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final shop = await SupabaseService.getShop(userId);
      if (shop == null) throw Exception('Shop not found');

      final sysParams = ref.read(sysParamProvider);

      final data = {
        'shop_id': shop.id,
        'name': _nameController.text.trim(),
        if (sysParams.showNumber) 'phone_number': _numberController.text.trim(),
        if (sysParams.showGst) 'gst_number': _gstController.text.trim(),
        if (sysParams.showPendingAmount) 'pending_amount': double.tryParse(_pendingAmountController.text) ?? 0.0,
        if (sysParams.showStock) 'related_stock': _stockController.text.trim(),
        if (sysParams.showStation) 'station': _stationController.text.trim(),
        if (sysParams.showAddress) 'address': _addressController.text.trim(),
      };

      if (widget.party != null) {
        await Supabase.instance.client
            .from('purchase_parties')
            .update(data)
            .eq('id', widget.party!['id']);
      } else {
        await Supabase.instance.client.from('purchase_parties').insert(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.party != null ? 'Purchase account updated successfully!' : 'Purchase account created successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final sysParams = ref.watch(sysParamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, widget.party != null ? 'Edit Purchase Account' : 'Purchase Account', widget.party != null ? 'खरीद खाता संपादित करें' : 'खरीद खाता')),
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
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    if (sysParams.showNumber) ...[
                      _buildTextField(
                        controller: _numberController,
                        label: AppLang.tr(isEn, 'Phone Number', 'फ़ोन नंबर'),
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (sysParams.showGst) ...[
                      _buildTextField(
                        controller: _gstController,
                        label: AppLang.tr(isEn, 'GST Number', 'GST नंबर'),
                        icon: Icons.receipt_long_rounded,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (sysParams.showPendingAmount) ...[
                      _buildTextField(
                        controller: _pendingAmountController,
                        label: AppLang.tr(isEn, 'Pending Amount', 'बकाया राशि'),
                        icon: Icons.currency_rupee_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (sysParams.showStock) ...[
                      _buildTextField(
                        controller: _stockController,
                        label: AppLang.tr(isEn, 'Related Stock', 'संबंधित स्टॉक'),
                        icon: Icons.inventory_2_rounded,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (sysParams.showStation) ...[
                      _buildTextField(
                        controller: _stationController,
                        label: AppLang.tr(isEn, 'Station', 'स्टेशन'),
                        icon: Icons.location_city_rounded,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (sysParams.showAddress) ...[
                      _buildTextField(
                        controller: _addressController,
                        label: AppLang.tr(isEn, 'Address', 'पता'),
                        icon: Icons.home_rounded,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                    ],
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
                        AppLang.tr(isEn, 'Save Account', 'खाता सहेजें'),
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
