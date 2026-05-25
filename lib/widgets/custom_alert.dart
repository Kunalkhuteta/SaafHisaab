import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum CustomAlertType {
  success,
  error,
  warning,
  info,
}

class CustomAlert extends StatelessWidget {
  final String title;
  final String content;
  final CustomAlertType type;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const CustomAlert({
    super.key,
    required this.title,
    required this.content,
    required this.type,
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
  });

  /// Static helper to show the dialog with a premium scale-and-fade entry animation
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String content,
    CustomAlertType type = CustomAlertType.warning,
    String? confirmLabel,
    String? cancelLabel,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool dismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: 'CustomAlertBarrier',
      barrierColor: Colors.black.withOpacity(0.55), // Modern, soft dim backdrop
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack, // Playful bounce entry for modern feel
        );
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: animation,
            child: CustomAlert(
              title: title,
              content: content,
              type: type,
              confirmLabel: confirmLabel,
              cancelLabel: cancelLabel,
              onConfirm: onConfirm,
              onCancel: onCancel,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Style configurations based on the alert type
    Color primaryColor;
    Color badgeBgColor;
    IconData iconData;

    switch (type) {
      case CustomAlertType.success:
        primaryColor = AppColors.success;
        badgeBgColor = AppColors.success.withOpacity(0.12);
        iconData = Icons.check_circle_outline_rounded;
        break;
      case CustomAlertType.error:
        primaryColor = AppColors.error;
        badgeBgColor = AppColors.error.withOpacity(0.12);
        iconData = Icons.error_outline_rounded;
        break;
      case CustomAlertType.warning:
        primaryColor = AppColors.warning;
        badgeBgColor = AppColors.warning.withOpacity(0.12);
        iconData = Icons.warning_amber_rounded;
        break;
      case CustomAlertType.info:
        primaryColor = AppColors.primary;
        badgeBgColor = AppColors.primary.withOpacity(0.12);
        iconData = Icons.info_outline_rounded;
        break;
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 340), // Standard size constraint
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: primaryColor.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Alert Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Dynamic Alert Description
                    Text(
                      content,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Action Buttons Layout
                    Row(
                      children: [
                        // Optional Cancel Button
                        if (cancelLabel != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                if (onCancel != null) onCancel!();
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                cancelLabel!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Confirm Button (Standard action)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              if (onConfirm != null) onConfirm!();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              confirmLabel ?? 'OK',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Floating Icon Badge at the Top
              Positioned(
                top: -30,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4), // Inner white ring margin
                      child: Container(
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconData,
                          color: primaryColor,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
