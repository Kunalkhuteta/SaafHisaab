import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../services/session_service.dart';
import '../home/home_screen.dart';

class SetPasscodeScreen extends ConsumerStatefulWidget {
  const SetPasscodeScreen({super.key});
  @override
  ConsumerState<SetPasscodeScreen> createState() => _SetPasscodeScreenState();
}

class _SetPasscodeScreenState extends ConsumerState<SetPasscodeScreen>
    with SingleTickerProviderStateMixin {
  String _passcode = '';
  String _firstPasscode = '';
  bool _isConfirming = false;
  bool _showError = false;
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
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_passcode.length >= 4) return;
    setState(() => _passcode += digit);

    if (_passcode.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_isConfirming) {
          // First entry done — move to confirm
          setState(() {
            _firstPasscode = _passcode;
            _passcode = '';
            _isConfirming = true;
          });
        } else {
          // Confirm entry done — check match
          if (_passcode == _firstPasscode) {
            _saveAndProceed();
          } else {
            // Mismatch — shake and retry confirm
            setState(() => _showError = true);
            _shakeController.forward();
          }
        }
      });
    }
  }

  void _onDelete() {
    if (_passcode.isNotEmpty) {
      setState(() => _passcode = _passcode.substring(0, _passcode.length - 1));
    }
  }

  Future<void> _saveAndProceed() async {
    await SessionService.savePasscode(_firstPasscode);
    await SessionService.saveLastActiveTime();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
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

          const SizedBox(height: 40),

          // Title
          Text(
            _isConfirming
                ? AppLang.tr(isEn, 'Confirm Passcode', 'Passcode confirm करें')
                : AppLang.tr(isEn, 'Set Passcode', 'Passcode set करें'),
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isConfirming
                ? AppLang.tr(isEn, 'Re-enter your 4-digit passcode', '4 अंकों का passcode दोबारा डालें')
                : AppLang.tr(isEn, 'Enter a 4-digit passcode', '4 अंकों का passcode डालें'),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),

          const SizedBox(height: 32),

          // Dots
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

          // Error text
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: _showError ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              AppLang.tr(isEn, 'Passcode did not match', 'Passcode match नहीं हुआ'),
              style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w500),
            ),
          ),

          const Spacer(),

          // Numpad
          _buildNumpad(),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
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
              color: AppColors.primaryBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 8, offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(k, style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.primary,
              )),
            ),
          ),
        );
      }).toList(),
    );
  }
}
