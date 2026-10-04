import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../globalVar.dart';
import '../services/invoice_pdf_service.dart';

class ReportPdfActionButton extends ConsumerWidget {
  final Future<String> Function() onGenerateHtml;
  final String reportTitle;
  final String? tooltip;
  final Color iconColor;
  final Widget? customIcon;

  const ReportPdfActionButton({
    super.key,
    required this.onGenerateHtml,
    required this.reportTitle,
    this.tooltip,
    this.iconColor = Colors.white,
    this.customIcon,
  });

  static Future<void> triggerAction({
    required BuildContext context,
    required WidgetRef ref,
    required Future<String> Function() onGenerateHtml,
    required String reportTitle,
    required String action,
  }) async {
    final isEn = ref.read(appLanguageProvider);
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(AppLang.tr(
              isEn,
              'Generating PDF report...',
              'PDF रिपोर्ट तैयार हो रही है...',
            )),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.primary,
      ),
    );

    try {
      final html = await onGenerateHtml();
      messenger.hideCurrentSnackBar();

      final cleanTitle = reportTitle.replaceAll(RegExp(r'[^\w\-]'), '_');

      if (action == 'print') {
        await InvoicePdfService.printOrSavePdf(
          htmlContent: html,
          invoiceTitle: cleanTitle,
        );
      } else if (action == 'browser') {
        InvoicePdfService.openHtmlInBrowser(
          htmlContent: html,
          invoiceTitle: cleanTitle,
        );
      } else if (action == 'share') {
        await InvoicePdfService.shareInvoice(
          htmlContent: html,
          filename: cleanTitle,
          invoiceTitle: reportTitle,
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(appLanguageProvider);

    return PopupMenuButton<String>(
      icon: customIcon ?? Icon(Icons.picture_as_pdf_rounded, color: iconColor),
      tooltip: tooltip ?? AppLang.tr(isEn, 'PDF Report', 'PDF रिपोर्ट'),
      onSelected: (action) => triggerAction(
        context: context,
        ref: ref,
        onGenerateHtml: onGenerateHtml,
        reportTitle: reportTitle,
        action: action,
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'print',
          child: Row(
            children: [
              const Icon(Icons.print_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                AppLang.tr(isEn, 'Print / Save PDF', 'PDF प्रिंट / सेव करें'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'browser',
          child: Row(
            children: [
              const Icon(Icons.open_in_browser_rounded, color: Colors.teal, size: 20),
              const SizedBox(width: 10),
              Text(
                AppLang.tr(isEn, 'Preview in Browser', 'ब्राउज़र में देखें'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              const Icon(Icons.share_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Text(
                AppLang.tr(isEn, 'Share Report', 'रिपोर्ट शेयर करें'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
