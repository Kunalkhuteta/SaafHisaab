import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  void _sendOTP() async {
    if (_phoneController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sahi 10 digit mobile number daalein'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => OTPScreen(phone: _phoneController.text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Logo
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 14),
                    const Text('SaafHisaab',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    const Text('Aapki dukaan ka saaf hisaab',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderBlue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Apna mobile number daalein',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('OTP se secure login hoga',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 20),

                    // Phone field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderBlue),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                  right: BorderSide(
                                      color: AppColors.borderBlue)),
                            ),
                            child: const Text('+91',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 2),
                              decoration: const InputDecoration(
                                hintText: '9876543210',
                                hintStyle:
                                    TextStyle(color: AppColors.textHint),
                                counterText: '',
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOTP,
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
                                  Text('OTP Bhejein',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 18),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Features row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _featureChip(Icons.receipt_rounded, 'Bill Scan'),
                  _featureChip(Icons.bar_chart_rounded, 'Sales Track'),
                  _featureChip(Icons.inventory_2_rounded, 'Stock'),
                ],
              ),

              const SizedBox(height: 32),

              Center(
                child: Text(
                  'SaafHisaab use karke aap hamare\nTerms & Privacy Policy se agree karte hain',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
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
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderBlue),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}