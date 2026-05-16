import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../services/session_service.dart';
import '../../services/auth_service.dart';
import '../../providers/app_providers.dart';
import 'login_screen.dart';

class PasscodeScreen extends ConsumerStatefulWidget {
  const PasscodeScreen({super.key});
  @override
  ConsumerState<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends ConsumerState<PasscodeScreen>
    with SingleTickerProviderStateMixin {
  String _passcode = '';
  int _attempts = 0;
  bool _showError = false;
  bool _isLocked = false;
  int _lockSeconds = 0;
  Timer? _lockTimer;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
        setState(() {
          _showError = false;
          _passcode = '';
        });
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  void _startLockTimer() {
    setState(() {
      _isLocked = true;
      _lockSeconds = 30;
    });
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isLocked = false;
          _lockSeconds = 0;
        });
      } else {
        setState(() => _lockSeconds--);
      }
    });
  }

  void _onDigit(String digit) {
    if (_isLocked || _passcode.length >= 4) return;
    setState(() => _passcode += digit);

    if (_passcode.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), _verifyPasscode);
    }
  }

  void _onDelete() {
    if (_isLocked) return;
    if (_passcode.isNotEmpty) {
      setState(() => _passcode = _passcode.substring(0, _passcode.length - 1));
    }
  }

  Future<void> _verifyPasscode() async {
    final isCorrect = await SessionService.verifyPasscode(_passcode);
    if (isCorrect) {
      await SessionService.saveLastActiveTime();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _attempts++;
      if (_attempts >= 5) {
        // 5 wrong — clear everything, go to login
        await SessionService.clearPasscode();
        await AuthService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
      }
      if (_attempts >= 3) {
        _startLockTimer();
      }
      setState(() => _showError = true);
      _shakeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final shopAsync = ref.watch(shopProvider);
    final remaining = 5 - _attempts;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
            // Blue header
            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 28,
              ),
              child: Column(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SaafHisaab',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Shop owner greeting
            shopAsync.when(
              loading: () => const SizedBox(height: 40),
              error: (_, __) => const SizedBox(height: 40),
              data: (shop) => Column(
                children: [
                  Text(
                    AppLang.tr(isEn, 'Hello, ${shop?.ownerName ?? 'User'} ji', 'नमस्ते, ${shop?.ownerName ?? ''} जी'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  if (shop?.shopName.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(shop!.shopName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),
            Text(
              AppLang.tr(isEn, 'Enter your passcode', 'अपना passcode डालें'),
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 32),

            // Dots with shake
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _shakeController.isAnimating
                        ? _shakeAnimation.value * ((_shakeController.value * 10).toInt().isEven ? 1 : -1)
                        : 0,
                    0,
                  ),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => _buildDot(i)),
              ),
            ),

            const SizedBox(height: 16),

            // Error / lock / attempts text
            if (_isLocked)
              Text(
                AppLang.tr(isEn, 'Locked for $_lockSeconds seconds', '$_lockSeconds सेकंड के लिए लॉक'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
              )
            else if (_showError)
              Text(
                AppLang.tr(isEn, 'Wrong passcode', 'गलत passcode'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.error),
              ),

            if (_attempts > 0 && !_isLocked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  AppLang.tr(isEn, '$remaining attempts left', '$remaining प्रयास बाकी'),
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ),

            const Spacer(),

            // Numpad
            _buildNumpad(),

            // Biometric hint + Forgot
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded, color: AppColors.textHint, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        AppLang.tr(isEn, 'Use fingerprint', 'फिंगरप्रिंट इस्तेमाल करें'),
                        style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      await SessionService.clearPasscode();
                      await AuthService.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    child: Text(
                      AppLang.tr(isEn, 'Forgot passcode?', 'Passcode भूल गए?'),
                      style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

                ], // close Column children
              ), // close Column
            ), // close SliverFillRemaining
          ], // close slivers
        ), // close CustomScrollView
      ), // close Scaffold
    ); // close PopScope
  }

  Widget _buildDot(int index) {
    final isFilled = index < _passcode.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: isFilled ? 20 : 16,
      height: isFilled ? 20 : 16,
      decoration: BoxDecoration(
        color: _showError
            ? AppColors.error
            : (isFilled ? AppColors.primary : Colors.transparent),
        shape: BoxShape.circle,
        border: Border.all(
          color: _showError
              ? AppColors.error
              : (isFilled ? AppColors.primary : AppColors.border),
          width: 2.5,
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          _numRow(['1', '2', '3']),
          const SizedBox(height: 16),
          _numRow(['4', '5', '6']),
          const SizedBox(height: 16),
          _numRow(['7', '8', '9']),
          const SizedBox(height: 16),
          _numRow(['', '0', 'del']),
        ],
      ),
    );
  }

  Widget _numRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox(width: 72, height: 72);
        if (k == 'del') {
          return GestureDetector(
            onTap: _onDelete,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.backspace_rounded, color: AppColors.error, size: 24),
            ),
          );
        }
        return GestureDetector(
          onTap: () => _onDigit(k),
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _isLocked ? AppColors.border.withOpacity(0.5) : AppColors.primaryBg,
              shape: BoxShape.circle,
              boxShadow: _isLocked ? [] : [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 8, offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(k, style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w600,
                color: _isLocked ? AppColors.textHint : AppColors.primary,
              )),
            ),
          ),
        );
      }).toList(),
    );
  }
}
