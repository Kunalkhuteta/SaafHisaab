import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'shop_setup_screen.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../home/home_screen.dart';

class OTPScreen extends StatefulWidget {
  final String phone;
  const OTPScreen({super.key, required this.phone});
  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
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

void _verifyOTP() async {
  String otp = _controllers.map((c) => c.text).join();
  if (otp.length != 6) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Poora 6-digit OTP daalein'),
        backgroundColor: AppColors.error,
      ),
    );
    return;
  }
  setState(() => _isLoading = true);
  try {
    final response = await AuthService.verifyOTP(
      phone: widget.phone,
      otp: otp,
    );

    if (response.user != null) {
      // Check if this user already has a shop
      final shopExists = await SupabaseService.shopExists(response.user!.id);

      if (mounted) {
        if (shopExists) {
          // Returning user → go home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else {
          // New user → go to shop setup
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ShopSetupScreen()),
            (route) => false,
          );
        }
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Galat OTP — dobara try karein'),
          backgroundColor: AppColors.error,
        ),
      );
      // Clear OTP boxes
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Blue header
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_rounded,
                          color: Colors.white70, size: 18),
                      SizedBox(width: 4),
                      Text('Wapas jaayein',
                          style: TextStyle(
                              fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('OTP verify karein',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('+91 ${widget.phone} pe OTP bheja gaya hai',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  const Text('6-digit OTP daalein',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    _secondsLeft > 0
                        ? '00:${_secondsLeft.toString().padLeft(2, '0')} mein expire hoga'
                        : 'OTP expire ho gaya',
                    style: TextStyle(
                        fontSize: 13,
                        color: _secondsLeft > 0
                            ? AppColors.textSecondary
                            : AppColors.error),
                  ),

                  const SizedBox(height: 32),

                  // OTP boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) {
                      return Container(
                        width: 46,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _focusNodes[i].hasFocus
                                ? AppColors.primary
                                : AppColors.borderBlue,
                            width:
                                _focusNodes[i].hasFocus ? 2 : 1,
                          ),
                        ),
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                          decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none),
                          onChanged: (val) {
                            setState(() {});
                            if (val.isNotEmpty && i < 5) {
                              _focusNodes[i + 1].requestFocus();
                            }
                            if (val.isEmpty && i > 0) {
                              _focusNodes[i - 1].requestFocus();
                            }
                            if (i == 5 && val.isNotEmpty) _verifyOTP();
                          },
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : const Text('Verify karein',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _secondsLeft == 0
                          ? () {
                              setState(() => _secondsLeft = 30);
                              _startTimer();
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderBlue),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _secondsLeft > 0
                            ? 'OTP dobara bhejein (00:${_secondsLeft.toString().padLeft(2, '0')})'
                            : 'OTP dobara bhejein',
                        style: TextStyle(
                            color: _secondsLeft > 0
                                ? AppColors.textHint
                                : AppColors.primary),
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