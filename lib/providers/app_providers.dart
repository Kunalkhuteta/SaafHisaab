import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';
import '../models/bill_model.dart';
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
final shopProvider = FutureProvider<ShopModel?>((ref) async {
  final userId = AuthService.currentUserId;
  if (userId == null) return null;
  return await SupabaseService.getShop(userId);
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

// ── Udhar customers provider ──
final udharCustomersProvider = FutureProvider((ref) async {
  final shop = await ref.watch(shopProvider.future);
  if (shop == null) return [];
  return await SupabaseService.getUdharCustomers(shop.id);
});