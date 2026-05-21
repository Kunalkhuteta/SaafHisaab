import 'dart:convert';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../globalVar.dart';
import '../models/item_master_model.dart';
import '../models/udhar_model.dart';
import 'credit_item_row.dart';
import 'party_name_field.dart';

class CreditSaleItem {
  final String? stockItemId;
  final String itemName;
  final double quantity;
  final String category;
  final String unit;
  final double amount;

  const CreditSaleItem({
    this.stockItemId,
    required this.itemName,
    required this.quantity,
    this.category = '',
    this.unit = 'piece',
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'stockItemId': stockItemId,
      'itemName': itemName,
      'quantity': quantity,
      'category': category,
      'unit': unit,
      'amount': amount,
    };
  }

  factory CreditSaleItem.fromJson(Map<String, dynamic> json) {
    return CreditSaleItem(
      stockItemId: json['stockItemId'] as String?,
      itemName: json['itemName'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      category: json['category'] ?? '',
      unit: json['unit'] ?? 'piece',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SavedCreditSale {
  static const noteMarker = '__saafhisaab_credit_sale_v1__';

  final String customerId;
  final String customerName;
  final String customerPhone;
  final double creditAmount;
  final double advancePaid;
  final double totalAmount;
  final DateTime? dueDate;
  final String note;
  final List<CreditSaleItem> items;
  final String? creditEntryId;
  final String? debitEntryId;

  const SavedCreditSale({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.creditAmount,
    required this.advancePaid,
    required this.totalAmount,
    this.dueDate,
    this.note = '',
    this.items = const [],
    this.creditEntryId,
    this.debitEntryId,
  });

  String toEntryNote() {
    final payload = {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'creditAmount': creditAmount,
      'advancePaid': advancePaid,
      'totalAmount': totalAmount,
      'dueDate': dueDate?.toIso8601String(),
      'note': note,
      'items': items.map((item) => item.toJson()).toList(),
    };
    return '$noteMarker${jsonEncode(payload)}';
  }

  static SavedCreditSale? tryParseNote(String note, {String? customerId}) {
    final markerIndex = note.indexOf(noteMarker);
    if (markerIndex < 0) return null;
    final jsonText = note.substring(markerIndex + noteMarker.length).trim();
    try {
      final payload = jsonDecode(jsonText) as Map<String, dynamic>;
      final rawItems = payload['items'] as List? ?? [];
      return SavedCreditSale(
        customerId: customerId ?? payload['customerId'] ?? '',
        customerName: payload['customerName'] ?? '',
        customerPhone: payload['customerPhone'] ?? '',
        creditAmount: (payload['creditAmount'] as num?)?.toDouble() ?? 0,
        advancePaid: (payload['advancePaid'] as num?)?.toDouble() ?? 0,
        totalAmount: (payload['totalAmount'] as num?)?.toDouble() ?? 0,
        dueDate: payload['dueDate'] == null
            ? null
            : DateTime.tryParse(payload['dueDate']),
        note: payload['note'] ?? '',
        items: rawItems
            .whereType<Map>()
            .map((item) => CreditSaleItem.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value))))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}

class CreditEntrySheet extends StatefulWidget {
  final String shopId;
  final String userId;
  final bool isEn;
  final String initialCustomerName;
  final String initialCustomerPhone;
  final double initialTotal;
  final List<ItemMasterModel> stockItems;
  final SavedCreditSale? existingCredit;

  const CreditEntrySheet({
    super.key,
    required this.shopId,
    required this.userId,
    required this.isEn,
    required this.initialCustomerName,
    required this.initialCustomerPhone,
    required this.initialTotal,
    required this.stockItems,
    this.existingCredit,
  });

  @override
  State<CreditEntrySheet> createState() => _CreditEntrySheetState();
}

class _CreditEntrySheetState extends State<CreditEntrySheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _advanceCtrl;
  late final TextEditingController _noteCtrl;
  late final List<CreditItemDraft> _items;
  UdharCustomerModel? _selectedCustomer;
  DateTime? _dueDate;
  bool _manualTotal = false;
  bool _saving = false;

  bool get _isEn => widget.isEn;
  double get _total => double.tryParse(_totalCtrl.text.trim()) ?? 0;
  double get _advance => double.tryParse(_advanceCtrl.text.trim()) ?? 0;
  double get _credit => (_total - _advance).clamp(0, double.infinity).toDouble();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCredit;
    _nameCtrl = TextEditingController(
      text: existing?.customerName ?? widget.initialCustomerName,
    );
    _phoneCtrl = TextEditingController(
      text: existing?.customerPhone ?? widget.initialCustomerPhone,
    );
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
    _items = existing?.items
            .map((item) => CreditItemDraft(
                  stockItemId: item.stockItemId,
                  name: item.itemName,
                  quantity: item.quantity,
                  category: item.category,
                  unit: item.unit,
                  price: item.quantity == 0 ? item.amount : item.amount / item.quantity,
                ))
            .toList() ??
        [CreditItemDraft()];
    _manualTotal = _totalCtrl.text.isNotEmpty;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    _noteCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmClose() async {
    if (_saving) return false;
    final hasData = _nameCtrl.text.trim().isNotEmpty ||
        _phoneCtrl.text.trim().isNotEmpty ||
        _totalCtrl.text.trim().isNotEmpty ||
        _items.any((item) => item.nameCtrl.text.trim().isNotEmpty);
    if (!hasData) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLang.tr(_isEn, 'Discard credit details?', 'क्रेडिट विवरण हटाएं?')),
        content: Text(AppLang.tr(_isEn, 'Go back and clear this credit draft?', 'वापस जाकर यह क्रेडिट ड्राफ्ट हटाएं?')),
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

  void _recalculateTotal() {
    final total = _items.fold<double>(0, (sum, item) => sum + item.total);
    if (!_manualTotal && total > 0) {
      _totalCtrl.text = total.toStringAsFixed(0);
    }
    setState(() {});
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final total = _total;
    final advance = _advance;

    if (name.isEmpty) {
      _showError(AppLang.tr(_isEn, 'Customer name is required', 'ग्राहक का नाम आवश्यक है'));
      return;
    }
    if (total <= 0) {
      _showError(AppLang.tr(_isEn, 'Total amount must be more than 0', 'Total amount 0 se zyada hona chahiye'));
      return;
    }
    if (advance > total) {
      _showError(AppLang.tr(_isEn, 'Advance cannot be more than total', 'एडवांस कुल रकम से ज्यादा नहीं हो सकता'));
      return;
    }
    final validItems = _items
        .where((item) => item.nameCtrl.text.trim().isNotEmpty && item.quantity > 0)
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
      _showError(AppLang.tr(_isEn, 'Add at least one item', 'Kam se kam ek item jodiye'));
      return;
    }

    if (_credit <= 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLang.tr(_isEn, 'Full payment received - no credit created', 'पूरा भुगतान मिल गया - क्रेडिट नहीं बनेगा')),
        backgroundColor: AppColors.success,
      ));
    }

    if (mounted) {
      Navigator.pop(
        context,
        SavedCreditSale(
          customerId: _selectedCustomer?.id ?? widget.existingCredit?.customerId ?? '',
          customerName: name,
          customerPhone: _phoneCtrl.text.trim(),
          creditAmount: _credit,
          advancePaid: advance,
          totalAmount: total,
          dueDate: _dueDate,
          note: _noteCtrl.text.trim(),
          items: validItems,
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              Text(
                AppLang.tr(_isEn, 'Credit Entry', 'उधार एंट्री'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              PartyNameField(
                shopId: widget.shopId,
                controller: _nameCtrl,
                phoneController: _phoneCtrl,
                isEn: _isEn,
                required: true,
                label: AppLang.tr(_isEn, 'Customer Name', 'ग्राहक का नाम'),
                hint: AppLang.tr(_isEn, 'Type or select customer', 'नाम लिखें या चुनें'),
                onCustomerSelected: (customer) =>
                    setState(() => _selectedCustomer = customer),
              ),
              if (_selectedCustomer != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '${AppLang.tr(_isEn, 'Current pending', 'अभी बाकी')}: Rs ${_selectedCustomer!.totalDue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _section(AppLang.tr(_isEn, 'Items Purchased', 'खरीदे गए आइटम'))),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(CreditItemDraft())),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(AppLang.tr(_isEn, 'Add Item', 'आइटम जोड़ें')),
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
              _amountField(
                _totalCtrl,
                AppLang.tr(_isEn, 'Total Amount Rs', 'कुल रकम Rs'),
                onChanged: (_) {
                  _manualTotal = true;
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              _amountField(
                _advanceCtrl,
                AppLang.tr(_isEn, 'Advance Paid Rs', 'एडवांस दिया Rs'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLang.tr(_isEn, 'Credit Remaining', 'उधार बाकी'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'Rs ${_credit.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: _decoration(AppLang.tr(_isEn, 'Phone Number', 'Phone Number'), Icons.phone_outlined),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _decoration(AppLang.tr(_isEn, 'Payment Due Date', 'भुगतान की तारीख'), Icons.event_outlined),
                  child: Text(
                    _dueDate == null ? AppLang.tr(_isEn, 'Not selected', 'चुना नहीं गया') : _formatDate(_dueDate!),
                    style: TextStyle(
                      color: _dueDate == null ? AppColors.textHint : AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: _decoration(AppLang.tr(_isEn, 'Note (optional)', 'Note (optional)'), Icons.note_alt_outlined),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(AppLang.tr(_isEn, 'Save Credit', 'Credit Save Karein')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
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
                  onPressed: _saving
                      ? null
                      : () async {
                          if (await _confirmClose() && mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: Text(AppLang.tr(_isEn, 'Cancel', 'Cancel')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _section(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
