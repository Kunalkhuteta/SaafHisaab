import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class InvoicePdfPrinterPlatform {
  /// Converts HTML to PDF and opens the native Print / Save as PDF sheet
  static Future<void> printOrSaveHtml(String htmlContent, String title) async {
    try {
      final pdfBytes = await Printing.convertHtml(
        html: htmlContent,
        format: PdfPageFormat.a4,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: title,
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      debugPrint('Error printing invoice on mobile: $e');
      rethrow;
    }
  }

  /// Opens preview/print dialog
  static void openHtmlInNewTab(String htmlContent, String title) async {
    await printOrSaveHtml(htmlContent, title);
  }

  /// Converts HTML to real PDF bytes (Uint8List)
  static Future<Uint8List> generatePdfBytes(String htmlContent) async {
    return await Printing.convertHtml(
      html: htmlContent,
      format: PdfPageFormat.a4,
    );
  }

  /// Downloads or saves invoice file
  static void downloadHtml(String htmlContent, String filename) async {
    await printOrSaveHtml(htmlContent, filename);
  }

  /// Shares PDF file via native share sheet (WhatsApp, Email, etc.)
  static Future<void> shareInvoice(String htmlContent, String filename, String title) async {
    final pdfBytes = await generatePdfBytes(htmlContent);
    final pdfName = filename.endsWith('.pdf') ? filename : '$filename.pdf';
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: pdfName,
      subject: title,
    );
  }
}
