import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../constants/app_colors.dart';
import '../globalVar.dart';
import '../models/item_master_model.dart';
import 'credit_entry_sheet.dart';
import 'credit_item_row.dart';
import 'package:saafhisaab/utils/indian_date_time.dart';


/// Bottom sheet for entering purchase credit details (owner buying on credit from a supplier).
/// Returns a [SavedCreditSale] to keep the data model consistent with the sale credit flow.
class PurchaseCreditEntrySheet extends StatefulWidget {
  final String shopId;
  final String userId;
  final bool isEn;
  final String initialPartyName;
  final double initialTotal;
  final List<ItemMasterModel> stockItems;
  final List<Map<String, dynamic>> purchaseParties;
  final SavedCreditSale? existingCredit;

  const PurchaseCreditEntrySheet({
    super.key,
    required this.shopId,
    required this.userId,
    required this.isEn,
    required this.initialPartyName,
    required this.initialTotal,
    required this.stockItems,
    required this.purchaseParties,
    this.existingCredit,
  });

  @override
  State<PurchaseCreditEntrySheet> createState() =>
      _PurchaseCreditEntrySheetState();
}

class _PurchaseCreditEntrySheetState extends State<PurchaseCreditEntrySheet> {
  late String? _selectedPartyId;
  late String _selectedPartyName;
  late double _selectedPartyPending;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _advanceCtrl;
  late final TextEditingController _noteCtrl;
  late final List<CreditItemDraft> _items;
  DateTime? _dueDate;
  Uint8List? _billImageBytes;
  String _billImageExtension = 'jpg';
  late String _billImageUrl;
  bool _manualTotal = false;

  bool get _isEn => widget.isEn;
  double get _total => double.tryParse(_totalCtrl.text.trim()) ?? 0;
  double get _advance => double.tryParse(_advanceCtrl.text.trim()) ?? 0;
  double get _credit =>
      (_total - _advance).clamp(0, double.infinity).toDouble();
  double get _itemsTotal =>
      _items.fold<double>(0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCredit;

    // Try to match initial party
    _selectedPartyId = null;
    _selectedPartyName = existing?.customerName ?? widget.initialPartyName;
    _selectedPartyPending = 0;

    if (_selectedPartyName.isNotEmpty) {
      for (final party in widget.purchaseParties) {
        if ((party['name'] as String?) == _selectedPartyName) {
          _selectedPartyId = party['id'] as String?;
          _selectedPartyPending =
              (party['pending_amount'] as num?)?.toDouble() ?? 0;
          break;
        }
      }
    }

    _totalCtrl = TextEditingController(
      text: ((existing?.totalAmount ?? widget.initialTotal) > 0)
          ? (existing?.totalAmount ?? widget.initialTotal).toStringAsFixed(0)
          : '',
    );
    _advanceCtrl = TextEditingController(
      text: (existing?.advancePaid ?? 0) > 0
          ? existing!.advancePaid.toStringAsFixed(0)
          : '',
    );
    _noteCtrl = TextEditingController(text: existing?.note ?? '');
    _dueDate = existing?.dueDate;
    _billImageUrl = existing?.billImageUrl ?? '';
    _items = existing?.items
            .map((item) => CreditItemDraft(
                  stockItemId: item.stockItemId,
                  name: item.itemName,
                  quantity: item.quantity,
                  category: item.category,
                  unit: item.unit,
                  price: item.quantity == 0
                      ? item.amount
                      : item.amount / item.quantity,
                ))
            .toList() ??
        [CreditItemDraft()];
    _manualTotal = false;
    _syncTotalWithItems();
  }

  Future<void> _pickBillImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    var ext = path.extension(pickedFile.path).replaceAll('.', '');
    if (ext.isEmpty && pickedFile.mimeType != null) {
      ext = pickedFile.mimeType!.split('/').last;
    }
    setState(() {
      _billImageBytes = bytes;
      _billImageExtension = ext.isEmpty ? 'jpg' : ext;
      _billImageUrl = '';
    });
  }

  void _showBillImageSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: _imageSourceButton(
                Icons.photo_camera_rounded,
                AppLang.tr(_isEn, 'Camera', 'Camera'),
                () {
                  Navigator.pop(ctx);
                  _pickBillImage(ImageSource.camera);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _imageSourceButton(
                Icons.photo_library_rounded,
                AppLang.tr(_isEn, 'Gallery', 'Gallery'),
                () {
                  Navigator.pop(ctx);
                  _pickBillImage(ImageSource.gallery);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    _noteCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _syncTotalWithItems() {
    if (_manualTotal) return;
    final total = _itemsTotal;
    _totalCtrl.text = total > 0 ? total.toStringAsFixed(0) : '';
    if (_advance > total) {
      _advanceCtrl.clear();
    }
  }

  void _recalculateTotal() {
    _syncTotalWithItems();
    setState(() {});
  }

  Future<void> _pickDueDate() async {
    final now = IndianDateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: IndianDateTime.date(now.year, now.month, now.day),
      lastDate: IndianDateTime.date(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<bool> _confirmClose() async {
    final hasData = _selectedPartyId != null ||
        _totalCtrl.text.trim().isNotEmpty ||
        _items.any((item) => item.nameCtrl.text.trim().isNotEmpty);
    if (!hasData) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLang.tr(_isEn, 'Discard credit details?',
            'क्रेडिट विवरण हटाएं?')),
        content: Text(AppLang.tr(_isEn, 'Go back and clear this credit draft?',
            'वापस जाकर यह क्रेडिट ड्राफ्ट हटाएं?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLang.tr(_isEn, 'No', 'नहीं')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLang.tr(_isEn, 'Yes', 'हाँ')),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  void _save() {
    if (_selectedPartyId == null || _selectedPartyName.isEmpty) {
      _showError(AppLang.tr(
          _isEn, 'Select a purchase party', 'खरीद पार्टी चुनें'));
      return;
    }
    _syncTotalWithItems();
    final total = _total;
    final advance = _advance;

    if (total <= 0) {
      _showError(AppLang.tr(_isEn, 'Total amount must be more than 0',
          'कुल राशि 0 से अधिक होनी चाहिए'));
      return;
    }
    if (advance > total) {
      _showError(AppLang.tr(_isEn, 'Advance cannot be more than total',
          'एडवांस कुल रकम से ज्यादा नहीं हो सकता'));
      return;
    }

    final validItems = _items
        .where((item) =>
            item.nameCtrl.text.trim().isNotEmpty && item.quantity > 0)
        .map((item) => CreditSaleItem(
              stockItemId: item.stockItemId,
              itemName: item.nameCtrl.text.trim(),
              quantity: item.quantity,
              category: item.categoryCtrl.text.trim(),
              unit: item.unitCtrl.text.trim().isEmpty
                  ? 'piece'
                  : item.unitCtrl.text.trim(),
              amount: item.total,
            ))
        .toList();

    if (validItems.isEmpty) {
      _showError(AppLang.tr(
          _isEn, 'Add at least one item', 'कम से कम एक आइटम जोड़ें'));
      return;
    }

    if (_credit <= 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLang.tr(
            _isEn,
            'Full payment done — no credit created',
            'पूरा भुगतान हो गया — क्रेडिट नहीं बनेगा')),
        backgroundColor: AppColors.success,
      ));
    }

    if (mounted) {
      Navigator.pop(
        context,
        SavedCreditSale(
          customerId: _selectedPartyId ?? '',
          customerName: _selectedPartyName,
          customerPhone: '', // purchase parties use phone_number field
          creditAmount: _credit,
          advancePaid: advance,
          totalAmount: total,
          dueDate: _dueDate,
          note: _noteCtrl.text.trim(),
          items: validItems,
          billId: widget.existingCredit?.billId,
          billImageUrl: _billImageUrl,
          billImageBytes: _billImageBytes,
          billImageExtension: _billImageExtension,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.stockItems
        .map((item) => item.itemCategory)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return WillPopScope(
      onWillPop: _confirmClose,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Icon(Icons.shopping_cart_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      AppLang.tr(_isEn, 'Purchase Credit Entry',
                          'खरीद उधार एंट्री'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    AppLang.tr(
                        _isEn,
                        'Record items bought on credit from supplier',
                        'सप्लायर से उधार खरीदे गए आइटम दर्ज करें'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Purchase Party Dropdown ──
                  Text(
                    AppLang.tr(_isEn, 'Purchase Party *', 'खरीद पार्टी *'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedPartyId,
                    isExpanded: true,
                    decoration: _decoration(
                      AppLang.tr(
                          _isEn, 'Select Party', 'पार्टी चुनें'),
                      Icons.people_rounded,
                    ),
                    items: widget.purchaseParties
                        .map((p) => DropdownMenuItem<String>(
                              value: p['id'] as String,
                              child: Text(
                                p['name'] as String? ?? '',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      final party = widget.purchaseParties
                          .firstWhere((p) => p['id'] == id);
                      setState(() {
                        _selectedPartyId = id;
                        _selectedPartyName =
                            party['name'] as String? ?? '';
                        _selectedPartyPending =
                            (party['pending_amount'] as num?)
                                    ?.toDouble() ??
                                0;
                      });
                    },
                  ),
                  if (_selectedPartyId != null &&
                      _selectedPartyPending > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        '${AppLang.tr(_isEn, 'Already pending', 'पहले से बकाया')}: Rs ${_selectedPartyPending.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),

                  // ── Items ──
                  Row(children: [
                    Expanded(
                      child: Text(
                        AppLang.tr(
                            _isEn, 'Items Purchased', 'खरीदे गए आइटम'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _items.add(CreditItemDraft())),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(AppLang.tr(
                          _isEn, 'Add Item', 'आइटम जोड़ें')),
                    ),
                  ]),
                  ...List.generate(
                    _items.length,
                    (index) => CreditItemRow(
                      item: _items[index],
                      stockItems: widget.stockItems,
                      categories: categories,
                      isEn: _isEn,
                      canRemove: _items.length > 1,
                      onChanged: _recalculateTotal,
                      onRemove: () {
                        final item = _items.removeAt(index);
                        item.dispose();
                        _recalculateTotal();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Total ──
                  _amountField(
                    _totalCtrl,
                    AppLang.tr(
                        _isEn, 'Total Amount Rs', 'कुल रकम Rs'),
                    onChanged: (_) {
                      _manualTotal = true;
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Advance Paid ──
                  _amountField(
                    _advanceCtrl,
                    AppLang.tr(
                        _isEn, 'Advance Paid Rs', 'एडवांस दिया Rs'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // ── Credit Remaining ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppLang.tr(_isEn, 'Credit (You Owe)',
                              'उधार (आप पर बकाया)'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'Rs ${_credit.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // ── Due Date ──
                  InkWell(
                    onTap: _pickDueDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _decoration(
                        AppLang.tr(_isEn, 'Payment Due Date',
                            'भुगतान की तारीख'),
                        Icons.event_outlined,
                      ),
                      child: Text(
                        _dueDate == null
                            ? AppLang.tr(
                                _isEn, 'Not selected', 'चुना नहीं गया')
                            : _formatDate(_dueDate!),
                        style: TextStyle(
                          color: _dueDate == null
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Note ──
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: _decoration(
                      AppLang.tr(
                          _isEn, 'Note (optional)', 'नोट (वैकल्पिक)'),
                      Icons.note_alt_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _billImagePicker(),
                  const SizedBox(height: 18),

                  // ── Save ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(AppLang.tr(_isEn,
                          'Save Purchase Credit', 'खरीद उधार सेव करें')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        if (await _confirmClose() && mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child:
                          Text(AppLang.tr(_isEn, 'Cancel', 'रद्द करें')),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _billImagePicker() {
    final hasImage = _billImageBytes != null || _billImageUrl.isNotEmpty;
    return InkWell(
      onTap: _showBillImageSource,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderBlue),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: _billImageBytes != null
                ? Image.memory(_billImageBytes!, fit: BoxFit.cover)
                : _billImageUrl.isNotEmpty
                    ? Image.network(_billImageUrl, fit: BoxFit.cover)
                    : const Icon(Icons.receipt_long_rounded,
                        color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hasImage
                    ? AppLang.tr(_isEn, 'Bill image attached',
                        'Bill image attached')
                    : AppLang.tr(_isEn, 'Attach bill image',
                        'Attach bill image'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLang.tr(_isEn, 'Camera or gallery, compressed on save',
                    'Camera or gallery, compressed on save'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          Icon(
            hasImage ? Icons.edit_rounded : Icons.add_a_photo_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ]),
      ),
    );
  }

  Widget _imageSourceButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              )),
        ]),
      ),
    );
  }

  Widget _amountField(
    TextEditingController controller,
    String label, {
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: _decoration(label, Icons.currency_rupee_rounded),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
