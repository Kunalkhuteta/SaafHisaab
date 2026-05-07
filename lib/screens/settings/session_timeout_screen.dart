import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../services/session_service.dart';

class SessionTimeoutScreen extends ConsumerStatefulWidget {
  const SessionTimeoutScreen({super.key});
  @override
  ConsumerState<SessionTimeoutScreen> createState() => _SessionTimeoutScreenState();
}

class _SessionTimeoutScreenState extends ConsumerState<SessionTimeoutScreen> {
  int _selectedMinutes = 5;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _options = [
    {'minutes': 0, 'en': 'Immediately (every app open)', 'hi': 'तुरंत (हर बार ऐप खोलने पर)'},
    {'minutes': 1, 'en': '1 minute', 'hi': '1 मिनट'},
    {'minutes': 5, 'en': '5 minutes', 'hi': '5 मिनट'},
    {'minutes': 15, 'en': '15 minutes', 'hi': '15 मिनट'},
    {'minutes': 30, 'en': '30 minutes', 'hi': '30 मिनट'},
    {'minutes': 60, 'en': '1 hour', 'hi': '1 घंटा'},
    {'minutes': -1, 'en': 'Never (only on logout)', 'hi': 'कभी नहीं (सिर्फ लॉगआउट पर)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final minutes = await SessionService.getTimeoutSetting();
    setState(() {
      _selectedMinutes = minutes;
      _isLoading = false;
    });
  }

  Future<void> _save(bool isEn) async {
    await SessionService.saveTimeoutSetting(_selectedMinutes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLang.tr(isEn, 'Settings saved', 'Settings save हो गया')),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20, right: 20, bottom: 16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    AppLang.tr(isEn, 'Session Timeout', 'सेशन टाइमआउट'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderBlue),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLang.tr(
                                isEn,
                                'Choose how long the app waits before asking for your passcode again.',
                                'चुनें कि ऐप कितनी देर बाद दोबारा passcode मांगे।',
                              ),
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      AppLang.tr(isEn, 'Lock app after', 'ऐप लॉक करें इसके बाद'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),

                    const SizedBox(height: 12),

                    // Options
                    ...List.generate(_options.length, (i) {
                      final opt = _options[i];
                      final isSelected = _selectedMinutes == opt['minutes'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMinutes = opt['minutes']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))]
                                : [],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: isSelected ? Colors.white : AppColors.textHint,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppLang.tr(isEn, opt['en'], opt['hi']),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _save(isEn),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          AppLang.tr(isEn, 'Save Settings', 'सेटिंग्स सहेजें'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
