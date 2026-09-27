import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../providers/app_providers.dart';
import '../../models/udhar_model.dart';
import 'sale_account_screen.dart';
import '../reports/party_wise_sales_report_screen.dart';

class SalePartiesListScreen extends ConsumerStatefulWidget {
  const SalePartiesListScreen({super.key});

  @override
  ConsumerState<SalePartiesListScreen> createState() => _SalePartiesListScreenState();
}

class _SalePartiesListScreenState extends ConsumerState<SalePartiesListScreen> {
  List<UdharCustomerModel> _parties = [];
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

      final shop = await ref.read(shopProvider.future);
      if (shop == null) throw Exception('Shop not found');

      final response = await SupabaseService.getAllUdharCustomers(shop.id);

      setState(() {
        _parties = response;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddParty() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SaleAccountScreen()),
    );
    if (result == true) {
      _fetchParties();
    }
  }

  void _openEditParty(UdharCustomerModel party) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SaleAccountScreen(party: party)),
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
        title: Text(AppLang.tr(isEn, 'Sale Parties', 'बिक्री पार्टियां')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: AppLang.tr(isEn, 'Party Wise Sale Report', 'पार्टी वार बिक्री रिपोर्ट'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PartyWiseSalesReportScreen()),
              );
            },
          ),
        ],
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
          AppLang.tr(isEn, 'Add Sale Party', 'बिक्री पार्टी जोड़ें'),
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
            AppLang.tr(isEn, 'No sale parties found', 'कोई बिक्री पार्टी नहीं मिली'),
            style: const TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            AppLang.tr(isEn, 'Tap + to add a new sale party', 'नई बिक्री पार्टी जोड़ने के लिए + दबाएं'),
            style: const TextStyle(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyCard(UdharCustomerModel party, bool isEn) {
    final name = party.customerName;
    final number = party.customerPhone;
    final pendingAmount = party.totalDue;

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
                    if (number.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(number, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                    AppLang.tr(isEn, 'Current Balance', 'वर्तमान शेष'),
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
