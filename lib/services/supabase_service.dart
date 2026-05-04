import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase service — all DB operations go through here.
class SupabaseService {
  static final client = Supabase.instance.client;

  // ─── Shop ───────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getShopByOwnerId(String userId) async {
    final response = await client
        .from('shops')
        .select()
        .eq('owner_id', userId)
        .maybeSingle();
    return response;
  }

  static Future<void> createShop(Map<String, dynamic> data) async {
    await client.from('shops').insert(data);
  }

  static Future<void> updateShop(String shopId, Map<String, dynamic> data) async {
    await client.from('shops').update(data).eq('id', shopId);
  }

  // ─── Sales / Bills ─────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTodaySales(String shopId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final response = await client
        .from('sales')
        .select()
        .eq('shop_id', shopId)
        .gte('created_at', '${today}T00:00:00')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> addSale(Map<String, dynamic> data) async {
    await client.from('sales').insert(data);
  }

  // ─── Stock ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getStock(String shopId) async {
    final response = await client
        .from('stock')
        .select()
        .eq('shop_id', shopId)
        .order('item_name');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getLowStock(String shopId, {int threshold = 5}) async {
    final response = await client
        .from('stock')
        .select()
        .eq('shop_id', shopId)
        .lte('quantity', threshold)
        .order('quantity');
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── Udhar (Credit) ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPendingUdhar(String shopId) async {
    final response = await client
        .from('udhar')
        .select()
        .eq('shop_id', shopId)
        .eq('is_paid', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> addUdhar(Map<String, dynamic> data) async {
    await client.from('udhar').insert(data);
  }

  static Future<void> markUdharPaid(String udharId) async {
    await client.from('udhar').update({'is_paid': true}).eq('id', udharId);
  }

  // ─── Connection Test ───────────────────────────────────
  static Future<bool> testConnection() async {
    try {
      await client.from('shops').select().limit(1);
      return true;
    } catch (e) {
      print('❌ Supabase connection test failed: $e');
      return false;
    }
  }
}
