import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  // ✅ Latin only — covers English + Hindi roman text
  // No Chinese, Japanese, Korean — not needed for Indian bills
  static final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // Main method — takes image file, returns extracted bill data
  static Future<Map<String, dynamic>> extractBillData(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);

      // Get full raw text
      final String rawText = recognizedText.text;

      // Parse the raw text into structured bill data
      return _parseBillData(rawText);
    } catch (e) {
      return {
        'raw_text': '',
        'amount': 0.0,
        'vendor_name': '',
        'bill_date': DateTime.now().toIso8601String().split('T')[0],
        'is_gst_bill': false,
        'gst_amount': 0.0,
        'error': e.toString(),
      };
    }
  }

  // Extract just the raw text — for preview
  static Future<String> extractRawText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return '';
    }
  }

  // ─────────────────────────────────────────
  // BILL DATA PARSER
  // ─────────────────────────────────────────

  static Map<String, dynamic> _parseBillData(String rawText) {
    return {
      'raw_text': rawText,
      'amount': _extractAmount(rawText),
      'vendor_name': _extractVendorName(rawText),
      'bill_date': _extractDate(rawText),
      'is_gst_bill': _isGstBill(rawText),
      'gst_amount': _extractGstAmount(rawText),
      'gstin': _extractGstin(rawText),
    };
  }

  // ─────────────────────────────────────────
  // AMOUNT EXTRACTOR
  // Most Indian bills show total as:
  // "Total: 1,250.00" or "Grand Total 850" or "Net Amount 500"
  // ─────────────────────────────────────────

  static double _extractAmount(String text) {
    final lines = text.split('\n');

    // Priority keywords — check these first
    final highPriority = [
      'grand total',
      'net amount',
      'total amount',
      'bill amount',
      'net payable',
      'amount payable',
      'total payable',
      'kul rakam',
    ];

    // Medium priority
    final mediumPriority = [
      'total',
      'subtotal',
      'sub total',
    ];

    // Search high priority first
    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final keyword in highPriority) {
        if (lower.contains(keyword)) {
          final amount = _extractNumberFromLine(line);
          if (amount > 0) return amount;
        }
      }
    }

    // Search medium priority
    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final keyword in mediumPriority) {
        if (lower.contains(keyword)) {
          final amount = _extractNumberFromLine(line);
          if (amount > 0) return amount;
        }
      }
    }

    // Fallback — find largest number in entire text
    return _findLargestAmount(text);
  }

  static double _extractNumberFromLine(String line) {
    // Match patterns like 1,250.00 or 1250 or 850.50
    final regex = RegExp(r'[\d,]+\.?\d*');
    final matches = regex.allMatches(line);
    double highest = 0;
    for (final match in matches) {
      final numStr = match.group(0)!.replaceAll(',', '');
      final num = double.tryParse(numStr) ?? 0;
      if (num > highest) highest = num;
    }
    return highest;
  }

  static double _findLargestAmount(String text) {
    final regex = RegExp(r'[\d,]+\.?\d*');
    final matches = regex.allMatches(text);
    double highest = 0;
    for (final match in matches) {
      final numStr = match.group(0)!.replaceAll(',', '');
      final num = double.tryParse(numStr) ?? 0;
      // Ignore unrealistic values (too small or too large)
      if (num > highest && num >= 1 && num <= 9999999) {
        highest = num;
      }
    }
    return highest;
  }

  // ─────────────────────────────────────────
  // VENDOR NAME EXTRACTOR
  // Usually the first non-empty line of a bill
  // ─────────────────────────────────────────

  static String _extractVendorName(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Skip lines that look like addresses or dates
    final skipPatterns = [
      RegExp(r'^\d'),           // starts with number
      RegExp(r'gst', caseSensitive: false),
      RegExp(r'invoice', caseSensitive: false),
      RegExp(r'bill', caseSensitive: false),
      RegExp(r'receipt', caseSensitive: false),
      RegExp(r'date', caseSensitive: false),
      RegExp(r'phone|mob|tel', caseSensitive: false),
    ];

    for (final line in lines.take(5)) {
      bool skip = false;
      for (final pattern in skipPatterns) {
        if (pattern.hasMatch(line)) {
          skip = true;
          break;
        }
      }
      if (!skip && line.length > 3) {
        return line;
      }
    }

    // Fallback — return first line
    return lines.isNotEmpty ? lines.first : '';
  }

  // ─────────────────────────────────────────
  // DATE EXTRACTOR
  // Handles formats: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
  // ─────────────────────────────────────────

  static String _extractDate(String text) {
    // Match DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final dateRegex = RegExp(
      r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})\b',
    );

    final match = dateRegex.firstMatch(text);
    if (match != null) {
      final day = match.group(1)!.padLeft(2, '0');
      final month = match.group(2)!.padLeft(2, '0');
      var year = match.group(3)!;

      // Convert 2-digit year to 4-digit
      if (year.length == 2) {
        year = '20$year';
      }

      // Return in YYYY-MM-DD format for Supabase
      return '$year-$month-$day';
    }

    // Fallback — today's date
    return DateTime.now().toIso8601String().split('T')[0];
  }

  // ─────────────────────────────────────────
  // GST DETECTION
  // ─────────────────────────────────────────

  static bool _isGstBill(String text) {
    final lower = text.toLowerCase();
    return lower.contains('gstin') ||
        lower.contains('gst no') ||
        lower.contains('gst number') ||
        lower.contains('cgst') ||
        lower.contains('sgst') ||
        lower.contains('igst') ||
        lower.contains('tax invoice');
  }

  static double _extractGstAmount(String text) {
    double cgst = 0;
    double sgst = 0;
    double igst = 0;

    final lines = text.split('\n');

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('cgst')) {
        cgst = _extractNumberFromLine(line);
      }
      if (lower.contains('sgst')) {
        sgst = _extractNumberFromLine(line);
      }
      if (lower.contains('igst')) {
        igst = _extractNumberFromLine(line);
      }
    }

    // IGST is used for interstate — either IGST or CGST+SGST
    return igst > 0 ? igst : (cgst + sgst);
  }

  // Extract GSTIN number — 15 character alphanumeric
  static String _extractGstin(String text) {
    final gstinRegex = RegExp(
      r'\b[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b',
    );
    final match = gstinRegex.firstMatch(text);
    return match?.group(0) ?? '';
  }

  // ─────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────

  static void dispose() {
    _recognizer.close();
  }
}