import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';
import '../models/bill_model.dart';
import '../models/shop_access_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../../main.dart';

// ── Auth state provider ──
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// ── Current user provider ──
final currentUserProvider = Provider<User?>((ref) {
  return AuthService.currentUser;
});

// ── Shop provider — loads shop data for current user ──
final shopAccessProvider = FutureProvider<ShopAccessContext?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull?.session?.user ?? AuthService.currentUser;
  final userId = user?.id;
  if (userId == null) return null;
  return await SupabaseService.getShopAccessContext(
    userId: userId,
    phone: user?.phone,
  );
});

final shopProvider = FutureProvider<ShopModel?>((ref) async {
  final context = await ref.watch(shopAccessProvider.future);
  if (context == null || context.isDeactivated) return null;
  return context.shop;
});

final currentRoleProvider = Provider<ShopRole?>((ref) {
  return ref.watch(shopAccessProvider).valueOrNull?.role;
});

// ── Dashboard stats provider ──
final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return {};
  return await SupabaseService.getDashboardStats(shop.id);
});

// ── Today's bills provider ──
final todayBillsProvider = FutureProvider((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];
  return await SupabaseService.getTodayBills(shop.id);
});

// ── Date filter for bills: 'today', 'week', 'month' ──
final billsDateFilterProvider = StateProvider<String>((ref) => 'today');

// ── Filtered bills provider (date-wise and type-wise) ──
final filteredBillsProvider = FutureProvider.family<List<BillModel>, String>((ref, billType) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];
  final filter = ref.watch(billsDateFilterProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  DateTime from;
  DateTime to = now;

  switch (filter) {
    case 'week':
      from = today.subtract(const Duration(days: 7));
      break;
    case 'month':
      from = DateTime(now.year, now.month, 1);
      break;
    default:
      from = today;
      break;
  }

  final bills = await SupabaseService.getBills(shop.id, from, to);
  return bills.where((b) => b.billType == billType).toList();
});

// ── Stock items provider ──
final stockItemsProvider = FutureProvider((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];
  return await SupabaseService.getStockItems(shop.id);
});

// ── Item Master provider ──
final itemMasterProvider = FutureProvider((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];
  return await SupabaseService.getMasterItems(shop.id);
});

// ── Udhar customers provider ──
final udharCustomersProvider = FutureProvider((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];
  return await SupabaseService.getUdharCustomers(shop.id);
});

// ── Purchase parties provider ──
final purchasePartiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];
  final response = await Supabase.instance.client
      .from('purchase_parties')
      .select()
      .eq('shop_id', shop.id)
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});
