import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saafhisaab/services/auth_service.dart';
import '../../constants/app_colors.dart';
import 'otp_screen.dart';
import '../../globalVar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  void _sendOTP(bool isEn) async {
    if (_phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLang.tr(isEn, 'Enter a valid 10 digit mobile number', 'सही 10 अंक का मोबाइल नंबर डालें')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.sendOTP(_phoneController.text.trim());
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => OTPScreen(phone: _phoneController.text.trim())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(isEn, 'Failed to send OTP: ${e.toString()}', 'OTP भेजने में विफल: ${e.toString()}')), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language toggle at the top right
              Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('हिंदी', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: isEn, activeColor: AppColors.primary,
                      onChanged: (val) => ref.read(appLanguageProvider.notifier).state = val,
                    ),
                    const Text('Eng', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 14),
                    const Text('SaafHisaab', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text(AppLang.tr(isEn, 'Clean Accounts for Your Shop', 'आपकी दुकान का साफ़ हिसाब'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppColors.surfaceBlue, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderBlue)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLang.tr(isEn, 'Enter your mobile number', 'अपना मोबाइल नंबर डालें'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(AppLang.tr(isEn, 'Secure login via OTP', 'OTP द्वारा सुरक्षित लॉगिन'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderBlue)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.borderBlue))),
                            child: const Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController, keyboardType: TextInputType.phone, maxLength: 10,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 2),
                              decoration: const InputDecoration(hintText: '9876543210', hintStyle: TextStyle(color: AppColors.textHint), counterText: '', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _sendOTP(isEn),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(AppLang.tr(isEn, 'Send OTP', 'OTP भेजें'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _featureChip(Icons.receipt_rounded, AppLang.tr(isEn, 'Bill Scan', 'बिल स्कैन')),
                  _featureChip(Icons.bar_chart_rounded, AppLang.tr(isEn, 'Sales Track', 'बिक्री ट्रैक')),
                  _featureChip(Icons.inventory_2_rounded, AppLang.tr(isEn, 'Stock', 'स्टॉक')),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  AppLang.tr(isEn, 'By using SaafHisaab you agree to our\nTerms & Privacy Policy', 'SaafHisaab का उपयोग करके आप हमारी\nशर्तों और गोपनीयता नीति से सहमत हैं'),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderBlue)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}