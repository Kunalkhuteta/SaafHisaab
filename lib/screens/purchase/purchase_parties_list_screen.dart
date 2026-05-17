import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import 'purchase_account_screen.dart';

class PurchasePartiesListScreen extends ConsumerStatefulWidget {
  const PurchasePartiesListScreen({super.key});

  @override
  ConsumerState<PurchasePartiesListScreen> createState() => _PurchasePartiesListScreenState();
}

class _PurchasePartiesListScreenState extends ConsumerState<PurchasePartiesListScreen> {
  List<Map<String, dynamic>> _parties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchParties();
  }

  Future<void> _fetchParties() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final shop = await SupabaseService.getShop(userId);
      if (shop == null) throw Exception('Shop not found');

      final response = await Supabase.instance.client
          .from('purchase_parties')
          .select()
          .eq('shop_id', shop.id)
          .order('created_at', ascending: false);

      setState(() {
        _parties = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddParty() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PurchaseAccountScreen()),
    );
    if (result == true) {
      _fetchParties();
    }
  }

  void _openEditParty(Map<String, dynamic> party) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PurchaseAccountScreen(party: party)),
    );
    if (result == true) {
      _fetchParties();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'Purchase Parties', 'खरीद पार्टियां')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _parties.isEmpty
              ? _buildEmptyState(isEn)
              : RefreshIndicator(
                  onRefresh: _fetchParties,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _parties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final party = _parties[index];
                      return _buildPartyCard(party, isEn);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddParty,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          AppLang.tr(isEn, 'Add Party', 'पार्टी जोड़ें'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isEn) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 80, color: AppColors.textHint.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            AppLang.tr(isEn, 'No purchase parties found', 'कोई खरीद पार्टी नहीं मिली'),
            style: const TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            AppLang.tr(isEn, 'Tap + to add a new party', 'नई पार्टी जोड़ने के लिए + दबाएं'),
            style: const TextStyle(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyCard(Map<String, dynamic> party, bool isEn) {
    final name = party['name'] as String? ?? 'Unknown';
    final number = party['phone_number'] as String?;
    final pendingAmount = (party['pending_amount'] as num?)?.toDouble() ?? 0.0;
    final station = party['station'] as String?;

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openEditParty(party),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (number != null && number.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(number, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ],
                    if (station != null && station.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_city_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(station, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${pendingAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: pendingAmount > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLang.tr(isEn, 'Pending', 'बकाया'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
