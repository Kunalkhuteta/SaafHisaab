import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../home/home_screen.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key});
  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  final _shopNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _gstController = TextEditingController();
  final _ownerNameController = TextEditingController();
  String _selectedType = 'Kirana Store';
  bool _isLoading = false;

  final List<String> _shopTypes = [
    'Kirana Store', 'Kapda / Cloth', 'Electronics',
    'Medical / Pharmacy', 'Hardware', 'Stationery',
    'Restaurant / Dhaba', 'Jewellery', 'Other',
  ];

void _saveShop() async {
  if (_ownerNameController.text.trim().isEmpty ||
      _shopNameController.text.trim().isEmpty ||
      _cityController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Naam, dukaan aur shahar zaroori hai'),
        backgroundColor: AppColors.error,
      ),
    );
    return;
  }
  setState(() => _isLoading = true);
  try {
    final userId = AuthService.currentUserId;
    final userPhone = AuthService.currentUserPhone;
    if (userId == null) throw Exception('User not logged in');

    await SupabaseService.saveShop(
      userId: userId,
      ownerName: _ownerNameController.text.trim(),
      shopName: _shopNameController.text.trim(),
      city: _cityController.text.trim(),
      shopType: _selectedType,
      phone: userPhone ?? '',
      gstNumber: _gstController.text.trim(),
    );

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  void dispose() {
  _ownerNameController.dispose();
  _shopNameController.dispose();
  _cityController.dispose();
  _gstController.dispose();
  super.dispose();
}

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20, right: 20, bottom: 20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Apni dukaan setup karein',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 4),
                Text('Ek baar karo, hamesha ke liye',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),

          // Progress
          Container(
            color: AppColors.primaryBg,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _progressStep('1', 'Login', true, true),
                _progressLine(true),
                _progressStep('2', 'Setup', true, false),
                _progressLine(false),
                _progressStep('3', 'Shuru', false, false),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField('Aapka naam *', 'Jaise: Ramesh Sharma', _ownerNameController),
const SizedBox(height: 16),
                  _buildField('Shahar / City *', 'Jaise: Kota, Rajasthan',
                      _cityController),
                  const SizedBox(height: 16),

                  const Text('Dukaan ka type *',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderBlue),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        isExpanded: true,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textPrimary),
                        items: _shopTypes
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedType = val!),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildField('GST Number (optional)',
                      'Jaise: 27AAPFU0939F1ZV', _gstController),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveShop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Shuru karein',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                                SizedBox(width: 8),
                                Icon(Icons.rocket_launch_rounded,
                                    color: Colors.white, size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderBlue)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderBlue)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _progressStep(String num, String label, bool done, bool current) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done ? AppColors.primary : AppColors.border,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done && !current
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text(num,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            done ? Colors.white : AppColors.textHint)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: done ? AppColors.primary : AppColors.textHint)),
      ],
    );
  }

  Widget _progressLine(bool done) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        color: done ? AppColors.primary : AppColors.border,
      ),
    );
  }
}

