import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../sys_param.dart';

class SystemParamsScreen extends ConsumerStatefulWidget {
  const SystemParamsScreen({super.key});

  @override
  ConsumerState<SystemParamsScreen> createState() => _SystemParamsScreenState();
}

class _SystemParamsScreenState extends ConsumerState<SystemParamsScreen> {
  late bool showNumber;
  late bool showGst;
  late bool showPendingAmount;
  late bool showStock;
  late bool showStation;
  late bool showAddress;

  @override
  void initState() {
    super.initState();
    final sysParams = ref.read(sysParamProvider);
    showNumber = sysParams.showNumber;
    showGst = sysParams.showGst;
    showPendingAmount = sysParams.showPendingAmount;
    showStock = sysParams.showStock;
    showStation = sysParams.showStation;
    showAddress = sysParams.showAddress;
  }

  void _saveSettings() {
    ref.read(sysParamProvider.notifier).setParam(
      showNumber: showNumber,
      showGst: showGst,
      showPendingAmount: showPendingAmount,
      showStock: showStock,
      showStation: showStation,
      showAddress: showAddress,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'System Params', 'सिस्टम पैरामीटर')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  AppLang.tr(isEn, 'Purchase Fields Configuration', 'खरीद फ़ील्ड कॉन्फ़िगरेशन'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  context: context,
                  title: AppLang.tr(isEn, 'Show Number', 'नंबर दिखाएं'),
                  value: showNumber,
                  onChanged: (val) => setState(() => showNumber = val),
                ),
                _buildSwitchTile(
                  context: context,
                  title: AppLang.tr(isEn, 'Show GST Number', 'GST नंबर दिखाएं'),
                  value: showGst,
                  onChanged: (val) => setState(() => showGst = val),
                ),
                _buildSwitchTile(
                  context: context,
                  title: AppLang.tr(isEn, 'Show Pending Amount', 'बकाया राशि दिखाएं'),
                  value: showPendingAmount,
                  onChanged: (val) => setState(() => showPendingAmount = val),
                ),
                _buildSwitchTile(
                  context: context,
                  title: AppLang.tr(isEn, 'Show Stock', 'स्टॉक दिखाएं'),
                  value: showStock,
                  onChanged: (val) => setState(() => showStock = val),
                ),
                _buildSwitchTile(
                  context: context,
                  title: AppLang.tr(isEn, 'Show Station', 'स्टेशन दिखाएं'),
                  value: showStation,
                  onChanged: (val) => setState(() => showStation = val),
                ),
                _buildSwitchTile(
                  context: context,
                  title: AppLang.tr(isEn, 'Show Address', 'पता दिखाएं'),
                  value: showAddress,
                  onChanged: (val) => setState(() => showAddress = val),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLang.tr(isEn, 'Save Settings', 'सेटिंग्स सहेजें'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}
