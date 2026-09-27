import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bill_model.dart';
import '../../models/shop_model.dart';
import '../../providers/app_providers.dart';
import 'handlelib_service.dart';
import 'invoice_html_template.dart';
import 'invoice_pdf_printer_stub.dart'
    if (dart.library.html) 'invoice_pdf_printer_web.dart';

class InvoicePdfService {
  /// Fetches shop and invoice payload asynchronously and generates the complete HTML document
  static Future<String> loadAndBuildInvoiceHtml({
    required WidgetRef ref,
    required BillModel bill,
  }) async {
    ShopModel? shop;
    try {
      shop = await ref.read(shopProvider.future);
    } catch (e) {
      debugPrint('Error fetching shop for invoice: $e');
    }

    Map<String, dynamic>? invoiceData;
    try {
      final res = await HandleLibService.getSalesInvoiceByInvTranId(bill.id);
      if (res['statusCode'] == 200 && res['data'] != null) {
        invoiceData = res['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading invoice payload: $e');
    }

    String? creatorName;
    try {
      final namesMap = ref.read(shopMemberNamesProvider).valueOrNull ?? {};
      creatorName = namesMap[bill.userId];
    } catch (e) {
      debugPrint('Error getting creator name: $e');
    }

    return InvoiceHtmlTemplate.generate(
      shop: shop,
      bill: bill,
      invoiceData: invoiceData,
      creatorName: creatorName,
    );
  }

  /// Opens the print / save as PDF dialog (works seamlessly on Web and Mobile)
  static Future<void> printOrSavePdf({
    required String htmlContent,
    required String invoiceTitle,
  }) async {
    await InvoicePdfPrinterPlatform.printOrSaveHtml(htmlContent, invoiceTitle);
  }

  /// Opens HTML preview directly in a new browser tab
  static void openHtmlInBrowser({
    required String htmlContent,
    required String invoiceTitle,
  }) {
    InvoicePdfPrinterPlatform.openHtmlInNewTab(htmlContent, invoiceTitle);
  }

  /// Downloads the HTML invoice file locally
  static void downloadHtml({
    required String htmlContent,
    required String filename,
  }) {
    InvoicePdfPrinterPlatform.downloadHtml(htmlContent, filename);
  }

  /// Shares the invoice via native share or print dialog
  static Future<void> shareInvoice({
    required String htmlContent,
    required String filename,
    required String invoiceTitle,
  }) async {
    await InvoicePdfPrinterPlatform.shareInvoice(htmlContent, filename, invoiceTitle);
  }
}
