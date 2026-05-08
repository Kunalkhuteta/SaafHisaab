import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';
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