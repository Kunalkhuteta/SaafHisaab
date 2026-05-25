import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/share_service.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../models/item_master_model.dart';
import '../../models/udhar_model.dart';
import '../../globalVar.dart';
import '../../widgets/credit_entry_sheet.dart';
import '../../widgets/party_name_field.dart';

/// Invoice type codes and utilities
class InvType {
  static const sin = 'sale';
  static const pin = 'purchase';
  static const srn = 'sale_return';
  static const prn = 'purchase_return';

  static String label(String type, bool isEn) {
    switch (type) {
      case sin: return AppLang.tr(isEn, 'Sales Invoice (SIN)', 'बिक्री चालान (SIN)');
      case pin: return AppLang.tr(isEn, 'Purchase Invoice (PIN)', 'खरीद चालान (PIN)');
      case srn: return AppLang.tr(isEn, 'Sales Return (SRN)', 'बिक्री वापसी (SRN)');
      case prn: return AppLang.tr(isEn, 'Purchase Return (PRN)', 'खरीद वापसी (PRN)');
      default: return type;
    }
  }

  static String shortCode(String type) {
    switch (type) {
      case sin: return 'SIN';
      case pin: return 'PIN';
      case srn: return 'SRN';
      case prn: return 'PRN';
      default: return '';
    }
  }

  static Color color(String type) {
    switch (type) {
      case sin: return AppColors.success;
      case pin: return AppColors.primary;
      case srn: return AppColors.warning;
      case prn: return AppColors.purple;
      default: return AppColors.textSecondary;
    }
  }

  static IconData icon(String type) {
    switch (type) {
      case sin: return Icons.trending_up_rounded;
      case pin: return Icons.shopping_cart_rounded;
      case srn: return Icons.assignment_return_rounded;
      case prn: return Icons.outbox_rounded;
      default: return Icons.receipt_rounded;
    }
  }

  static bool deductsStock(String type) => type == sin || type == prn;
  static bool addsStock(String type) => type == pin || type == srn;
}

class _SaleLineItem {
  String? stockItemId;
  String? originalStockItemId;
  double originalQty = 0;
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
  final String billType;
  const SaleEntryScreen({super.key, this.bill, this.billType = 'sale'});
  @override
  ConsumerState<SaleEntryScreen> createState() => _SaleEntryScreenState();
}

class _SaleEntryScreenState extends ConsumerState<SaleEntryScreen> {
  final _customerCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_SaleLineItem> _lineItems = [_SaleLineItem()];
  String _paymentMode = 'cash';
  bool _isSaving = false;
  SavedCreditSale? _creditSale;
  SavedCreditSale? _originalCreditSale;

  double get _grandTotal {
    if ((_paymentMode == 'credit' || _paymentMode == 'split') && _creditSale != null) {
      return _creditSale!.totalAmount;
    }
    return _lineItems.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  String get _billType => widget.bill?.billType ?? widget.billType;
  bool get _deductsStock => InvType.deductsStock(_billType);
  bool get _addsStock => InvType.addsStock(_billType);
  Color get _typeColor => InvType.color(_billType);
  String get _typeCode => InvType.shortCode(_billType);

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
            item.originalStockItemId = s.stockItemId;
            item.originalQty = s.quantity;
            item.unit = s.unit;
            item.qtyCtrl.text = s.quantity.toString();
            item.priceCtrl.text = s.sellingPrice.toString();
            _lineItems.add(item);
          }
        });
        
        // Refresh current stock for these items
        final stockItems = await ref.read(itemMasterProvider.future);
        setState(() {
          for (var li in _lineItems) {
            final si = stockItems.firstWhere(
              (element) => element.id == li.stockItemId, 
              orElse: () => ItemMasterModel(
                id: '', 
                shopId: '', 
                userId: '', 
                itemName: '', 
                currentStock: 0, 
                createdAt: DateTime.now(),
              )
            );
            li.currentStock = si.currentStock;
          }
        });

        if (_paymentMode == 'credit' || _paymentMode == 'split') {
          await _loadCreditSaleForExistingBill(widget.bill!.vendorName, '');
        }
      }
    } catch (e) {
      debugPrint('Error loading existing sale: $e');
    }
  }

  Future<void> _loadCreditSaleForExistingBill(String customerName, String customerPhone) async {
    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) return;
      UdharCustomerModel? customer = await SupabaseService.findCustomerByName(shop.id, customerName);
      customer ??= await SupabaseService.findCustomerByPhone(shop.id, customerPhone);
      if (customer == null) return;

      final entries = await SupabaseService.getUdharEntriesForCustomer(customer.id);
      for (final entry in entries) {
        if (entry.entryType == 'credit') {
          final parsed = SavedCreditSale.tryParseNote(entry.note, customerId: customer.id);
          if (parsed != null) {
            bool isMatch = false;
            final markerIndex = entry.note.indexOf(SavedCreditSale.noteMarker);
            if (markerIndex >= 0) {
              final jsonText = entry.note.substring(markerIndex + SavedCreditSale.noteMarker.length).trim();
              try {
                final payload = jsonDecode(jsonText) as Map<String, dynamic>;
                final String? noteBillId = payload['billId'] as String?;
                if (noteBillId != null) {
                  isMatch = noteBillId == widget.bill!.id;
                } else {
                  // Backward compatibility: match by amount and date close to bill date
                  final timeDiff = entry.entryDate.difference(widget.bill!.billDate).abs();
                  isMatch = (parsed.totalAmount - widget.bill!.amount).abs() < 1.0 && timeDiff.inMinutes < 60;
                }
              } catch (_) {
                final timeDiff = entry.entryDate.difference(widget.bill!.billDate).abs();
                isMatch = (parsed.totalAmount - widget.bill!.amount).abs() < 1.0 && timeDiff.inMinutes < 60;
              }
            }

            if (isMatch) {
              String? debitEntryId;
              if (parsed.advancePaid > 0) {
                try {
                  final debits = entries.where((e) =>
                      e.entryType == 'debit' &&
                      e.amount == parsed.advancePaid &&
                      e.entryDate.difference(entry.entryDate).abs().inDays <= 1);
                  if (debits.isNotEmpty) {
                    debitEntryId = debits.first.id;
                  }
                } catch (_) {}
              }

              setState(() {
                final updatedCreditSale = SavedCreditSale(
                  customerId: parsed.customerId,
                  customerName: parsed.customerName,
                  customerPhone: parsed.customerPhone,
                  creditAmount: parsed.creditAmount,
                  advancePaid: parsed.advancePaid,
                  totalAmount: parsed.totalAmount,
                  dueDate: parsed.dueDate,
                  note: parsed.note,
                  items: parsed.items,
                  creditEntryId: entry.id,
                  debitEntryId: debitEntryId,
                );
                _creditSale = updatedCreditSale;
                _originalCreditSale = updatedCreditSale;
                _customerPhoneCtrl.text = parsed.customerPhone;
              });
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading credit sale for existing bill: $e');
    }
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _customerPhoneCtrl.dispose();
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

  Future<void> _showMissingCustomerAlert(bool isEn) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLang.tr(
          isEn,
          'Customer name required',
          'ग्राहक का नाम आवश्यक है',
        )),
        content: Text(AppLang.tr(
          isEn,
          'Please enter the customer name before saving.',
          'सेव करने से पहले ग्राहक का नाम दर्ज करें।',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLang.tr(isEn, 'OK', 'ठीक है')),
          ),
        ],
      ),
    );
  }

  Future<void> _syncDailyBalancesForBillDates(
    String shopId,
    Iterable<DateTime> dates,
  ) async {
    final seen = <String>{};
    for (final date in dates) {
      final key = '${date.year}-${date.month}';
      if (!seen.add(key)) continue;
      try {
        await SupabaseService.syncAndGetDailyBalances(
          shopId,
          date.month,
          date.year,
        );
      } catch (e) {
        debugPrint('Daily balance sync failed: $e');
      }
    }
  }

  String _saleNotesForPersistence() {
    final baseNotes = _notesCtrl.text.trim();
    if (_creditSale == null) return baseNotes;
    final marker =
        '__saafhisaab_credit_advance:${_creditSale!.advancePaid};credit:${_creditSale!.creditAmount}__';
    return baseNotes.isEmpty ? marker : '$baseNotes\n$marker';
  }

  Future<SavedCreditSale?> _persistCreditOnBillSave({
    required String shopId,
    required String userId,
    required bool isEn,
    String? billId,
  }) async {
    final credit = _creditSale;
    if (credit == null || credit.creditAmount <= 0) return null;

    UdharCustomerModel? customer;
    UdharCustomerModel? createdCustomer;
    UdharEntryModel? creditEntry;
    UdharEntryModel? debitEntry;
    double? oldDue;

    try {
      if (credit.customerId.isNotEmpty) {
        oldDue = await SupabaseService.getCustomerTotalDue(credit.customerId);
        customer = UdharCustomerModel(
          id: credit.customerId,
          shopId: shopId,
          userId: userId,
          customerName: credit.customerName,
          customerPhone: credit.customerPhone,
          totalDue: oldDue,
          createdAt: DateTime.now(),
        );
      } else {
        customer = await SupabaseService.findCustomerByName(shopId, credit.customerName);
        customer ??= await SupabaseService.findCustomerByPhone(shopId, credit.customerPhone);
        if (customer == null) {
          customer = await SupabaseService.createUdharCustomer(
            shopId: shopId,
            userId: userId,
            customerName: credit.customerName,
            phone: credit.customerPhone,
          );
          createdCustomer = customer;
        }
        oldDue = await SupabaseService.getCustomerTotalDue(customer.id);
      }

      creditEntry = await SupabaseService.addCreditEntry(
        shopId: shopId,
        userId: userId,
        customerId: customer.id,
        amount: credit.creditAmount,
        note: credit.toEntryNote(billId: billId),
      );

      if (credit.advancePaid > 0) {
        debitEntry = await SupabaseService.addDebitEntry(
          shopId: shopId,
          userId: userId,
          customerId: customer.id,
          amount: credit.advancePaid,
          note: SupabaseService.creditSaleAdvanceNote,
        );
      }

      await SupabaseService.updateCustomerTotalDue(
        customer.id,
        (oldDue ?? 0) + credit.creditAmount,
      );

      return SavedCreditSale(
        customerId: customer.id,
        customerName: credit.customerName,
        customerPhone: credit.customerPhone,
        creditAmount: credit.creditAmount,
        advancePaid: credit.advancePaid,
        totalAmount: credit.totalAmount,
        dueDate: credit.dueDate,
        note: credit.note,
        items: credit.items,
        creditEntryId: creditEntry.id,
        debitEntryId: debitEntry?.id,
      );
    } catch (e) {
      if (creditEntry != null) await SupabaseService.deleteUdharEntry(creditEntry.id);
      if (debitEntry != null) await SupabaseService.deleteUdharEntry(debitEntry.id);
      if (customer != null && oldDue != null) {
        await SupabaseService.updateCustomerTotalDue(customer.id, oldDue);
      }
      if (createdCustomer != null) {
        await SupabaseService.deleteUdharCustomer(createdCustomer.id);
      }
      throw Exception(AppLang.tr(isEn, 'Credit save failed', 'क्रेडिट सेव नहीं हुआ'));
    }
  }

  Future<void> _openCreditSheet(bool isEn, List<ItemMasterModel> stockItems) async {
    final userId = AuthService.currentUserId;
    final shop = await ref.read(shopProvider.future);
    if (userId == null || shop == null) {
      _showError(AppLang.tr(isEn, 'Shop not found', 'दुकान नहीं मिली'));
      return;
    }

    final result = await showModalBottomSheet<SavedCreditSale>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => CreditEntrySheet(
        shopId: shop.id,
        userId: userId,
        isEn: isEn,
        initialCustomerName: _customerCtrl.text.trim(),
        initialCustomerPhone: _customerPhoneCtrl.text.trim(),
        initialTotal: _grandTotal,
        stockItems: stockItems,
        existingCredit: _creditSale,
      ),
    );

    if (result == null) return;
    setState(() {
      _creditSale = result.creditAmount > 0 ? result : null;
      _customerCtrl.text = result.customerName;
      _customerPhoneCtrl.text = result.customerPhone;
      _paymentMode = result.creditAmount > 0
          ? (result.advancePaid > 0 ? 'split' : 'credit')
          : 'cash';
    });
    ref.invalidate(udharCustomersProvider);
    ref.invalidate(dashboardStatsProvider);
  }


  Future<void> _selectPaymentMode(
      String value, bool isEn, List<ItemMasterModel> stockItems) async {
    if (value == 'credit') {
      await _openCreditSheet(isEn, stockItems);
      return;
    }
    if ((_paymentMode == 'credit' || _paymentMode == 'split') &&
        _creditSale != null) {
      final remove = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLang.tr(isEn, 'Remove credit entry?', 'क्रेडिट एंट्री हटाएं?')),
          content: Text(AppLang.tr(isEn, 'This will clear credit data from this invoice.', 'इस इनवॉइस से क्रेडिट विवरण हट जाएगा।')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLang.tr(isEn, 'No', 'नहीं')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLang.tr(isEn, 'Yes', 'हाँ')),
            ),
          ],
        ),
      );
      if (remove != true) return;
      setState(() => _creditSale = null);
    }
    setState(() => _paymentMode = value);
  }

  Future<void> _saveSale(bool isEn) async {
    if (_customerCtrl.text.trim().isEmpty) {
      await _showMissingCustomerAlert(isEn);
      return;
    }

    final bool isCreditSale = (_paymentMode == 'credit' || _paymentMode == 'split') && _creditSale != null;
    final itemsToSave = <_SaleLineItem>[];

    try {
      final stockItems = await ref.read(itemMasterProvider.future);
      if (isCreditSale) {
        for (final ci in _creditSale!.items) {
          final li = _SaleLineItem();
          li.stockItemId = ci.stockItemId;
          li.originalStockItemId = ci.stockItemId;
          li.stockItemName = ci.itemName;
          li.unit = ci.unit;
          li.qtyCtrl.text = ci.quantity.toString();
          final price = ci.quantity == 0 ? ci.amount : ci.amount / ci.quantity;
          li.priceCtrl.text = price.toString();

          final si = stockItems.firstWhere(
            (element) => element.id == li.stockItemId,
            orElse: () => ItemMasterModel(
              id: '',
              shopId: '',
              userId: '',
              itemName: '',
              currentStock: 0,
              createdAt: DateTime.now(),
            ),
          );
          li.currentStock = si.currentStock;

          if (widget.bill != null) {
            try {
              final oldSales = await SupabaseService.getSalesByBillId(widget.bill!.id);
              final match = oldSales.firstWhere(
                (os) => os.stockItemId == li.stockItemId,
                orElse: () => SaleModel(
                  id: '',
                  shopId: '',
                  userId: '',
                  itemName: '',
                  quantity: 0,
                  unit: '',
                  sellingPrice: 0,
                  totalAmount: 0,
                  paymentMode: '',
                  saleDate: DateTime.now(),
                  createdAt: DateTime.now(),
                ),
              );
              li.originalQty = match.quantity;
            } catch (_) {}
          }
          itemsToSave.add(li);
        }
      } else {
        itemsToSave.addAll(_lineItems);
      }
    } catch (e) {
      _showError('Failed to prepare items: $e');
      return;
    }

    // ── Validate ──
    for (int i = 0; i < itemsToSave.length; i++) {
      final li = itemsToSave[i];
      if (li.stockItemName.trim().isEmpty) {
        _showError(AppLang.tr(isEn, 'Select item for row ${i + 1}',
            'पंक्ति ${i + 1} के लिए आइटम चुनें'));
        return;
      }
      if (li.quantity <= 0) {
        _showError(AppLang.tr(isEn, 'Qty must be > 0 for ${li.stockItemName}',
            '${li.stockItemName} की मात्रा 0 से अधिक होनी चाहिए'));
        return;
      }
      if (li.unitPrice <= 0) {
        _showError(AppLang.tr(isEn, 'Price/Amount must be > 0 for ${li.stockItemName}',
            '${li.stockItemName} का मूल्य 0 से अधिक होना चाहिए'));
        return;
      }
      double availableStock = li.currentStock;
      if (widget.bill != null && li.stockItemId != null && li.stockItemId == li.originalStockItemId) {
        availableStock += li.originalQty;
      }

      if (li.stockItemId != null && _deductsStock && li.quantity > availableStock) {
        _showError(AppLang.tr(
            isEn,
            'Insufficient stock for ${li.stockItemName}! Available: ${availableStock.toStringAsFixed(0)} ${li.unit}',
            '${li.stockItemName} का स्टॉक कम! उपलब्ध: ${availableStock.toStringAsFixed(0)} ${li.unit}'));
        return;
      }
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    final deductedItems = <_SaleLineItem>[];
    var oldSales = <SaleModel>[];
    String? createdBillId;

    try {
      final userId = AuthService.currentUserId;
      final shop = await ref.read(shopProvider.future);
      if (userId == null || shop == null) throw Exception('Not found');

      String billId;
      if (widget.bill != null) {
        // UPDATE MODE
        billId = widget.bill!.id;
        
        // 1. Reverse old stock operations
        oldSales = await SupabaseService.getSalesByBillId(billId);
        for (var os in oldSales) {
          if (os.stockItemId != null) {
            if (_deductsStock) {
              await SupabaseService.addMasterStockById(os.stockItemId!, os.quantity);
            } else if (_addsStock) {
              await SupabaseService.deductMasterStockById(os.stockItemId!, os.quantity);
            }
          }
        }

        // 2. Apply new stock operations
        for (final li in itemsToSave) {
          bool ok = true;
          if (li.stockItemId == null) {
            ok = true;
          } else if (_deductsStock) {
            ok = await SupabaseService.deductMasterStockById(li.stockItemId!, li.quantity);
          } else if (_addsStock) {
            ok = await SupabaseService.addMasterStockById(li.stockItemId!, li.quantity);
          }
          
          if (!ok) {
            throw StockUnavailableException(AppLang.tr(isEn,
              'Stock operation failed for ${li.stockItemName}',
              '${li.stockItemName} के लिए स्टॉक ऑपरेशन विफल'));
          }
          if (li.stockItemId != null) deductedItems.add(li);
        }

        // 3. Update Bill
        await SupabaseService.updateBill(billId, 
          amount: _grandTotal, 
          vendorName: _customerCtrl.text.trim(), 
          notes: _notesCtrl.text.trim()
        );

        // 4. Delete old sale items
        await SupabaseService.deleteSalesByBillId(billId);
      } else {
        // NEW MODE
        for (final li in itemsToSave) {
          bool ok = true;
          if (li.stockItemId == null) {
            ok = true;
          } else if (_deductsStock) {
            ok = await SupabaseService.deductMasterStockById(li.stockItemId!, li.quantity);
          } else if (_addsStock) {
            ok = await SupabaseService.addMasterStockById(li.stockItemId!, li.quantity);
          }
          
          if (!ok) {
            throw StockUnavailableException(AppLang.tr(isEn,
              'Stock operation failed for ${li.stockItemName}',
              '${li.stockItemName} के लिए स्टॉक ऑपरेशन विफल'));
          }
          if (li.stockItemId != null) deductedItems.add(li);
        }

        // 1. Save BillModel and get its unique ID
        billId = await SupabaseService.saveBillGetId(BillModel(
          id: '',
          shopId: shop.id,
          userId: userId,
          amount: _grandTotal,
          billDate: DateTime.now(),
          vendorName: _customerCtrl.text.trim(),
          billType: _billType,
          notes: _notesCtrl.text.trim(),
          createdAt: DateTime.now(),
        ));
        createdBillId = billId;
      }

      // 4. Save individual SaleModel records linked to the bill + deduct stock
      int stockUpdated = 0;
      for (final li in itemsToSave) {
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
          saleDate: widget.bill?.billDate ?? DateTime.now(),
          notes: _saleNotesForPersistence(),
          createdAt: DateTime.now(),
          stockItemId: li.stockItemId,
        ));

        stockUpdated++;
      }

      // Reverse previous credit entries if they existed (in Update Mode)
      if (widget.bill != null && _originalCreditSale != null) {
        final orig = _originalCreditSale!;
        if (orig.creditEntryId != null) {
          await SupabaseService.deleteUdharEntry(orig.creditEntryId!);
        }
        if (orig.debitEntryId != null) {
          await SupabaseService.deleteUdharEntry(orig.debitEntryId!);
        }
        if (orig.customerId.isNotEmpty) {
          final oldDue = await SupabaseService.getCustomerTotalDue(orig.customerId);
          await SupabaseService.updateCustomerTotalDue(orig.customerId, oldDue - orig.creditAmount);
        }
      }

      // Persist new credit entries if current payment mode is credit or split
      final persistedCredit = await _persistCreditOnBillSave(
        shopId: shop.id,
        userId: userId,
        isEn: isEn,
        billId: billId,
      );
      if (persistedCredit != null) {
        _creditSale = persistedCredit;
      }

      await _syncDailyBalancesForBillDates(
        shop.id,
        [widget.bill?.billDate ?? DateTime.now(), DateTime.now()],
      );

      ref.invalidate(todayBillsProvider);
      ref.invalidate(filteredBillsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(itemMasterProvider);
      ref.invalidate(stockItemsProvider);
      ref.invalidate(udharCustomersProvider);

      if (mounted) {
        final msg = _creditSale != null ? AppLang.tr(isEn, 'Sale saved! Credit Rs ${_creditSale!.creditAmount.toStringAsFixed(0)} added for ${_creditSale!.customerName}', 'बिक्री सेव हुई! ${_creditSale!.customerName} के नाम Rs ${_creditSale!.creditAmount.toStringAsFixed(0)} उधार जोड़ा गया') : stockUpdated == itemsToSave.length
            ? AppLang.tr(isEn, '$_typeCode saved & stock updated!', '$_typeCode सहेजा और स्टॉक अपडेट!')
            : AppLang.tr(isEn, '$_typeCode saved!', '$_typeCode सहेजा!');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      for (final li in deductedItems.reversed) {
        if (_deductsStock) {
          await SupabaseService.addMasterStockById(li.stockItemId!, li.quantity);
        } else if (_addsStock) {
          await SupabaseService.deductMasterStockById(li.stockItemId!, li.quantity);
        }
      }
      if (widget.bill != null) {
        for (final os in oldSales) {
          if (os.stockItemId != null) {
            if (_deductsStock) {
              await SupabaseService.deductMasterStockById(os.stockItemId!, os.quantity);
            } else if (_addsStock) {
              await SupabaseService.addMasterStockById(os.stockItemId!, os.quantity);
            }
          }
        }
      } else if (createdBillId != null && createdBillId!.isNotEmpty) {
        await SupabaseService.deleteSalesByBillId(createdBillId!);
        await SupabaseService.deleteBill(createdBillId!);
      }
      _showError(e is StockUnavailableException ? e.message : 'Save failed: $e');
    } finally {
      if (isCreditSale) {
        for (final li in itemsToSave) {
          li.dispose();
        }
      }
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSale(bool isEn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLang.tr(isEn, 'Delete $_typeCode?', '$_typeCode हटाएं?')),
        content: Text(AppLang.tr(isEn, 'Are you sure? This will reverse stock operations.', 'क्या आप वाकई चाहते हैं? इससे स्टॉक वापस जुड़/घट जाएगा।')),
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
      final shop = await ref.read(shopProvider.future);
      if (shop == null) throw Exception('Shop not found');
      final billId = widget.bill!.id;
      // 1. Reverse stock
      final oldSales = await SupabaseService.getSalesByBillId(billId);
      for (var os in oldSales) {
        if (os.stockItemId != null) {
          if (_deductsStock) {
            await SupabaseService.addMasterStockById(os.stockItemId!, os.quantity);
          } else if (_addsStock) {
            await SupabaseService.deductMasterStockById(os.stockItemId!, os.quantity);
          }
        }
      }

      // Reverse credit entry if existed
      if (_originalCreditSale != null) {
        final orig = _originalCreditSale!;
        if (orig.creditEntryId != null) {
          await SupabaseService.deleteUdharEntry(orig.creditEntryId!);
        }
        if (orig.debitEntryId != null) {
          await SupabaseService.deleteUdharEntry(orig.debitEntryId!);
        }
        if (orig.customerId.isNotEmpty) {
          final oldDue = await SupabaseService.getCustomerTotalDue(orig.customerId);
          await SupabaseService.updateCustomerTotalDue(orig.customerId, oldDue - orig.creditAmount);
        }
      }

      // 2. Delete data
      await SupabaseService.deleteSalesByBillId(billId);
      await SupabaseService.deleteBill(billId);
      await _syncDailyBalancesForBillDates(shop.id, [widget.bill!.billDate]);

      ref.invalidate(todayBillsProvider);
      ref.invalidate(filteredBillsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(itemMasterProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLang.tr(isEn, '$_typeCode deleted successfully', '$_typeCode सफलतापूर्वक हटा दिया गया')),
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
    final stockAsync = ref.watch(itemMasterProvider);
    final shopAsync = ref.watch(shopProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // ── Header ──
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_typeColor, _typeColor.withOpacity(0.8)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.bill != null
                        ? AppLang.tr(isEn, 'Edit $_typeCode', '$_typeCode एडिट करें')
                        : AppLang.tr(isEn, 'New $_typeCode Entry', 'नई $_typeCode एंट्री'),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      InvType.label(_billType, isEn),
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_typeCode, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5,
              )),
            ),
            if (widget.bill != null) ...[
              const SizedBox(width: 8),
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
            ],
          ]),
        ),

        // ── Body ──
        Expanded(
          child: stockAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (stockItems) => shopAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (shop) => shop == null
                  ? const Center(child: Text('Shop not found'))
                  : _buildForm(isEn, stockItems, shop.id),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildForm(bool isEn, List<dynamic> rawStockItems, String shopId) {
    final stockItems = rawStockItems.cast<ItemMasterModel>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Customer Name ──
        _sectionLabel(AppLang.tr(isEn, 'Customer Name *', 'ग्राहक का नाम *')),
        const SizedBox(height: 6),
        if (_billType == 'purchase' || _billType == 'purchase_return')
          ref.watch(purchasePartiesProvider).when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
            error: (e, _) => Text('Error: $e'),
            data: (parties) => DropdownButtonFormField<String>(
              value: _customerCtrl.text.isNotEmpty && parties.any((p) => p['name'] == _customerCtrl.text) ? _customerCtrl.text : null,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: AppLang.tr(isEn, 'Select Party', 'पार्टी चुनें'),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: parties.map((p) => DropdownMenuItem<String>(
                value: p['name'] as String,
                child: Text(p['name'] as String, style: const TextStyle(fontSize: 15)),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _customerCtrl.text = val);
                }
              },
            ),
          )
        else if (false)
          _textField(_customerCtrl, AppLang.tr(isEn, 'e.g. Ramesh Ji', 'जैसे रमेश जी')),

        if (!(_billType == 'purchase' || _billType == 'purchase_return'))
          PartyNameField(
          shopId: shopId,
          controller: _customerCtrl,
          phoneController: _customerPhoneCtrl,
          isEn: isEn,
          label: AppLang.tr(isEn, 'Customer Name', 'ग्राहक का नाम'),
          hint: AppLang.tr(isEn, 'e.g. Ramesh Ji', 'जैसे रमेश जी'),
          required: true,
          onCustomerSelected: (_) => setState(() {}),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 20),

        if (_creditSale == null) ...[
          // ── Line Items ──
          Row(children: [
            Expanded(
                child: _sectionLabel(
                    AppLang.tr(isEn, '$_typeCode Items', '$_typeCode आइटम'))),
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
        ],

        if (_billType == 'sale') ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _creditPayChip(isEn, stockItems),
          ]),
        ],

        if (_billType == 'sale' && _customerCtrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _creditActionCard(isEn, stockItems),
        ],

        if (_creditSale != null) ...[
          const SizedBox(height: 10),
          _creditSummaryCard(isEn, stockItems),
        ],

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
              _typeColor,
              _typeColor.withOpacity(0.85)
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
              label: Text(AppLang.tr(isEn, 'Delete This $_typeCode', 'यह $_typeCode हटाएं')),
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
                widget.bill != null
                    ? AppLang.tr(isEn, 'Update $_typeCode', '$_typeCode अपडेट करें')
                    : AppLang.tr(isEn, 'Save $_typeCode', '$_typeCode सहेजें'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _typeColor,
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

  Widget _creditPayChip(bool isEn, List<ItemMasterModel> stockItems) {
    final selected = _paymentMode == 'credit' || _paymentMode == 'split';
    return GestureDetector(
      onTap: () => _openCreditSheet(isEn, stockItems),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.success : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.success : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 16, color: selected ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            selected ? AppLang.tr(isEn, 'Credit ✓', 'उधार ✓') : AppLang.tr(isEn, 'Credit', 'उधार'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _creditActionCard(bool isEn, List<ItemMasterModel> stockItems) {
    final hasCredit = _creditSale != null;
    return InkWell(
      onTap: () => _openCreditSheet(isEn, stockItems),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasCredit ? AppColors.success.withOpacity(0.12) : AppColors.primaryBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCredit ? AppColors.success.withOpacity(0.35) : AppColors.primaryBorder,
          ),
        ),
        child: Row(children: [
          Icon(
            hasCredit ? Icons.check_circle_rounded : Icons.add_rounded,
            color: hasCredit ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasCredit
                  ? AppLang.tr(isEn, 'Credit: Rs ${_creditSale!.creditAmount.toStringAsFixed(0)} added', 'उधार: Rs ${_creditSale!.creditAmount.toStringAsFixed(0)} जोड़ा गया')
                  : AppLang.tr(isEn, '+ Add Credit', '+ उधार जोड़ें'),
              style: TextStyle(
                color: hasCredit ? AppColors.success : AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _creditSummaryCard(bool isEn, List<ItemMasterModel> stockItems) {
    final credit = _creditSale!;
    final due = credit.dueDate == null
        ? '-'
        : credit.dueDate!.toIso8601String().split('T')[0];
    return InkWell(
      onTap: () => _openCreditSheet(isEn, stockItems),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row with credit amount and customer
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.warning,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    credit.customerName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLang.tr(isEn, 'Due: $due', 'देय: $due'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs ${credit.creditAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (credit.advancePaid > 0)
                  Text(
                    AppLang.tr(isEn, '+ Rs ${credit.advancePaid.toStringAsFixed(0)} paid', '+ Rs ${credit.advancePaid.toStringAsFixed(0)} दिया'),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ]),

          // Items breakdown
          if (credit.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLang.tr(isEn, 'Items', 'आइटम'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...credit.items.map((item) {
                    final rate = item.quantity > 0 ? (item.amount / item.quantity) : item.amount;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.itemName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit} x ₹${rate.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${item.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLang.tr(isEn, 'Tap card to edit credit items', 'क्रेडिट आइटम बदलने के लिए टैप करें'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Split payment info
          if (credit.advancePaid > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppLang.tr(isEn, 'Split: Rs ${credit.advancePaid.toStringAsFixed(0)} Cash + Rs ${credit.creditAmount.toStringAsFixed(0)} Credit', 'स्प्लिट: Rs ${credit.advancePaid.toStringAsFixed(0)} नकद + Rs ${credit.creditAmount.toStringAsFixed(0)} उधार'),
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],

          // Tap to edit hint
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.edit_outlined, size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                AppLang.tr(isEn, 'Tap to edit', 'एडिट करने के लिए दबाएं'),
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Future<void> _changePaymentModeBasic(String value) async {
    if ((_paymentMode == 'credit' || _paymentMode == 'split') && _creditSale != null) {
      final isEn = ref.read(appLanguageProvider);
      final remove = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLang.tr(isEn, 'Remove credit entry?', 'क्रेडिट एंट्री हटाएं?')),
          content: Text(AppLang.tr(isEn, 'Clear credit data from this invoice?', 'इस इनवॉइस से क्रेडिट विवरण हटाएं?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLang.tr(isEn, 'No', 'नहीं'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLang.tr(isEn, 'Yes', 'हाँ'))),
          ],
        ),
      );
      if (remove != true) return;
      _creditSale = null;
    }
    if (mounted) setState(() => _paymentMode = value);
  }

  Widget _lineItemCard(int index, List<ItemMasterModel> stockItems, bool isEn) {
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
        if (li.stockItemId == null && li.stockItemName.trim().isNotEmpty)
          TextField(
            controller: TextEditingController(text: li.stockItemName),
            onChanged: (value) => li.stockItemName = value,
            decoration: InputDecoration(
              hintText: AppLang.tr(isEn, 'Item name', 'Item name'),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderBlue)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          )
        else
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
                          '${item.currentStock.toStringAsFixed(0)} piece',
                          style: TextStyle(
                              fontSize: 11,
                              color: item.currentStock <= 5
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: item.currentStock <= 5
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
              li.unit = 'piece';
              li.currentStock = item.currentStock;
              li.isLowStock = item.currentStock <= 5;
              if (li.priceCtrl.text.isEmpty || li.priceCtrl.text == '0') {
                li.priceCtrl.text = '0'; // No selling price in Master Item
              }
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
      onTap: () => _changePaymentModeBasic(value),
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
