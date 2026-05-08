import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import 'shop_setup_screen.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../home/home_screen.dart';
import '../../globalVar.dart';

class OTPScreen extends ConsumerStatefulWidget {
  final String phone;
  const OTPScreen({super.key, required this.phone});
  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() async {
    while (_secondsLeft > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _secondsLeft--);
    }
  }

  void _resendOTP(bool isEn) async {
    setState(() => _isLoading = true);
    try {
      await AuthService.sendOTP(widget.phone);
      if (mounted) {
        setState(() => _secondsLeft = 30);
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(isEn, 'OTP sent again', 'OTP दोबारा भेज दिया गया')), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(isEn, 'Failed to send OTP: ${e.toString()}', 'OTP भेजने में विफल: ${e.toString()}')), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _verifyOTP(bool isEn) async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(isEn, 'Enter full 6-digit OTP', 'पूरा 6 अंकों का OTP डालें')), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await AuthService.verifyOTP(phone: widget.phone, otp: otp);
      if (response.user != null) {
        final shopExists = await SupabaseService.shopExists(response.user!.id);
        if (mounted) {
          if (shopExists) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
          } else {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ShopSetupScreen()), (route) => false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(isEn, 'Invalid OTP — please try again', 'गलत OTP — कृपया पुनः प्रयास करें')), backgroundColor: AppColors.error));
        for (var c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
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
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 4),
                      Text(AppLang.tr(isEn, 'Go Back', 'वापस जाएँ'), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppLang.tr(isEn, 'Verify OTP', 'OTP सत्यापित करें'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(AppLang.tr(isEn, 'OTP sent to +91 ${widget.phone}', '+91 ${widget.phone} पर OTP भेजा गया है'), style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Text(AppLang.tr(isEn, 'Enter 6-digit OTP', '6 अंकों का OTP डालें'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    _secondsLeft > 0
                        ? AppLang.tr(isEn, 'Expires in 00:${_secondsLeft.toString().padLeft(2, '0')}', '00:${_secondsLeft.toString().padLeft(2, '0')} में समाप्त होगा')
                        : AppLang.tr(isEn, 'OTP has expired', 'OTP समाप्त हो गया है'),
                    style: TextStyle(fontSize: 13, color: _secondsLeft > 0 ? AppColors.textSecondary : AppColors.error),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) {
                      return Container(
                        width: 46, height: 54,
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _focusNodes[i].hasFocus ? AppColors.primary : AppColors.borderBlue, width: _focusNodes[i].hasFocus ? 2 : 1)),
                        child: TextField(
                          controller: _controllers[i], focusNode: _focusNodes[i], keyboardType: TextInputType.number, maxLength: 1, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                          decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                          onChanged: (val) {
                            setState(() {});
                            if (val.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                            if (val.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                            if (i == 5 && val.isNotEmpty) _verifyOTP(isEn);
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _verifyOTP(isEn),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : Text(AppLang.tr(isEn, 'Verify Now', 'अभी सत्यापित करें'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: OutlinedButton(
                      onPressed: _secondsLeft == 0 ? () => _resendOTP(isEn) : null,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.borderBlue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(
                        _secondsLeft > 0
                            ? AppLang.tr(isEn, 'Resend OTP (00:${_secondsLeft.toString().padLeft(2, '0')})', 'OTP दोबारा भेजें (00:${_secondsLeft.toString().padLeft(2, '0')})')
                            : AppLang.tr(isEn, 'Resend OTP', 'OTP दोबारा भेजें'),
                        style: TextStyle(color: _secondsLeft > 0 ? AppColors.textHint : AppColors.primary),
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
}