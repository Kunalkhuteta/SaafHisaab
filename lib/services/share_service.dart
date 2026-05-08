import 'package:share_plus/share_plus.dart';

class ShareService {
  /// Share bill details via WhatsApp or any sharing app
  static Future<void> shareBill({
    required String vendorName,
    required double amount,
    required String billType,
    required DateTime billDate,
    bool isGstBill = false,
    double gstAmount = 0,
    String notes = '',
  }) async {
    final dateStr =
        '${billDate.day.toString().padLeft(2, '0')}/${billDate.month.toString().padLeft(2, '0')}/${billDate.year}';
    final typeStr = billType == 'sale' ? 'Sale / बिक्री' : 'Purchase / खरीद';

    String msg = '📋 *SaafHisaab Bill*\n\n';
    msg += '📌 Type: $typeStr\n';
    if (vendorName.isNotEmpty) msg += '🏪 Party: $vendorName\n';
    msg += '💰 Amount: ₹${amount.toStringAsFixed(0)}\n';
    msg += '📅 Date: $dateStr\n';
    if (isGstBill && gstAmount > 0) {
      msg += '🧾 GST: ₹${gstAmount.toStringAsFixed(0)}\n';
    }
    if (notes.isNotEmpty) msg += '📝 Note: $notes\n';
    msg += '\n_Sent via SaafHisaab — Aapki dukaan ka saaf hisaab_';

    await Share.share(msg, subject: 'SaafHisaab Bill');
  }

  /// Share udhar reminder
  static Future<void> shareUdharReminder({
    required String customerName,
    required double amount,
    String shopName = '',
  }) async {
    String msg = '💰 *Udhar Reminder*\n\n';
    msg += 'Dear $customerName,\n';
    msg += 'Your pending amount is ₹${amount.toStringAsFixed(0)}';
    if (shopName.isNotEmpty) msg += ' at $shopName';
    msg += '.\n\nPlease clear at your earliest convenience.\n';
    msg += '\n_Sent via SaafHisaab_';

    await Share.share(msg, subject: 'Udhar Reminder');
  }
}
