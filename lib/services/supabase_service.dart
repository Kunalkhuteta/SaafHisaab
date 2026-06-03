import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';
import '../models/bill_model.dart';
import '../models/sale_model.dart';
import '../models/stock_model.dart';
import '../models/item_master_model.dart';
import '../models/udhar_model.dart';
import '../models/daily_balance_model.dart';
import '../models/ledger_row_model.dart';
import 'dart:typed_data';

class StockUnavailableException implements Exception {
  final String message;

  const StockUnavailableException(this.message);

  @override
  String toString() => message;
}

class SupabaseService {

  // Use getter so it's always fresh
  static SupabaseClient get _client => Supabase.instance.client;
  static const creditSaleAdvanceNote = 'Advance payment on credit sale';
  static const saleReturnUdharReductionNote = 'Sale return - udhar reduced';
  static const adjustmentAmountColumn = 'tobeadjustAmount';
  static const adjustmentAmountFallbackColumn = 'tobeadjust_amount';
  static const saleAdjustmentNoteMarker = '__saafhisaab_sale_adjustment_v1__';

  static double _creditAdvanceFromNotes(String notes) {
    final match = RegExp(r'__saafhisaab_credit_advance:([0-9.]+);credit:([0-9.]+)__')
        .firstMatch(notes);
    if (match == null) return 0;
    return double.tryParse(match.group(1) ?? '') ?? 0;
  }

  static double saleAdjustmentFromNotes(String notes) {
    final markerIndex = notes.indexOf(saleAdjustmentNoteMarker);
    if (markerIndex < 0) return 0;
    final raw = notes.substring(markerIndex + saleAdjustmentNoteMarker.length).trim();
    final match = RegExp(r'"adjustedAmount"\s*:\s*([0-9.]+)').firstMatch(raw);
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static String saleAdjustmentNote({
    required double adjustedAmount,
    required double grossAmount,
    required double paidAmount,
    required double remainingAdjustment,
  }) {
    return '$saleAdjustmentNoteMarker{"adjustedAmount":$adjustedAmount,"grossAmount":$grossAmount,"paidAmount":$paidAmount,"remainingAdjustment":$remainingAdjustment}';
  }

  static Future<void> _trySyncDailyBalancesForDate(
    String shopId,
    DateTime date,
  ) async {
    try {
      await syncAndGetDailyBalances(shopId, date.month, date.year);
    } catch (e) {
      debugPrint('Daily balance sync failed: $e');
    }
  }

  // ─────────────────────────────────────────
  // SHOP
  // ─────────────────────────────────────────

  static Future<bool> shopExists(String userId) async {
    final response = await _client
        .from('shops')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return response != null;
  }

  static Future<ShopModel> saveShop({
    required String userId,
    required String ownerName,
    required String shopName,
    required String city,
    required String shopType,
    required String phone,
    String gstNumber = '',
  }) async {
    final data = await _client
        .from('shops')
        .insert({
          'user_id': userId,
          'owner_name': ownerName,
          'shop_name': shopName,
          'city': city,
          'shop_type': shopType,
          'phone': phone,
          'gst_number': gstNumber,
        })
        .select()
        .single();
    return ShopModel.fromJson(data);
  }

  static Future<ShopModel?> getShop(String userId) async {
    final data = await _client
        .from('shops')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return ShopModel.fromJson(data);
  }

  static Future<void> updateShop(
      String shopId, Map<String, dynamic> updates) async {
    await _client
        .from('shops')
        .update({
          ...updates,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', shopId);
  }

  static Future<void> saveFcmToken(String userId, String token) async {
    await _client
        .from('shops')
        .update({'fcm_token': token})
        .eq('user_id', userId);
  }

  // ─────────────────────────────────────────
  // BILLS
  // ─────────────────────────────────────────

  static Future<void> saveBill(BillModel bill) async {
    await _client.from('bills').insert(bill.toJson());
  }

  /// Insert bill and return its generated ID
  static Future<String> saveBillGetId(BillModel bill) async {
    await _client.from('bills').insert(bill.toJson());
    // Query the bill we just created (most recent for this user)
    final data = await _client
        .from('bills')
        .select('id')
        .eq('shop_id', bill.shopId)
        .eq('user_id', bill.userId)
        .order('created_at', ascending: false)
        .limit(1);
    if ((data as List).isNotEmpty) {
      return data.first['id'] as String;
    }
    return '';
  }

  /// Get sales linked to a specific bill
  static Future<List<SaleModel>> getSalesByBillId(String billId) async {
    final data = await _client
        .from('sales')
        .select()
        .eq('bill_id', billId)
        .order('created_at');
    return (data as List).map((s) => SaleModel.fromJson(s)).toList();
  }

  static Future<List<BillModel>> getSaleBillsForCustomer(
    String shopId,
    String customerName, {
    DateTime? from,
    DateTime? to,
  }) async {
    var request = _client
        .from('bills')
        .select()
        .eq('shop_id', shopId)
        .eq('bill_type', 'sale')
        .ilike('vendor_name', '%${customerName.trim()}%');

    if (from != null) {
      request = request.gte('bill_date', from.toIso8601String().split('T')[0]);
    }
    if (to != null) {
      request = request.lte('bill_date', to.toIso8601String().split('T')[0]);
    }

    final data = await request
        .order('bill_date', ascending: false)
        .order('created_at', ascending: false);
    return (data as List).map((b) => BillModel.fromJson(b)).toList();
  }

  static Future<List<Map<String, dynamic>>> searchSaleCustomers(
    String shopId,
    String query,
  ) async {
    final trimmed = query.trim();
    var request = _client
        .from('bills')
        .select('vendor_name')
        .eq('shop_id', shopId)
        .eq('bill_type', 'sale')
        .neq('vendor_name', '');

    final data = trimmed.isEmpty
        ? await request.order('vendor_name').limit(50)
        : await request
            .ilike('vendor_name', '%$trimmed%')
            .order('vendor_name')
            .limit(50);

    final names = <String, Map<String, dynamic>>{};
    for (final row in data as List) {
      final name = (row['vendor_name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      names.putIfAbsent(name.toLowerCase(), () => {
            'name': name,
            'phone': '',
            'total_due': 0.0,
            'source': 'cash',
          });
    }
    return names.values.toList();
  }

  static Future<List<SaleModel>> getReturnSalesForBill(String referenceBillId) async {
    final data = await _client
        .from('sales')
        .select()
        .lt('quantity', 0)
        .ilike('notes', '%__saafhisaab_return_ref:$referenceBillId%')
        .order('created_at');
    return (data as List).map((s) => SaleModel.fromJson(s)).toList();
  }

  static Future<List<BillModel>> getTodayBills(String shopId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await _client
        .from('bills')
        .select()
        .eq('shop_id', shopId)
        .eq('bill_date', today)
        .order('created_at', ascending: false);
    return (data as List).map((b) => BillModel.fromJson(b)).toList();
  }

  static Future<List<BillModel>> getBills(
      String shopId, DateTime from, DateTime to) async {
    final data = await _client
        .from('bills')
        .select()
        .eq('shop_id', shopId)
        .gte('bill_date', from.toIso8601String().split('T')[0])
        .lte('bill_date', to.toIso8601String().split('T')[0])
        .order('created_at', ascending: false);
    return (data as List).map((b) => BillModel.fromJson(b)).toList();
  }

  static Future<BillModel?> getBillById(String billId) async {
    final data = await _client
        .from('bills')
        .select()
        .eq('id', billId)
        .limit(1);
    final rows = data as List;
    if (rows.isEmpty) return null;
    return BillModel.fromJson(rows.first);
  }

  // ─────────────────────────────────────────
  // SALES
  // ─────────────────────────────────────────

  static Future<void> saveSale(SaleModel sale) async {
    await _client.from('sales').insert(sale.toJson());
  }

  /// Update an existing bill's amount, vendor, notes
  static Future<void> updateBill(String billId, {
    double? amount,
    String? vendorName,
    String? notes,
    String? imageUrl,
    bool? isGstBill,
    double? gstAmount,
    DateTime? billDate,
  }) async {
    final updates = <String, dynamic>{};
    if (amount != null) updates['amount'] = amount;
    if (vendorName != null) updates['vendor_name'] = vendorName;
    if (notes != null) updates['notes'] = notes;
    if (imageUrl != null) updates['image_url'] = imageUrl;
    if (isGstBill != null) updates['is_gst_bill'] = isGstBill;
    if (gstAmount != null) updates['gst_amount'] = gstAmount;
    if (billDate != null) updates['bill_date'] = billDate.toIso8601String().split('T')[0];
    await _client.from('bills').update(updates).eq('id', billId);
  }

  /// Delete all sale items linked to a bill (used before re-inserting updated items)
  static Future<void> deleteSalesByBillId(String billId) async {
    await _client.from('sales').delete().eq('bill_id', billId);
  }

  /// Delete a bill
  static Future<void> deleteBill(String billId) async {
    await _client.from('bills').delete().eq('id', billId);
  }

static Future<double> getTodaySalesTotal(String shopId) async {
  final today = DateTime.now().toIso8601String().split('T')[0];
  final data = await _client
      .from('sales')
      .select('total_amount')
      .eq('shop_id', shopId)
      .eq('sale_date', today);
  if ((data as List).isEmpty) return 0.0;
  // ✅ Fixed — cast to double directly
  double total = 0.0;
  for (final s in data) {
    total += (s['total_amount'] as num?)?.toDouble() ?? 0.0;
  }
  return total;
}

  static Future<int> getTodaySalesCount(String shopId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await _client
        .from('sales')
        .select('id')
        .eq('shop_id', shopId)
        .eq('sale_date', today);
    return (data as List).length;
  }

  static Future<List<SaleModel>> getSales(
      String shopId, DateTime from, DateTime to) async {
    final data = await _client
        .from('sales')
        .select()
        .eq('shop_id', shopId)
        .gte('sale_date', from.toIso8601String().split('T')[0])
        .lte('sale_date', to.toIso8601String().split('T')[0])
        .order('created_at', ascending: false);
    return (data as List).map((s) => SaleModel.fromJson(s)).toList();
  }

  // ─────────────────────────────────────────
  // STOCK
  // ─────────────────────────────────────────

  static Future<StockItemModel> saveStockItem(StockItemModel item) async {
    final data = await _client
        .from('stock_items')
        .insert(item.toJson())
        .select()
        .single();
    return StockItemModel.fromJson(data);
  }

  static Future<List<StockItemModel>> getStockItems(String shopId) async {
    final data = await _client
        .from('stock_items')
        .select()
        .eq('shop_id', shopId)
        .order('item_name');
    return (data as List).map((s) => StockItemModel.fromJson(s)).toList();
  }

  static Future<int> getLowStockCount(String shopId) async {
    final items = await getStockItems(shopId);
    return items.where((i) => i.isLowStock).length;
  }

  static Future<void> updateStockQuantity(
      String itemId, double newQuantity) async {
    await _client
        .from('stock_items')
        .update({
          'current_quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itemId);
  }

  /// Update full stock item details
  static Future<void> updateStockItem(StockItemModel item) async {
    await _client
        .from('stock_items')
        .update({
          'item_name': item.itemName,
          'current_quantity': item.currentQuantity,
          'unit': item.unit,
          'buying_price': item.buyingPrice,
          'selling_price': item.sellingPrice,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', item.id);
  }

  /// Delete stock item
  static Future<void> deleteStockItem(String itemId) async {
    await _client.from('stock_items').delete().eq('id', itemId);
  }

  // ─────────────────────────────────────────
  // ITEM MASTER
  // ─────────────────────────────────────────

  static Future<ItemMasterModel> saveMasterItem(ItemMasterModel item) async {
    final data = await _client
        .from('item_master')
        .insert(item.toJson())
        .select()
        .single();
    return ItemMasterModel.fromJson(data);
  }

  static Future<void> updateMasterItem(ItemMasterModel item) async {
    // using patch correctly
    final updates = item.toJson();
    updates['updated_at'] = DateTime.now().toIso8601String();
    
    await _client
        .from('item_master')
        .update(updates)
        .eq('id', item.id);
  }

  static Future<List<ItemMasterModel>> getMasterItems(String shopId) async {
    final data = await _client
        .from('item_master')
        .select()
        .eq('shop_id', shopId)
        .order('item_name');
    return (data as List).map((s) => ItemMasterModel.fromJson(s)).toList();
  }

  static Future<void> deleteMasterItem(String itemId) async {
    await _client.from('item_master').delete().eq('id', itemId);
  }

  static Future<String> uploadItemImage(String shopId, String itemName, Uint8List imageBytes, String extension) async {
    final fileName = '${shopId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = '$shopId/$fileName';
    
    await _client.storage.from('items').uploadBinary(
      path,
      imageBytes,
      fileOptions: const FileOptions(upsert: true),
    );
    
    return _client.storage.from('items').getPublicUrl(path);
  }

  static Future<String> uploadCreditReceipt(
      String shopId, Uint8List imageBytes, String extension) async {
    final fileName =
        'credit_receipt_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = '$shopId/credit_receipts/$fileName';

    await _client.storage.from('items').uploadBinary(
      path,
      imageBytes,
      fileOptions: const FileOptions(upsert: true),
    );

    return _client.storage.from('items').getPublicUrl(path);
  }

  static Future<String> uploadBillImage(
      String shopId, Uint8List imageBytes, String extension) async {
    final fileName =
        'bill_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = '$shopId/bills/$fileName';

    await _client.storage.from('items').uploadBinary(
      path,
      imageBytes,
      fileOptions: const FileOptions(upsert: true),
    );

    return _client.storage.from('items').getPublicUrl(path);
  }

  static Future<bool> addMasterStockById(String stockItemId, double quantity) async {
    try {
      final data = await _client
          .from('item_master')
          .select('current_stock')
          .eq('id', stockItemId)
          .single();
      final current = (data['current_stock'] as num?)?.toDouble() ?? 0.0;
      await _client
          .from('item_master')
          .update({
            'current_stock': current + quantity,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', stockItemId);
      return true;
    } catch (e) {
      debugPrint('Add master stock error: $e');
      return false;
    }
  }

  static Future<bool> deductMasterStockById(String stockItemId, double quantity) async {
    if (quantity <= 0) return false;

    try {
      final data = await _client
          .from('item_master')
          .select('id, current_stock')
          .eq('id', stockItemId)
          .maybeSingle();

      if (data == null) {
        print('⚠️ deductMasterStockById: item $stockItemId not found');
        return false;
      }

      final current = (data['current_stock'] as num?)?.toDouble() ?? 0.0;
      if (current < quantity) {
        debugPrint(
          'deductMasterStockById blocked: requested $quantity, available $current',
        );
        return false;
      }
      final newQty = current - quantity;
      
      final updated = await _client
          .from('item_master')
          .update({
            'current_stock': newQty,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', stockItemId)
          .eq('current_stock', current)
          .select('id');

      return (updated as List).isNotEmpty;
    } catch (e) {
      print('❌ deductMasterStockById error: $e');
      return false;
    }
  }

  /// Update Udhar customer
  static Future<void> updateUdharCustomer(UdharCustomerModel customer) async {
    await _client
        .from('udhar_customers')
        .update({
          'customer_name': customer.customerName,
          'customer_phone': customer.customerPhone,
          'total_due': customer.totalDue,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', customer.id);
  }

  /// Delete Udhar record
  static Future<void> deleteUdharCustomer(String id) async {
    await _client.from('udhar_customers').delete().eq('id', id);
  }

  /// Add stock by item ID directly (reverses deduction)
  static Future<bool> addStockById(String stockItemId, double quantity) async {
    try {
      final data = await _client
          .from('stock_items')
          .select('current_quantity')
          .eq('id', stockItemId)
          .single();
      final current = (data['current_quantity'] as num?)?.toDouble() ?? 0.0;
      await updateStockQuantity(stockItemId, current + quantity);
      return true;
    } catch (e) {
      debugPrint('Add stock error: $e');
      return false;
    }
  }
  /// Deduct stock by item ID directly (most reliable)
  static Future<bool> deductStockById(String stockItemId, double quantity) async {
    if (quantity <= 0) return false;

    try {
      final data = await _client
          .from('stock_items')
          .select('id, current_quantity')
          .eq('id', stockItemId)
          .maybeSingle();

      if (data == null) {
        print('⚠️ deductStockById: item $stockItemId not found');
        return false;
      }

      final current = (data['current_quantity'] as num?)?.toDouble() ?? 0.0;
      if (current < quantity) {
        debugPrint(
          'deductStockById blocked: requested $quantity, available $current',
        );
        return false;
      }
      final newQty = current - quantity;
      
      print('📦 Stock deduct: $current - $quantity = $newQty (id: $stockItemId)');

      // 2. Update directly
      final updated = await _client
          .from('stock_items')
          .update({
            'current_quantity': newQty,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', stockItemId)
          .eq('current_quantity', current)
          .select('id');

      return (updated as List).isNotEmpty;
    } catch (e) {
      print('❌ deductStockById error: $e');
      return false;
    }
  }

  /// Deduct stock by item name (fallback)
  static Future<bool> deductStock(
      String shopId, String itemName, double quantity) async {
    if (quantity <= 0) return false;

    try {
      final data = await _client
          .from('stock_items')
          .select()
          .eq('shop_id', shopId)
          .eq('item_name', itemName)
          .maybeSingle();

      if (data == null) {
        print('⚠️ deductStock: "$itemName" not found in shop $shopId');
        return false;
      }

      final current = (data['current_quantity'] as num?)?.toDouble() ?? 0.0;
      if (current < quantity) {
        debugPrint(
          'deductStock blocked for "$itemName": requested $quantity, '
          'available $current',
        );
        return false;
      }
      final newQty = current - quantity;
      
      print('📦 Stock deduct by name: $current - $quantity = $newQty');
      final updated = await _client
          .from('stock_items')
          .update({
            'current_quantity': newQty,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', data['id'])
          .eq('current_quantity', current)
          .select('id');

      return (updated as List).isNotEmpty;
    } catch (e) {
      print('❌ deductStock error: $e');
      return false;
    }
  }
  // ─────────────────────────────────────────
  // UDHAR
  // ─────────────────────────────────────────

  static Future<UdharCustomerModel> saveUdharCustomer(
      UdharCustomerModel customer) async {
    final data = await _client
        .from('udhar_customers')
        .insert(customer.toJson())
        .select()
        .single();
    return UdharCustomerModel.fromJson(data);
  }

  static Future<List<UdharCustomerModel>> getUdharCustomers(
      String shopId) async {
    final data = await _client
        .from('udhar_customers')
        .select()
        .eq('shop_id', shopId)
        .gt('total_due', 0)
        .order('total_due', ascending: false);
    return (data as List)
        .map((u) => UdharCustomerModel.fromJson(u))
        .toList();
  }

  static Future<List<UdharCustomerModel>> getAllUdharCustomers(
      String shopId) async {
    final data = await _client
        .from('udhar_customers')
        .select()
        .eq('shop_id', shopId)
        .order('updated_at', ascending: false);
    return (data as List)
        .map((u) => UdharCustomerModel.fromJson(u))
        .toList();
  }

  static Future<List<UdharCustomerModel>> searchUdharCustomers(
      String shopId, String query) async {
    var request = _client
        .from('udhar_customers')
        .select()
        .eq('shop_id', shopId);

    final trimmed = query.trim();
    final data = trimmed.isEmpty
        ? await request.order('customer_name').limit(25)
        : await request
            .ilike('customer_name', '%$trimmed%')
            .order('customer_name')
            .limit(25);

    return (data as List)
        .map((u) => UdharCustomerModel.fromJson(u))
        .toList();
  }

  static Future<UdharCustomerModel?> findCustomerByName(
      String shopId, String name) async {
    final data = await _client
        .from('udhar_customers')
        .select()
        .eq('shop_id', shopId)
        .ilike('customer_name', name.trim())
        .order('updated_at', ascending: false)
        .limit(1);
    final rows = data as List;
    if (rows.isEmpty) return null;
    return UdharCustomerModel.fromJson(rows.first);
  }

  static Future<UdharCustomerModel?> findCustomerByPhone(
      String shopId, String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;
    final data = await _client
        .from('udhar_customers')
        .select()
        .eq('shop_id', shopId)
        .eq('customer_phone', trimmed)
        .order('updated_at', ascending: false)
        .limit(1);
    final rows = data as List;
    if (rows.isEmpty) return null;
    return UdharCustomerModel.fromJson(rows.first);
  }

  static Future<UdharCustomerModel> createUdharCustomer({
    required String shopId,
    required String userId,
    required String customerName,
    String phone = '',
  }) async {
    final data = await _client
        .from('udhar_customers')
        .insert({
          'shop_id': shopId,
          'user_id': userId,
          'customer_name': customerName.trim(),
          'customer_phone': phone.trim(),
          'total_due': 0,
        })
        .select()
        .single();
    return UdharCustomerModel.fromJson(data);
  }

  static Future<UdharEntryModel> addCreditEntry({
    required String shopId,
    required String userId,
    required String customerId,
    required double amount,
    String note = '',
  }) async {
    try {
      final data = await _client
          .from('udhar_entries')
          .insert({
            'shop_id': shopId,
            'user_id': userId,
            'customer_id': customerId,
            'entry_type': 'credit',
            'amount': amount,
            'note': note,
            'entry_date': DateTime.now().toIso8601String().split('T')[0],
            'is_paid': false,
            'party_paid': 0.0,
          })
          .select()
          .single();
      final model = UdharEntryModel.fromJson(data);
      await syncCustomerCreditEntriesPaidStatus(customerId);
      return model;
    } catch (e) {
      if (e.toString().contains('column') || e.toString().contains('is_paid') || e.toString().contains('party_paid')) {
        final data = await _client
            .from('udhar_entries')
            .insert({
              'shop_id': shopId,
              'user_id': userId,
              'customer_id': customerId,
              'entry_type': 'credit',
              'amount': amount,
              'note': note,
              'entry_date': DateTime.now().toIso8601String().split('T')[0],
            })
            .select()
            .single();
        return UdharEntryModel.fromJson(data);
      }
      rethrow;
    }
  }

  static Future<UdharEntryModel> addDebitEntry({
    required String shopId,
    required String userId,
    required String customerId,
    required double amount,
    String note = '',
  }) async {
    try {
      final data = await _client
          .from('udhar_entries')
          .insert({
            'shop_id': shopId,
            'user_id': userId,
            'customer_id': customerId,
            'entry_type': 'debit',
            'amount': amount,
            'note': note,
            'entry_date': DateTime.now().toIso8601String().split('T')[0],
            'is_paid': false,
            'party_paid': 0.0,
          })
          .select()
          .single();
      final model = UdharEntryModel.fromJson(data);
      await syncCustomerCreditEntriesPaidStatus(customerId);
      return model;
    } catch (e) {
      if (e.toString().contains('column') || e.toString().contains('is_paid') || e.toString().contains('party_paid')) {
        final data = await _client
            .from('udhar_entries')
            .insert({
              'shop_id': shopId,
              'user_id': userId,
              'customer_id': customerId,
              'entry_type': 'debit',
              'amount': amount,
              'note': note,
              'entry_date': DateTime.now().toIso8601String().split('T')[0],
            })
            .select()
            .single();
        return UdharEntryModel.fromJson(data);
      }
      rethrow;
    }
  }

  static Future<UdharEntryModel> addAdjustmentCreditEntry({
    required String shopId,
    required String userId,
    required String customerId,
    required double amount,
    String note = '',
  }) async {
    try {
      final data = await _client
          .from('udhar_entries')
          .insert({
            'shop_id': shopId,
            'user_id': userId,
            'customer_id': customerId,
            'entry_type': 'credit_adjustment',
            'amount': amount,
            'note': note,
            'entry_date': DateTime.now().toIso8601String().split('T')[0],
            'is_paid': false,
            'party_paid': 0.0,
          })
          .select()
          .single();
      final model = UdharEntryModel.fromJson(data);
      await syncCustomerCreditEntriesPaidStatus(customerId);
      return model;
    } catch (e) {
      if (e.toString().contains('column') || e.toString().contains('is_paid') || e.toString().contains('party_paid')) {
        final data = await _client
            .from('udhar_entries')
            .insert({
              'shop_id': shopId,
              'user_id': userId,
              'customer_id': customerId,
              'entry_type': 'credit_adjustment',
              'amount': amount,
              'note': note,
              'entry_date': DateTime.now().toIso8601String().split('T')[0],
            })
            .select()
            .single();
        return UdharEntryModel.fromJson(data);
      }
      rethrow;
    }
  }

  static Future<UdharEntryModel> recordUdharPayment({
    required String shopId,
    required String userId,
    required UdharCustomerModel customer,
    required double amount,
    required String paymentMethod,
    String receiptImageUrl = '',
    String? appliedCreditEntryId,
    String? billId,
  }) async {
    final currentDue = await getCustomerTotalDue(customer.id);
    final paidAmount = amount.clamp(0, currentDue).toDouble();
    final remainingAmount = (currentDue - paidAmount).clamp(0, double.infinity).toDouble();
    final meta = UdharPaymentMeta(
      paymentMethod: paymentMethod,
      receiptImageUrl: receiptImageUrl,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      customerName: customer.customerName,
      customerPhone: customer.customerPhone,
      appliedCreditEntryId: appliedCreditEntryId,
      billId: billId,
    );
    final entry = await addDebitEntry(
      shopId: shopId,
      userId: userId,
      customerId: customer.id,
      amount: paidAmount,
      note: meta.toEntryNote(),
    );
    await updateCustomerTotalDue(customer.id, remainingAmount);
    await _trySyncDailyBalancesForDate(shopId, DateTime.now());
    return entry;
  }

  static Future<void> syncCustomerCreditEntriesPaidStatus(String customerId) async {
    try {
      final entries = await getUdharEntriesForCustomer(customerId);
      final credits = entries
          .where((e) => e.entryType == 'credit')
          .toList()
          .reversed
          .toList();

      final debits = entries.where((e) => e.entryType == 'debit').toList();
      double totalDebit = debits.fold<double>(0, (sum, entry) => sum + entry.amount);

      for (final credit in credits) {
        double paidForThis = 0.0;
        if (totalDebit >= credit.amount) {
          paidForThis = credit.amount;
          totalDebit -= credit.amount;
        } else if (totalDebit > 0) {
          paidForThis = totalDebit;
          totalDebit = 0.0;
        }

        final isPaid = paidForThis >= credit.amount;
        if (credit.isPaid != isPaid || credit.partypaid != paidForThis) {
          try {
            await _client.from('udhar_entries').update({
              'is_paid': isPaid,
              'party_paid': paidForThis,
            }).eq('id', credit.id);
          } catch (e) {
            // Gracefully ignore if columns do not exist in schema yet
            debugPrint('Failed to update is_paid/party_paid column (possibly schema doesn\'t exist yet): $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing credit entries paid status: $e');
    }
  }

  static Future<void> updateCustomerTotalDue(
      String customerId, double newTotalDue) async {
    await _client
        .from('udhar_customers')
        .update({
          'total_due': newTotalDue < 0 ? 0 : newTotalDue,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', customerId);
  }

  static Future<double> getCustomerTotalDue(String customerId) async {
    final data = await _client
        .from('udhar_customers')
        .select('total_due')
        .eq('id', customerId)
        .single();
    return (data['total_due'] as num?)?.toDouble() ?? 0.0;
  }

  /// Computes available adjustment balance from udhar_entries.
  /// This is the source of truth — column is just a cache.
  static Future<double> _computeAdjustmentFromEntries(String customerId) async {
    try {
      final entries = await getAdjustmentEntriesForCustomer(customerId);
      double total = 0;
      for (final entry in entries) {
        if (entry.entryType == 'credit_adjustment') {
          total += entry.amount;
        } else if (entry.entryType == 'adjustment_used') {
          total -= entry.amount;
        }
      }
      return total.clamp(0, double.infinity).toDouble();
    } catch (e) {
      debugPrint('_computeAdjustmentFromEntries error: $e');
      return 0.0;
    }
  }

  static Future<double> getCustomerAdjustmentAmount(String customerId) async {
    try {
      final data = await _client
          .from('udhar_customers')
          .select(adjustmentAmountColumn)
          .eq('id', customerId)
          .single();
      return (data[adjustmentAmountColumn] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      try {
        final data = await _client
            .from('udhar_customers')
            .select(adjustmentAmountFallbackColumn)
            .eq('id', customerId)
            .single();
        return (data[adjustmentAmountFallbackColumn] as num?)?.toDouble() ?? 0.0;
      } catch (_) {
        // Column doesn't exist — compute from entries (source of truth)
        return _computeAdjustmentFromEntries(customerId);
      }
    }
  }

  static Future<void> updateCustomerAdjustmentAmount(
    String customerId,
    double newAmount,
  ) async {
    final safeAmount = newAmount < 0 ? 0.0 : newAmount;
    try {
      await _client
          .from('udhar_customers')
          .update({
            adjustmentAmountColumn: safeAmount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', customerId);
    } catch (_) {
      try {
        await _client
            .from('udhar_customers')
            .update({
              adjustmentAmountFallbackColumn: safeAmount,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', customerId);
      } catch (_) {
        // Column doesn't exist — silently skip; entries are the source of truth
        debugPrint('Adjustment column not found on udhar_customers, skipping cache update');
      }
    }
  }

  static Future<double> addCustomerAdjustmentAmount(
    String customerId,
    double amount,
  ) async {
    final current = await getCustomerAdjustmentAmount(customerId);
    final next = current + amount;
    try {
      await updateCustomerAdjustmentAmount(customerId, next);
    } catch (_) {
      // Cache update failed — entries still hold the truth
    }
    return next;
  }

  static Future<double> deductCustomerAdjustmentAmount(
    String customerId,
    double amount,
  ) async {
    final current = await getCustomerAdjustmentAmount(customerId);
    final next = (current - amount).clamp(0.0, double.infinity).toDouble();
    try {
      await updateCustomerAdjustmentAmount(customerId, next);
    } catch (_) {
      // Cache update failed — entries still hold the truth
    }
    return next;
  }

  static Future<List<UdharEntryModel>> getAdjustmentEntriesForCustomer(
    String customerId,
  ) async {
    final data = await _client
        .from('udhar_entries')
        .select()
        .eq('customer_id', customerId)
        .inFilter('entry_type', ['credit_adjustment', 'adjustment_used'])
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => UdharEntryModel.fromJson(e)).toList();
  }

  static Future<UdharEntryModel> addAdjustmentUsedEntry({
    required String shopId,
    required String userId,
    required String customerId,
    required double amount,
    String note = '',
  }) async {
    final data = await _client
        .from('udhar_entries')
        .insert({
          'shop_id': shopId,
          'user_id': userId,
          'customer_id': customerId,
          'entry_type': 'adjustment_used',
          'amount': amount,
          'note': note,
          'entry_date': DateTime.now().toIso8601String().split('T')[0],
        })
        .select()
        .single();
    return UdharEntryModel.fromJson(data);
  }

  static Future<void> deleteUdharEntry(String entryId) async {
    try {
      final entryData = await _client.from('udhar_entries').select('customer_id').eq('id', entryId).maybeSingle();
      await _client.from('udhar_entries').delete().eq('id', entryId);
      if (entryData != null) {
        final customerId = entryData['customer_id'] as String?;
        if (customerId != null) {
          await syncCustomerCreditEntriesPaidStatus(customerId);
        }
      }
    } catch (e) {
      debugPrint('Error deleting udhar entry: $e');
    }
  }

  static Future<List<UdharEntryModel>> getUdharEntriesForCustomer(
      String customerId) async {
    final data = await _client
        .from('udhar_entries')
        .select()
        .eq('customer_id', customerId)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => UdharEntryModel.fromJson(e)).toList();
  }

static Future<double> getTotalUdhar(String shopId) async {
  final data = await _client
      .from('udhar_customers')
      .select('total_due')
      .eq('shop_id', shopId);
  if ((data as List).isEmpty) return 0.0;
  // ✅ Fixed — cast to double directly
  double total = 0.0;
  for (final u in data) {
    total += (u['total_due'] as num?)?.toDouble() ?? 0.0;
  }
  return total;
}
  static Future<void> addUdharEntry(
      UdharEntryModel entry, String customerId) async {
    try {
      await _client.from('udhar_entries').insert(entry.toJson());
    } catch (e) {
      if (e.toString().contains('column') || e.toString().contains('is_paid') || e.toString().contains('party_paid')) {
        final map = entry.toJson();
        map.remove('is_paid');
        map.remove('party_paid');
        map.remove('isPaid');
        map.remove('partypaid');
        await _client.from('udhar_entries').insert(map);
      } else {
        rethrow;
      }
    }

    final customer = await _client
        .from('udhar_customers')
        .select('total_due')
        .eq('id', customerId)
        .single();

    double currentDue =
        ((customer['total_due'] ?? 0) as num).toDouble();
    double newDue = entry.entryType == 'credit'
        ? currentDue + entry.amount
        : currentDue - entry.amount;
    newDue = newDue.clamp(0, double.infinity);

    await _client
        .from('udhar_customers')
        .update({
          'total_due': newDue,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', customerId);
        
    await syncCustomerCreditEntriesPaidStatus(customerId);
  }

  static Future<void> markUdharPaid(String customerId) async {
    await _client
        .from('udhar_customers')
        .update({
          'total_due': 0,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', customerId);
  }

  // ─────────────────────────────────────────
  // PURCHASE CREDIT
  // ─────────────────────────────────────────

  static Future<void> updatePurchasePartyPendingAmount(
      String partyId, double newAmount) async {
    await _client.from('purchase_parties').update({
      'pending_amount': newAmount < 0 ? 0 : newAmount,
    }).eq('id', partyId);
  }

  static Future<Map<String, dynamic>?> findPurchasePartyByName(
      String shopId, String name) async {
    final data = await _client
        .from('purchase_parties')
        .select()
        .eq('shop_id', shopId)
        .ilike('name', name.trim())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data;
  }

  static Future<Map<String, dynamic>> createPurchaseParty({
    required String shopId,
    required String userId,
    required String name,
  }) async {
    final data = await _client
        .from('purchase_parties')
        .insert({
          'shop_id': shopId,
          'name': name.trim(),
        })
        .select()
        .single();
    return data;
  }

  static Future<double> getPurchasePartyAdjustmentAmount(String partyId) async {
    try {
      final data = await _client
          .from('purchase_parties')
          .select('tobeadjust_amount')
          .eq('id', partyId)
          .single();
      return (data['tobeadjust_amount'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  static Future<void> updatePurchasePartyAdjustmentAmount(
      String partyId, double amount) async {
    await _client.from('purchase_parties').update({
      'tobeadjust_amount': amount < 0 ? 0.0 : amount,
    }).eq('id', partyId);
  }

  static Future<double> addPurchasePartyAdjustmentAmount(
      String partyId, double amount) async {
    final current = await getPurchasePartyAdjustmentAmount(partyId);
    final next = current + amount;
    await updatePurchasePartyAdjustmentAmount(partyId, next);
    return next;
  }

  static Future<double> deductPurchasePartyAdjustmentAmount(
      String partyId, double amount) async {
    final current = await getPurchasePartyAdjustmentAmount(partyId);
    final next = (current - amount).clamp(0.0, double.infinity).toDouble();
    await updatePurchasePartyAdjustmentAmount(partyId, next);
    return next;
  }

  static Future<List<Map<String, dynamic>>> searchPurchaseParties(
      String shopId, String query) async {
    var request = _client
        .from('purchase_parties')
        .select()
        .eq('shop_id', shopId);

    final trimmed = query.trim();
    final data = trimmed.isEmpty
        ? await request.order('name').limit(25)
        : await request
            .ilike('name', '%$trimmed%')
            .order('name')
            .limit(25);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<double> recalculatePurchasePartyPendingAmount({
    required String shopId,
    required String partyId,
    required String partyName,
  }) async {
    try {
      final bills = await getPurchaseBillsForParty(shopId, partyName);
      double totalPending = 0.0;

      for (final bill in bills) {
        if (bill.notes == 'Payment to Supplier') {
          totalPending -= bill.amount;
          continue;
        }

        double creditAmount = 0.0;
        try {
          final sales = await getSalesByBillId(bill.id);
          if (sales.isNotEmpty) {
            final paymentMode = sales.first.paymentMode.toLowerCase();
            bool hasCreditDetails = false;

            for (final s in sales) {
              final notesStr = s.notes;
              final startMarker = '__saafhisaab_credit_advance:';
              final startIndex = notesStr.indexOf(startMarker);
              if (startIndex >= 0) {
                final endMarker = '__';
                final endIndex = notesStr.indexOf(endMarker, startIndex + startMarker.length);
                if (endIndex >= 0) {
                  final sub = notesStr.substring(startIndex + startMarker.length, endIndex);
                  final parts = sub.split(';credit:');
                  if (parts.length == 2) {
                    creditAmount = double.tryParse(parts[1]) ?? 0.0;
                    hasCreditDetails = true;
                    break;
                  }
                }
              }
            }

            if (!hasCreditDetails) {
              if (paymentMode == 'credit' || paymentMode == 'split') {
                creditAmount = bill.amount;
              }
            }
          }
        } catch (_) {}
        totalPending += creditAmount;
      }

      final finalPending = totalPending < 0 ? 0.0 : totalPending;
      await updatePurchasePartyPendingAmount(partyId, finalPending);
      return finalPending;
    } catch (e) {
      debugPrint('Error recalculating pending amount: $e');
      return 0.0;
    }
  }

  static Future<void> recordPurchasePartyPayment({
    required String shopId,
    required String userId,
    required String partyId,
    required String partyName,
    required double amount,
    required String paymentMethod,
  }) async {
    final currentPending = await getPurchasePartyPendingAmount(partyId);
    final newPending = (currentPending - amount).clamp(0.0, double.infinity);
    await updatePurchasePartyPendingAmount(partyId, newPending);

    // Save payment as purchase bill
    final billId = await saveBillGetId(BillModel(
      id: '',
      shopId: shopId,
      userId: userId,
      amount: amount,
      billDate: DateTime.now(),
      vendorName: partyName,
      billType: 'purchase',
      notes: 'Payment to Supplier',
      createdAt: DateTime.now(),
    ));

    // Save a linked sale to record the payment mode
    await saveSale(SaleModel(
      id: '',
      shopId: shopId,
      userId: userId,
      itemName: 'Payment to Supplier',
      quantity: 1,
      unit: 'piece',
      sellingPrice: amount,
      totalAmount: amount,
      paymentMode: paymentMethod,
      billId: billId.isNotEmpty ? billId : null,
      saleDate: DateTime.now(),
      notes: 'Payment to Supplier',
      createdAt: DateTime.now(),
    ));

    // Force sync daily balances
    await _trySyncDailyBalancesForDate(shopId, DateTime.now());
  }

  static Future<List<LedgerRow>> fetchLedgerMonthly({
    required String accountId,
    required bool isReceivable,
    required String shopId,
  }) async {
    final now = DateTime.now();
    final fyStart = now.month >= 4 ? now.year : now.year - 1;
    final startOfFy = DateTime(fyStart, 4, 1);
    final endOfFy = DateTime(fyStart + 1, 3, 31);

    double openingBalance = 0.0;

    // Initialize 12 months starting from April
    final monthNames = [
      'April', 'May', 'June', 'July', 'August', 'September',
      'October', 'November', 'December', 'January', 'February', 'March'
    ];

    final Map<String, Map<String, double>> monthlySums = {};
    for (final mName in monthNames) {
      monthlySums[mName] = {'debit': 0.0, 'credit': 0.0};
    }

    if (isReceivable) {
      // Fetch customer udhar entries
      final entries = await getUdharEntriesForCustomer(accountId);
      
      double debitsBefore = 0.0;
      double creditsBefore = 0.0;

      for (final entry in entries) {
        final entryDate = entry.entryDate;
        final amount = entry.amount;
        final isCreditEntry = entry.entryType == 'credit'; // udhar given = debit (owing us)

        if (entryDate.isBefore(startOfFy)) {
          if (isCreditEntry) {
            debitsBefore += amount;
          } else {
            creditsBefore += amount;
          }
        } else if (!entryDate.isAfter(endOfFy)) {
          int idx = entryDate.month - 4;
          if (idx < 0) idx += 12;
          final mName = monthNames[idx];
          
          if (isCreditEntry) {
            monthlySums[mName]!['debit'] = (monthlySums[mName]!['debit'] ?? 0) + amount;
          } else {
            monthlySums[mName]!['credit'] = (monthlySums[mName]!['credit'] ?? 0) + amount;
          }
        }
      }
      openingBalance = -debitsBefore + creditsBefore;

    } else {
      // Fetch supplier bills
      final partyData = await _client
          .from('purchase_parties')
          .select('name')
          .eq('id', accountId)
          .single();
      final partyName = partyData['name'] as String? ?? '';

      final bills = await getPurchaseBillsForParty(shopId, partyName);
      
      double debitsBefore = 0.0;
      double creditsBefore = 0.0;

      for (final bill in bills) {
        final billDate = bill.billDate;
        final amount = bill.amount;
        final isPayment = bill.notes == 'Payment to Supplier';

        if (billDate.isBefore(startOfFy)) {
          if (isPayment) {
            debitsBefore += amount; // payment reduces payable = debit
          } else {
            creditsBefore += amount; // purchase increases payable = credit
          }
        } else if (!billDate.isAfter(endOfFy)) {
          int idx = billDate.month - 4;
          if (idx < 0) idx += 12;
          final mName = monthNames[idx];

          if (isPayment) {
            monthlySums[mName]!['debit'] = (monthlySums[mName]!['debit'] ?? 0) + amount;
          } else {
            monthlySums[mName]!['credit'] = (monthlySums[mName]!['credit'] ?? 0) + amount;
          }
        }
      }
      openingBalance = -debitsBefore + creditsBefore;
    }

    final List<LedgerRow> rows = [];
    rows.add(LedgerRow(
      particular: 'Opening Balance',
      debit: 0.0,
      credit: 0.0,
      balance: openingBalance,
    ));

    double runningBalance = openingBalance;
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    for (final mName in monthNames) {
      final deb = monthlySums[mName]!['debit']!;
      final cred = monthlySums[mName]!['credit']!;
      
      runningBalance = runningBalance - deb + cred;
      totalDebit += deb;
      totalCredit += cred;

      rows.add(LedgerRow(
        particular: mName,
        debit: deb,
        credit: cred,
        balance: runningBalance,
      ));
    }

    rows.add(LedgerRow(
      particular: '***** ALL MONTHS *****',
      debit: totalDebit,
      credit: totalCredit,
      balance: runningBalance,
    ));

    return rows;
  }

  static Future<double> getPurchasePartyPendingAmount(String partyId) async {
    final data = await _client
        .from('purchase_parties')
        .select('pending_amount')
        .eq('id', partyId)
        .single();
    return (data['pending_amount'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<String> getPurchasePartyName(String partyId) async {
    final data = await _client
        .from('purchase_parties')
        .select('name')
        .eq('id', partyId)
        .single();
    return data['name'] as String? ?? '';
  }

  static Future<List<Map<String, dynamic>>> getPurchasePartiesWithPending(
      String shopId) async {
    final data = await _client
        .from('purchase_parties')
        .select()
        .eq('shop_id', shopId)
        .gt('pending_amount', 0)
        .order('pending_amount', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<BillModel>> getPurchaseBillsForParty(
      String shopId, String partyName) async {
    final data = await _client
        .from('bills')
        .select()
        .eq('shop_id', shopId)
        .eq('bill_type', 'purchase')
        .ilike('vendor_name', partyName.trim())
        .order('bill_date', ascending: false);
    return (data as List).map((b) => BillModel.fromJson(b)).toList();
  }

  // ─────────────────────────────────────────
  // DASHBOARD
  // ─────────────────────────────────────────

  /// Sum of bill amounts by type from [bills] table for today
  static Future<double> getTodayBillTotalByType(String shopId, String type) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await _client
        .from('bills')
        .select('amount')
        .eq('shop_id', shopId)
        .eq('bill_date', today)
        .eq('bill_type', type);
    if ((data as List).isEmpty) return 0.0;
    double total = 0.0;
    for (final b in data) {
      total += (b['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  /// Count of all bills from [bills] table for today
  static Future<int> getTodayBillCount(String shopId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await _client
        .from('bills')
        .select('id')
        .eq('shop_id', shopId)
        .eq('bill_date', today);
    return (data as List).length;
  }

  static Future<Map<String, dynamic>> getDashboardStats(
      String shopId) async {
    final results = await Future.wait([
      getTodayBillTotalByType(shopId, 'sale'),
      getTodayBillTotalByType(shopId, 'sale_return'),
      getTotalUdhar(shopId),
      getLowStockCount(shopId),
      getTodayBillCount(shopId),
    ]);
    final salesTotal = (results[0] as double);
    final returnsTotal = (results[1] as double);
    final billCount = (results[4] as int);
    
    return {
      'today_sales': salesTotal - returnsTotal, // Net sales
      'today_bills': billCount,
      'total_udhar': results[2],
      'low_stock': results[3],
    };
  }

  // ─────────────────────────────────────────
  // DAILY BALANCES
  // ─────────────────────────────────────────

  static Future<List<DailyBalanceModel>> syncAndGetDailyBalances(String shopId, int month, int year) async {
    final start = DateTime(year, month, 1).toIso8601String().split('T')[0];
    // End date is the last day of the month
    final end = DateTime(year, month + 1, 0).toIso8601String().split('T')[0];

    // 1. Fetch bills for the month
    final billsData = await _client
        .from('bills')
        .select('id, amount, bill_type, bill_date')
        .eq('shop_id', shopId)
        .gte('bill_date', start)
        .lte('bill_date', end);

    final billIds = (billsData as List)
        .map((b) => b['id'] as String?)
        .whereType<String>()
        .toSet();

    // 2. Fetch sales by bill link to get payment mode distribution.
    // Do not filter by sale_date here: edited invoices can rewrite sale rows
    // later while the bill still belongs to its original bill_date.
    final salesData = billIds.isEmpty
        ? <dynamic>[]
        : await _client
            .from('sales')
            .select('bill_id, payment_mode, notes')
            .inFilter('bill_id', billIds.toList());

    final Map<String, String> billPaymentModes = {};
    final Map<String, double> billCashPaid = {};
    final Map<String, double> billAdjustedAmount = {};
    for (var sale in salesData) {
      final bId = sale['bill_id'] as String?;
      if (bId == null || !billIds.contains(bId)) continue;
      if (bId != null && !billPaymentModes.containsKey(bId)) {
        billPaymentModes[bId] = sale['payment_mode'] ?? 'cash';
        billCashPaid[bId] = _creditAdvanceFromNotes(sale['notes'] ?? '');
        billAdjustedAmount[bId] = saleAdjustmentFromNotes(sale['notes'] ?? '');
      }
    }

    final Map<String, DailyBalanceModel> dailyMap = {};

    for (var b in billsData) {
      final dateStr = b['bill_date'] as String;
      final billType = b['bill_type'] as String;
      final amount = (b['amount'] as num).toDouble();
      final billId = b['id'] as String;

      if (!dailyMap.containsKey(dateStr)) {
        dailyMap[dateStr] = DailyBalanceModel(
          id: '', shopId: shopId, balanceDate: DateTime.parse(dateStr),
        );
      }

      double cashIn = 0, cashOut = 0, bankIn = 0, bankOut = 0;
      final mode = billPaymentModes[billId] ?? 'cash';
      final adjustedAmount =
          (billAdjustedAmount[billId] ?? 0).clamp(0, amount).toDouble();
      final paidAmount = (amount - adjustedAmount).clamp(0, amount).toDouble();

      if (mode == 'adjustment') {
        // Return amount is kept as customer adjustment credit, so no cash/bank flow.
      } else if (mode == 'upi' || mode == 'card') {
        if (billType == 'sale' || billType == 'purchase_return') bankIn += paidAmount;
        else bankOut += paidAmount;
      } else if (mode == 'credit') {
        // Credit sales do not add cash or bank balance on invoice day.
      } else if (mode == 'split') {
        final cashPaid = (billType == 'sale_return' || billType == 'purchase_return')
            ? paidAmount
            : (billCashPaid[billId] ?? 0).clamp(0, paidAmount).toDouble();
        if (billType == 'sale' || billType == 'purchase_return') cashIn += cashPaid;
        else cashOut += cashPaid;
      } else {
        if (billType == 'sale' || billType == 'purchase_return') cashIn += paidAmount;
        else cashOut += paidAmount;
      }

      final current = dailyMap[dateStr]!;
      dailyMap[dateStr] = DailyBalanceModel(
        id: current.id, shopId: shopId, balanceDate: current.balanceDate,
        cashIn: current.cashIn + cashIn,
        cashOut: current.cashOut + cashOut,
        bankIn: current.bankIn + bankIn,
        bankOut: current.bankOut + bankOut,
      );
    }

    final udharPaymentsData = await _client
        .from('udhar_entries')
        .select('amount, entry_date, note')
        .eq('shop_id', shopId)
        .eq('entry_type', 'debit')
        .gte('entry_date', start)
        .lte('entry_date', end);

    for (final payment in udharPaymentsData) {
      final dateStr = payment['entry_date'] as String;
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
      final note = payment['note'] ?? '';
      if (note == creditSaleAdvanceNote ||
          note.toString().startsWith(saleReturnUdharReductionNote)) {
        continue;
      }
      final meta = UdharPaymentMeta.tryParseNote(note);
      final mode = (meta?.paymentMethod ?? 'cash').toLowerCase();

      dailyMap.putIfAbsent(
        dateStr,
        () => DailyBalanceModel(
          id: '',
          shopId: shopId,
          balanceDate: DateTime.parse(dateStr),
        ),
      );

      final current = dailyMap[dateStr]!;
      final cashIn = mode == 'cash' ? amount : 0.0;
      final bankIn = mode == 'upi' || mode == 'bank' ? amount : 0.0;
      dailyMap[dateStr] = DailyBalanceModel(
        id: current.id,
        shopId: shopId,
        balanceDate: current.balanceDate,
        cashIn: current.cashIn + cashIn,
        cashOut: current.cashOut,
        bankIn: current.bankIn + bankIn,
        bankOut: current.bankOut,
      );
    }

    // Upsert into database
    final upsertList = dailyMap.values.map((d) {
      return {
        'shop_id': shopId,
        'balance_date': d.balanceDate.toIso8601String().split('T')[0],
        'cash_in': d.cashIn,
        'cash_out': d.cashOut,
        'bank_in': d.bankIn,
        'bank_out': d.bankOut,
        'net_cash': d.cashIn - d.cashOut,
        'net_bank': d.bankIn - d.bankOut,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    await _client
        .from('daily_balances')
        .delete()
        .eq('shop_id', shopId)
        .gte('balance_date', start)
        .lte('balance_date', end);

    if (upsertList.isNotEmpty) {
      await _client.from('daily_balances').upsert(upsertList, onConflict: 'shop_id, balance_date');
    }

    // Fetch the stored models from DB (sorted desc)
    final savedData = await _client
        .from('daily_balances')
        .select('*')
        .eq('shop_id', shopId)
        .gte('balance_date', start)
        .lte('balance_date', end)
        .order('balance_date', ascending: false);

    return savedData.map((d) => DailyBalanceModel.fromJson(d)).toList();
  }

  // ─────────────────────────────────────────
  // CONNECTION TEST
  // ─────────────────────────────────────────

  static Future<bool> testConnection() async {
    try {
      await _client.from('shops').select().limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}
