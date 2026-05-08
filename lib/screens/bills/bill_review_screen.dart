import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/share_service.dart';
import '../../models/bill_model.dart';
import '../../globalVar.dart';

class BillReviewScreen extends ConsumerStatefulWidget {
  final Uint8List imageBytes;
  final Map<String, dynamic> ocrData;

  const BillReviewScreen({
    super.key,
    required this.imageBytes,
    required this.ocrData,
  });

  @override
  ConsumerState<BillReviewScreen> createState() => _BillReviewScreenState();
}

class _BillReviewScreenState extends ConsumerState<BillReviewScreen> {
  late TextEditingController _vendorCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _gstAmountCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _itemNameCtrl;
  late TextEditingController _itemQtyCtrl;
  late DateTime _billDate;
  String _billType = 'purchase';
  bool _isGstBill = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.ocrData;
    _vendorCtrl = TextEditingController(text: data['vendor_name'] ?? '');
    final amount = (data['amount'] ?? 0.0);
    _amountCtrl = TextEditingController(
      text: amount is double && amount > 0 ? amount.toStringAsFixed(2) : '',
    );
    _isGstBill = data['is_gst_bill'] ?? false;
    final gst = (data['gst_amount'] ?? 0.0);
    _gstAmountCtrl = TextEditingController(
      text: gst is double && gst > 0 ? gst.toStringAsFixed(2) : '',
    );
    _notesCtrl = TextEditingController();
    _itemNameCtrl = TextEditingController();
    _itemQtyCtrl = TextEditingController(text: '1');

    try {
      final dateStr = data['bill_date'] as String?;
      _billDate = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    } catch (_) {
      _billDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _amountCtrl.dispose();
    _gstAmountCtrl.dispose();
    _notesCtrl.dispose();
    _itemNameCtrl.dispose();
    _itemQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _saveBill(bool isEn) async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLang.tr(isEn, 'Enter a valid amount', 'सही राशि डालें')),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = AuthService.currentUserId;
      final shop = await ref.read(shopProvider.future);
      if (userId == null || shop == null) throw Exception('User or shop not found');

      final vendorName = _vendorCtrl.text.trim();
      final gstAmount = double.tryParse(_gstAmountCtrl.text.trim()) ?? 0;
      final notes = _notesCtrl.text.trim();

      // 1. Save bill to Supabase
      await SupabaseService.saveBill(BillModel(
        id: '',
        shopId: shop.id,
        userId: userId,
        rawText: widget.ocrData['raw_text'] ?? '',
        amount: amount,
        billDate: _billDate,
        vendorName: vendorName,
        billType: _billType,
        isGstBill: _isGstBill,
        gstAmount: gstAmount,
        notes: notes,
        createdAt: DateTime.now(),
      ));

      // 2. Stock deduction for sale bills
      if (_billType == 'sale' && _itemNameCtrl.text.trim().isNotEmpty) {
        final qty = double.tryParse(_itemQtyCtrl.text.trim()) ?? 1;
        try {
          await SupabaseService.deductStock(
            shop.id,
            _itemNameCtrl.text.trim(),
            qty,
          );
        } catch (e) {
          debugPrint('Stock deduction failed: $e');
        }
      }

      ref.invalidate(todayBillsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(stockItemsProvider);

      if (mounted) {
        // 3. Show share dialog before popping
        await _showShareDialog(isEn, vendorName, amount, gstAmount, notes);

        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showShareDialog(bool isEn, String vendorName, double amount, double gstAmount, String notes) async {
    final shouldShare = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(AppLang.tr(isEn, 'Bill Saved!', 'बिल सहेजा गया!'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          AppLang.tr(isEn, 'Share this bill via WhatsApp?', 'यह बिल WhatsApp पर शेयर करें?'),
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLang.tr(isEn, 'Skip', 'छोड़ें'),
                style: const TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
            label: Text(AppLang.tr(isEn, 'Share', 'शेयर करें'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366), // WhatsApp green
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );

    if (shouldShare == true) {
      await ShareService.shareBill(
        vendorName: vendorName,
        amount: amount,
        billType: _billType,
        billDate: _billDate,
        isGstBill: _isGstBill,
        gstAmount: gstAmount,
        notes: notes,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final hasOcrData = (widget.ocrData['raw_text'] ?? '').toString().isNotEmpty;

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
                    AppLang.tr(isEn, 'Review Bill', 'बिल समीक्षा'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                if (hasOcrData)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(AppLang.tr(isEn, 'OCR', 'OCR'),
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.memory(widget.imageBytes, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100, color: AppColors.primaryBg,
                          child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textHint, size: 40)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      hasOcrData
                          ? AppLang.tr(isEn, '✅ Data extracted — verify below', '✅ डेटा निकाला — नीचे सत्यापित करें')
                          : AppLang.tr(isEn, '📝 Enter bill details manually', '📝 बिल विवरण मैन्युअल दर्ज करें'),
                      style: TextStyle(fontSize: 12, color: hasOcrData ? AppColors.success : AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Bill Type
                  _label(AppLang.tr(isEn, 'Bill Type', 'बिल प्रकार')),
                  const SizedBox(height: 8),
                  Row(children: [
                    _typeChip(AppLang.tr(isEn, 'Purchase', 'खरीद'), 'purchase'),
                    const SizedBox(width: 10),
                    _typeChip(AppLang.tr(isEn, 'Sale', 'बिक्री'), 'sale'),
                  ]),

                  const SizedBox(height: 14),

                  // Vendor
                  _label(AppLang.tr(isEn, 'Vendor / Party Name', 'वेंडर / पार्टी नाम')),
                  const SizedBox(height: 6),
                  _field(_vendorCtrl, AppLang.tr(isEn, 'E.g. Sharma Traders', 'जैसे शर्मा ट्रेडर्स')),

                  const SizedBox(height: 14),

                  // Amount
                  _label(AppLang.tr(isEn, 'Amount (₹) *', 'राशि (₹) *')),
                  const SizedBox(height: 6),
                  _field(_amountCtrl, '0.00', isNumber: true),

                  const SizedBox(height: 14),

                  // Date
                  _label(AppLang.tr(isEn, 'Bill Date', 'बिल तारीख')),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderBlue)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Text('${_billDate.day.toString().padLeft(2, '0')}/${_billDate.month.toString().padLeft(2, '0')}/${_billDate.year}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      ]),
                    ),
                  ),

                  // ── Sale-specific: Stock Deduction ──
                  if (_billType == 'sale') ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.success.withOpacity(0.2)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.inventory_2_rounded, color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            AppLang.tr(isEn, 'Deduct from Stock (optional)', 'स्टॉक से कटौती (वैकल्पिक)'),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
                          )),
                        ]),
                        const SizedBox(height: 10),
                        _field(_itemNameCtrl, AppLang.tr(isEn, 'Item name (must match stock)', 'आइटम नाम (स्टॉक से मिलना चाहिए)')),
                        const SizedBox(height: 8),
                        _field(_itemQtyCtrl, AppLang.tr(isEn, 'Quantity to deduct', 'कटौती मात्रा'), isNumber: true),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // GST toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(AppLang.tr(isEn, 'GST Bill', 'GST बिल'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
                      Switch(value: _isGstBill, activeColor: AppColors.primary, onChanged: (v) => setState(() => _isGstBill = v)),
                    ]),
                  ),

                  if (_isGstBill) ...[
                    const SizedBox(height: 10),
                    _label(AppLang.tr(isEn, 'GST Amount (₹)', 'GST राशि (₹)')),
                    const SizedBox(height: 6),
                    _field(_gstAmountCtrl, '0.00', isNumber: true),
                  ],

                  const SizedBox(height: 14),
                  _label(AppLang.tr(isEn, 'Notes (optional)', 'नोट्स (वैकल्पिक)')),
                  const SizedBox(height: 6),
                  _field(_notesCtrl, AppLang.tr(isEn, 'Any notes...', 'कोई नोट...'), maxLines: 2),

                  const SizedBox(height: 22),

                  // Save Button
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : () => _saveBill(isEn),
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded, color: Colors.white),
                      label: Text(AppLang.tr(isEn, 'Save & Share', 'सहेजें और शेयर'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String label, String type) {
    final sel = _billType == type;
    return GestureDetector(
      onTap: () => setState(() => _billType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary));

  Widget _field(TextEditingController c, String hint, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: c, keyboardType: isNumber ? TextInputType.number : TextInputType.text, maxLines: maxLines,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
        filled: true, fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
