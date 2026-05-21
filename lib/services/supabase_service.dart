import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';
import '../models/bill_model.dart';
import '../models/sale_model.dart';
import '../models/stock_model.dart';
import '../models/item_master_model.dart';
import '../models/udhar_model.dart';
import '../models/daily_balance_model.dart';
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
    bool? isGstBill,
    double? gstAmount,
    DateTime? billDate,
  }) async {
    final updates = <String, dynamic>{};
    if (amount != null) updates['amount'] = amount;
    if (vendorName != null) updates['vendor_name'] = vendorName;
    if (notes != null) updates['notes'] = notes;
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
    await _client.from('udhar_entries').insert(entry.toJson());

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

    // 2. Fetch sales for the month to get payment mode distribution
    final salesData = await _client
        .from('sales')
        .select('bill_id, payment_mode')
        .eq('shop_id', shopId)
        .gte('sale_date', start)
        .lte('sale_date', end);

    final Map<String, String> billPaymentModes = {};
    for (var sale in salesData) {
      final bId = sale['bill_id'];
      if (bId != null && !billPaymentModes.containsKey(bId)) {
        billPaymentModes[bId] = sale['payment_mode'] ?? 'cash';
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

      if (mode == 'upi' || mode == 'card') {
        if (billType == 'sale' || billType == 'purchase_return') bankIn += amount;
        else bankOut += amount;
      } else {
        if (billType == 'sale' || billType == 'purchase_return') cashIn += amount;
        else cashOut += amount;
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
