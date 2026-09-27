import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class InvoicePdfPrinterPlatform {
  /// Opens print dialog in browser with automatic print prompt and backup print button
  static Future<void> printOrSaveHtml(String htmlContent, String title) async {
    final printButtonAndScript = '''
<div class="no-print" style="position:fixed;top:16px;right:20px;display:flex;gap:8px;z-index:9999;">
  <button onclick="window.print()" style="padding:10px 18px;background:#2563eb;color:#fff;border:none;border-radius:6px;font-size:14px;font-weight:bold;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,0.15);">🖨️ Print / Save as PDF</button>
  <button onclick="window.close()" style="padding:10px 14px;background:#64748b;color:#fff;border:none;border-radius:6px;font-size:14px;cursor:pointer;">✕ Close</button>
</div>
<script>
  window.addEventListener('load', function() {
    setTimeout(function() {
      try { window.print(); } catch (e) {}
    }, 450);
  });
</script>
</body>
''';

    final finalHtml = htmlContent.contains('</body>')
        ? htmlContent.replaceFirst('</body>', printButtonAndScript)
        : '$htmlContent$printButtonAndScript';

    final blob = html.Blob([finalHtml], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  /// Opens the raw HTML in a new browser tab for live preview / editing review
  static void openHtmlInNewTab(String htmlContent, String title) {
    const previewHeader = '''
<div class="no-print" style="position:fixed;top:16px;right:20px;display:flex;gap:8px;z-index:9999;">
  <button onclick="window.print()" style="padding:10px 18px;background:#2563eb;color:#fff;border:none;border-radius:6px;font-size:14px;font-weight:bold;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,0.15);">🖨️ Print / Save as PDF</button>
</div>
</body>
''';

    final finalHtml = htmlContent.contains('</body>')
        ? htmlContent.replaceFirst('</body>', previewHeader)
        : '$htmlContent$previewHeader';

    final blob = html.Blob([finalHtml], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  /// Generates PDF bytes if supported on web, or returns encoded HTML bytes
  static Future<Uint8List> generatePdfBytes(String htmlContent) async {
    // Web fallback: return UTF8 bytes of HTML
    return Uint8List.fromList(utf8.encode(htmlContent));
  }

  /// Downloads the HTML document to local computer
  static void downloadHtml(String htmlContent, String filename) {
    final bytes = utf8.encode(htmlContent);
    final blob = html.Blob([bytes], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..download = filename.endsWith('.html') ? filename : '$filename.html';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  /// Shares invoice on web
  static Future<void> shareInvoice(String htmlContent, String filename, String title) async {
    // On web, open the print / save view
    await printOrSaveHtml(htmlContent, title);
  }
}
