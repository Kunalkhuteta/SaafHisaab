import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../models/udhar_model.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../globalVar.dart';
import '../sales/sale_entry_screen.dart';

class DashboardItemDetailScreen extends ConsumerStatefulWidget {
  final dynamic item;
  const DashboardItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<DashboardItemDetailScreen> createState() => _DashboardItemDetailScreenState();
}

class _DashboardItemDetailScreenState extends ConsumerState<DashboardItemDetailScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final item = widget.item;

    String title = AppLang.tr(isEn, 'Details', 'विवरण');
    List<Widget> details = [];
    Color headerColor = AppColors.primary;

    if (item is SaleModel) {
      title = AppLang.tr(isEn, 'Sale Details', 'बिक्री विवरण');
      headerColor = AppColors.success;
      details = _buildSaleDetails(item, isEn);
    } else if (item is BillModel) {
      final code = InvType.shortCode(item.billType);
      title = '${AppLang.tr(isEn, 'Bill Details', 'बिल विवरण')} ($code)';
      headerColor = InvType.color(item.billType);
      details = _buildBillDetails(item, isEn);
    } else if (item is UdharCustomerModel) {
      title = AppLang.tr(isEn, 'Credit Details', 'क्रेडिट विवरण');
      headerColor = AppColors.error;
      details = _buildUdharDetails(item, isEn);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        actions: [
          if (item is SaleModel)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: AppLang.tr(isEn, 'Edit Sale', 'बिक्री एडिट'),
              onPressed: () => _editSaleItem(item),
            )
          else if (item is BillModel)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: AppLang.tr(isEn, 'Edit Bill', 'बिल एडिट'),
              onPressed: () => _editBillItem(item),
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: details,
          ),
    );
  }

  void _editSaleItem(SaleModel sale) async {
    // For sales with a bill_id, try to edit through SaleEntryScreen
    if (sale.billId != null && sale.billId!.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final shop = await ref.read(shopProvider.future);
        if (shop == null) throw Exception('Shop not found');
        final List<BillModel> bills = await SupabaseService.getBills(shop.id, DateTime(2000), DateTime(2100));
        final bill = bills.firstWhere((b) => b.id == sale.billId);
        if (mounted) {
          setState(() => _isLoading = false);
          final result = await Navigator.push(context,
            MaterialPageRoute(builder: (_) => SaleEntryScreen(bill: bill)));
          if (result == true) {
            _invalidateAll();
            if (mounted) Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
        debugPrint('Error finding bill: $e');
      }
    }
  }

  void _editBillItem(BillModel bill) async {
    // Use the unified SaleEntryScreen for all bill types
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => SaleEntryScreen(billType: bill.billType, bill: bill),
    ));
    if (result == true) {
      _invalidateAll();
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _invalidateAll() {
    ref.invalidate(todayBillsProvider);
    ref.invalidate(filteredBillsProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(stockItemsProvider);
  }

  Widget _infoTile(String label, String value, [Color valueColor = AppColors.textPrimary]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textHint, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSaleDetails(SaleModel sale, bool isEn) {
    return [
      _infoTile(AppLang.tr(isEn, 'Item Name', 'आइटम का नाम'), sale.itemName),
      _infoTile(AppLang.tr(isEn, 'Quantity', 'मात्रा'), '${sale.quantity.toStringAsFixed(2)} ${sale.unit}'),
      _infoTile(AppLang.tr(isEn, 'Price/Unit', 'मूल्य/इकाई'), '₹${sale.sellingPrice.toStringAsFixed(2)}'),
      _infoTile(AppLang.tr(isEn, 'Total Amount', 'कुल राशि'), '₹${sale.totalAmount.toStringAsFixed(2)}', AppColors.success),
      _infoTile(AppLang.tr(isEn, 'Payment Mode', 'भुगतान मोड'), sale.paymentMode.toUpperCase(), AppColors.primary),
      _infoTile(AppLang.tr(isEn, 'Date', 'तारीख'), _fmtDate(sale.saleDate)),
      if (sale.notes.isNotEmpty)
        _infoTile(AppLang.tr(isEn, 'Notes', 'नोट्स'), sale.notes),
    ];
  }

  List<Widget> _buildBillDetails(BillModel bill, bool isEn) {
    final code = InvType.shortCode(bill.billType);
    final typeColor = InvType.color(bill.billType);
    return [
      _infoTile(AppLang.tr(isEn, 'Type', 'प्रकार'), '${InvType.label(bill.billType, isEn)} ($code)', typeColor),
      if (bill.vendorName.isNotEmpty) _infoTile(AppLang.tr(isEn, 'Party Name', 'पार्टी का नाम'), bill.vendorName),
      _infoTile(AppLang.tr(isEn, 'Amount', 'राशि'), '₹${bill.amount.toStringAsFixed(2)}', typeColor),
      if (bill.isGstBill) _infoTile('GST', '₹${bill.gstAmount.toStringAsFixed(2)}', AppColors.warning),
      _infoTile(AppLang.tr(isEn, 'Date', 'तारीख'), _fmtDate(bill.billDate)),
      if (bill.notes.isNotEmpty) _infoTile(AppLang.tr(isEn, 'Notes', 'नोट्स'), bill.notes),
    ];
  }

  List<Widget> _buildUdharDetails(UdharCustomerModel customer, bool isEn) {
    return [
      _infoTile(AppLang.tr(isEn, 'Customer', 'ग्राहक'), customer.customerName),
      _infoTile(AppLang.tr(isEn, 'Phone', 'फ़ोन'), customer.customerPhone),
      _infoTile(AppLang.tr(isEn, 'Total Due', 'कुल बकाया'), '₹${customer.totalDue.toStringAsFixed(2)}', AppColors.error),
      _infoTile(AppLang.tr(isEn, 'Added On', 'जोड़ा गया'), _fmtDate(customer.createdAt)),
    ];
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
