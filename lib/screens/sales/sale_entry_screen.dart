import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/share_service.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../models/stock_model.dart';
import '../../globalVar.dart';

class _SaleLineItem {
  String? stockItemId;
  String stockItemName = '';
  String unit = 'piece';
  double currentStock = 0;
  bool isLowStock = false;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _SaleLineItem()
      : qtyCtrl = TextEditingController(text: '1'),
        priceCtrl = TextEditingController(text: '0');

  double get quantity => double.tryParse(qtyCtrl.text) ?? 0;
  double get unitPrice => double.tryParse(priceCtrl.text) ?? 0;
  double get lineTotal => quantity * unitPrice;

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class SaleEntryScreen extends ConsumerStatefulWidget {
  final BillModel? bill;
  const SaleEntryScreen({super.key, this.bill});
  @override
  ConsumerState<SaleEntryScreen> createState() => _SaleEntryScreenState();
}

class _SaleEntryScreenState extends ConsumerState<SaleEntryScreen> {
  final _customerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_SaleLineItem> _lineItems = [_SaleLineItem()];
  String _paymentMode = 'cash';
  bool _isSaving = false;

  double get _grandTotal =>
      _lineItems.fold(0.0, (sum, item) => sum + item.lineTotal);

  @override
  void initState() {
    super.initState();
    if (widget.bill != null) {
      _loadExistingSale();
    }
  }

  Future<void> _loadExistingSale() async {
    _customerCtrl.text = widget.bill!.vendorName;
    _notesCtrl.text = widget.bill!.notes;
    try {
      final sales = await SupabaseService.getSalesByBillId(widget.bill!.id);
      if (sales.isNotEmpty) {
        setState(() {
          _paymentMode = sales.first.paymentMode;
          _lineItems.clear();
          for (var s in sales) {
            final item = _SaleLineItem();
            item.stockItemName = s.itemName;
            item.stockItemId = s.stockItemId;
            item.unit = s.unit;
            item.qtyCtrl.text = s.quantity.toString();
            item.priceCtrl.text = s.sellingPrice.toString();
            _lineItems.add(item);
          }
        });
        
        // Refresh current stock for these items
        final stockItems = await ref.read(stockItemsProvider.future);
        setState(() {
          for (var li in _lineItems) {
            final si = stockItems.firstWhere(
              (element) => element.id == li.stockItemId, 
              orElse: () => StockItemModel(
                id: '', 
                shopId: '', 
                userId: '', 
                itemName: '', 
                currentQuantity: 0, 
                unit: '',
                createdAt: DateTime.now(),
              )
            );
            li.currentStock = si.currentQuantity;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading existing sale: $e');
    }
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addLineItem() => setState(() => _lineItems.add(_SaleLineItem()));

  void _removeLineItem(int index) {
    if (_lineItems.length > 1) {
      _lineItems[index].dispose();
      setState(() => _lineItems.removeAt(index));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  Future<void> _saveSale(bool isEn) async {
    // ── Validate ──
    for (int i = 0; i < _lineItems.length; i++) {
      final li = _lineItems[i];
      if (li.stockItemId == null) {
        _showError(AppLang.tr(isEn, 'Select item for row ${i + 1}',
            'पंक्ति ${i + 1} के लिए आइटम चुनें'));
        return;
      }
      if (li.quantity <= 0) {
        _showError(AppLang.tr(isEn, 'Qty must be > 0 for ${li.stockItemName}',
            '${li.stockItemName} की मात्रा 0 से अधिक होनी चाहिए'));
        return;
      }
      if (li.quantity > li.currentStock) {
        _showError(AppLang.tr(
            isEn,
            'Insufficient stock for ${li.stockItemName}! Available: ${li.currentStock.toStringAsFixed(0)} ${li.unit}',
            '${li.stockItemName} का स्टॉक कम! उपलब्ध: ${li.currentStock.toStringAsFixed(0)} ${li.unit}'));
        return;
      }
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final userId = AuthService.currentUserId;
      final shop = await ref.read(shopProvider.future);
      if (userId == null || shop == null) throw Exception('Not found');

      String billId;
      if (widget.bill != null) {
        // UPDATE MODE
        billId = widget.bill!.id;
        
        // 1. Reverse old stock deductions
        final oldSales = await SupabaseService.getSalesByBillId(billId);
        for (var os in oldSales) {
          if (os.stockItemId != null) {
            await SupabaseService.addStockById(os.stockItemId!, os.quantity);
          }
        }

        // 2. Update Bill
        await SupabaseService.updateBill(billId, 
          amount: _grandTotal, 
          vendorName: _customerCtrl.text.trim(), 
          notes: _notesCtrl.text.trim()
        );

        // 3. Delete old sale items
        await SupabaseService.deleteSalesByBillId(billId);
      } else {
        // NEW MODE
        // 1. Save BillModel and get its unique ID
        billId = await SupabaseService.saveBillGetId(BillModel(
          id: '',
          shopId: shop.id,
          userId: userId,
          amount: _grandTotal,
          billDate: DateTime.now(),
          vendorName: _customerCtrl.text.trim(),
          billType: 'sale',
          notes: _notesCtrl.text.trim(),
          createdAt: DateTime.now(),
        ));
      }

      // 4. Save individual SaleModel records linked to the bill + deduct stock
      int stockUpdated = 0;
      for (final li in _lineItems) {
        await SupabaseService.saveSale(SaleModel(
          id: '',
          shopId: shop.id,
          userId: userId,
          itemName: li.stockItemName,
          quantity: li.quantity,
          unit: li.unit,
          sellingPrice: li.unitPrice,
          totalAmount: li.lineTotal,
          paymentMode: _paymentMode,
          billId: billId.isNotEmpty ? billId : null,
          saleDate: DateTime.now(),
          notes: _notesCtrl.text.trim(),
          createdAt: DateTime.now(),
          stockItemId: li.stockItemId,
        ));

        // 5. Deduct stock by ID
        if (li.stockItemId != null) {
          final deducted = await SupabaseService.deductStockById(
              li.stockItemId!, li.quantity);
          if (deducted) stockUpdated++;
        }
      }

      ref.invalidate(todayBillsProvider);
      ref.invalidate(filteredBillsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(stockItemsProvider);

      if (mounted) {
        final msg = stockUpdated == _lineItems.length
            ? AppLang.tr(isEn, 'Sale saved & stock updated!', 'बिक्री सहेजी और स्टॉक अपडेट!')
            : AppLang.tr(isEn, 'Sale saved! (Stock update partial)', 'बिक्री सहेजी! (स्टॉक आंशिक अपडेट)');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSale(bool isEn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLang.tr(isEn, 'Delete Sale?', 'बिक्री हटाएं?')),
        content: Text(AppLang.tr(isEn, 'Are you sure? This will reverse stock deductions.', 'क्या आप वाकई चाहते हैं? इससे स्टॉक वापस जुड़ जाएगा।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLang.tr(isEn, 'Cancel', 'रद्द करें'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AppLang.tr(isEn, 'Delete', 'हटाएं'))
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final billId = widget.bill!.id;
      // 1. Reverse stock
      final oldSales = await SupabaseService.getSalesByBillId(billId);
      for (var os in oldSales) {
        if (os.stockItemId != null) {
          await SupabaseService.addStockById(os.stockItemId!, os.quantity);
        }
      }
      // 2. Delete data
      await SupabaseService.deleteSalesByBillId(billId);
      await SupabaseService.deleteBill(billId);

      ref.invalidate(todayBillsProvider);
      ref.invalidate(filteredBillsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(stockItemsProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLang.tr(isEn, 'Sale deleted successfully', 'बिक्री सफलतापूर्वक हटा दी गई')),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      _showError('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final stockAsync = ref.watch(stockItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // ── Header ──
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 20,
              bottom: 16),
          child: Row(children: [
            GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            Expanded(
                child: Text(
                    AppLang.tr(isEn, 
                        widget.bill != null ? 'Edit Sale' : 'New Sale Entry', 
                        widget.bill != null ? 'बिक्री एडिट करें' : 'नई बिक्री एंट्री'),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white))),
            if (widget.bill != null)
              GestureDetector(
                onTap: () {
                  // Share functionality
                  ShareService.shareBill(
                    vendorName: widget.bill!.vendorName,
                    amount: widget.bill!.amount,
                    billType: widget.bill!.billType,
                    billDate: widget.bill!.billDate,
                    notes: widget.bill!.notes,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                ),
              ),
          ]),
        ),

        // ── Body ──
        Expanded(
          child: stockAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (stockItems) => _buildForm(isEn, stockItems),
          ),
        ),
      ]),
    );
  }

  Widget _buildForm(bool isEn, List<dynamic> rawStockItems) {
    final stockItems = rawStockItems.cast<StockItemModel>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Customer Name ──
        _sectionLabel(AppLang.tr(isEn, 'Customer Name (optional)',
            'ग्राहक का नाम (वैकल्पिक)')),
        const SizedBox(height: 6),
        _textField(_customerCtrl,
            AppLang.tr(isEn, 'e.g. Ramesh Ji', 'जैसे रमेश जी')),

        const SizedBox(height: 20),

        // ── Line Items ──
        Row(children: [
          Expanded(
              child: _sectionLabel(
                  AppLang.tr(isEn, 'Sale Items', 'बिक्री आइटम'))),
          GestureDetector(
            onTap: _addLineItem,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 4),
                Text(AppLang.tr(isEn, 'Add Item', 'आइटम जोड़ें'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        ...List.generate(_lineItems.length,
            (i) => _lineItemCard(i, stockItems, isEn)),

        const SizedBox(height: 16),

        // ── Payment Mode ──
        _sectionLabel(AppLang.tr(isEn, 'Payment Mode', 'भुगतान मोड')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          _payChip('cash', AppLang.tr(isEn, 'Cash', 'नकद'), Icons.money),
          _payChip('upi', 'UPI', Icons.phone_android_rounded),
          _payChip(
              'card', AppLang.tr(isEn, 'Card', 'कार्ड'), Icons.credit_card),
        ]),

        const SizedBox(height: 16),

        // ── Notes ──
        _sectionLabel(
            AppLang.tr(isEn, 'Notes (optional)', 'नोट्स (वैकल्पिक)')),
        const SizedBox(height: 6),
        _textField(
            _notesCtrl, AppLang.tr(isEn, 'Any notes...', 'कोई नोट...'),
            maxLines: 2),

        const SizedBox(height: 20),

        // ── Grand Total ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.85)
            ]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Text(AppLang.tr(isEn, 'Grand Total', 'कुल योग'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70)),
            const Spacer(),
            Text('₹${_grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ]),
        ),

        const SizedBox(height: 16),

        if (widget.bill != null) ...[
          Center(
            child: TextButton.icon(
              onPressed: _isSaving ? null : () => _deleteSale(isEn),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(AppLang.tr(isEn, 'Delete This Sale', 'यह बिक्री हटाएं')),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── Save Button ──
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSaving
                ? null
                : () => _saveSale(ref.read(appLanguageProvider)),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_rounded, color: Colors.white),
            label: Text(
                AppLang.tr(ref.read(appLanguageProvider), 
                    widget.bill != null ? 'Update Sale' : 'Save Sale',
                    widget.bill != null ? 'बिक्री अपडेट करें' : 'बिक्री सहेजें'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _lineItemCard(int index, List<StockItemModel> stockItems, bool isEn) {
    final li = _lineItems[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(8)),
            child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary))),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  AppLang.tr(isEn, 'Item ${index + 1}', 'आइटम ${index + 1}'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary))),
          if (_lineItems.length > 1)
            GestureDetector(
              onTap: () => _removeLineItem(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.close_rounded,
                    color: AppColors.error, size: 16),
              ),
            ),
        ]),
        const SizedBox(height: 10),

        // Stock dropdown
        DropdownButtonFormField<String>(
          value: li.stockItemId,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: AppLang.tr(isEn, 'Select item', 'आइटम चुनें'),
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderBlue)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: stockItems
              .map((item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Row(children: [
                      Expanded(
                          child: Text(item.itemName,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis)),
                      Text(
                          '${item.currentQuantity.toStringAsFixed(0)} ${item.unit}',
                          style: TextStyle(
                              fontSize: 11,
                              color: item.isLowStock
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: item.isLowStock
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ]),
                  ))
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final item = stockItems.firstWhere((s) => s.id == id);
            setState(() {
              li.stockItemId = id;
              li.stockItemName = item.itemName;
              li.unit = item.unit;
              li.currentStock = item.currentQuantity;
              li.isLowStock = item.isLowStock;
              li.priceCtrl.text = item.sellingPrice.toStringAsFixed(0);
            });
          },
        ),

        // Low stock warning
        if (li.stockItemId != null && li.currentStock <= 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.block_rounded,
                    color: AppColors.error, size: 14),
                const SizedBox(width: 6),
                Text(
                    AppLang.tr(isEn, 'Out of stock!', 'स्टॉक खत्म!'),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          )
        else if (li.isLowStock)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.warning_rounded,
                    color: AppColors.warning, size: 14),
                const SizedBox(width: 6),
                Text(
                    AppLang.tr(
                        isEn,
                        'Low stock: ${li.currentStock.toStringAsFixed(0)} ${li.unit} left',
                        'कम स्टॉक: ${li.currentStock.toStringAsFixed(0)} ${li.unit} बचे'),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.warning)),
              ]),
            ),
          ),

        const SizedBox(height: 10),

        // Qty, Price, Total row
        Row(children: [
          // Qty with unit
          Expanded(
            child: TextField(
              controller: li.qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: li.stockItemId != null
                    ? '${AppLang.tr(isEn, 'Qty', 'मात्रा')} (${li.unit})'
                    : AppLang.tr(isEn, 'Qty', 'मात्रा'),
                labelStyle: const TextStyle(fontSize: 12),
                suffixText: li.stockItemId != null ? li.unit : null,
                suffixStyle: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.borderBlue)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          // Price per unit
          Expanded(
            child: TextField(
              controller: li.priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: li.stockItemId != null
                    ? '₹/${li.unit}'
                    : '₹ ${AppLang.tr(isEn, 'Price', 'मूल्य')}',
                labelStyle: const TextStyle(fontSize: 12),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.borderBlue)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          // Line Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('₹${li.lineTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success)),
          ),
        ]),
      ]),
    );
  }

  Widget _payChip(String value, String label, IconData icon) {
    final sel = _paymentMode == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 16, color: sel ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));

  Widget _textField(TextEditingController c, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderBlue)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
