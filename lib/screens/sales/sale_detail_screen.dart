import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../services/share_service.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../globalVar.dart';
import 'sale_entry_screen.dart';

class SaleDetailScreen extends ConsumerStatefulWidget {
  final BillModel bill;
  const SaleDetailScreen({super.key, required this.bill});
  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  List<SaleModel> _saleItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSaleItems();
  }

  Future<void> _loadSaleItems() async {
    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) return;

      // Try to fetch sales linked to this specific bill by bill_id
      if (widget.bill.id.isNotEmpty) {
        final linkedSales = await SupabaseService.getSalesByBillId(widget.bill.id);
        if (linkedSales.isNotEmpty) {
          _saleItems = linkedSales;
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      // Fallback: fetch all sales for this date (for older sales without bill_id)
      final sales = await SupabaseService.getSales(
        shop.id,
        widget.bill.billDate,
        widget.bill.billDate,
      );
      _saleItems = sales;
    } catch (e) {
      debugPrint('Load sale items error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final bill = widget.bill;
    final isSale = bill.billType == 'sale';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // ── Header ──
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20, right: 20, bottom: 20,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(
                isSale
                    ? AppLang.tr(isEn, 'Sale Details', 'बिक्री विवरण')
                    : AppLang.tr(isEn, 'Bill Details', 'बिल विवरण'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              )),
              // Share
              GestureDetector(
                onTap: () => _shareBill(isEn),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Amount Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(children: [
                Text(
                  AppLang.tr(isEn, 'Total Amount', 'कुल राशि'),
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${bill.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _headerChip(
                    icon: isSale ? Icons.trending_up_rounded : Icons.shopping_bag_rounded,
                    label: isSale
                        ? AppLang.tr(isEn, 'Sale', 'बिक्री')
                        : AppLang.tr(isEn, 'Purchase', 'खरीद'),
                    color: isSale ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                  ),
                  const SizedBox(width: 8),
                  _headerChip(
                    icon: Icons.calendar_today_rounded,
                    label: '${bill.billDate.day.toString().padLeft(2, '0')}/${bill.billDate.month.toString().padLeft(2, '0')}/${bill.billDate.year}',
                    color: Colors.white.withOpacity(0.3),
                  ),
                ]),
                if (bill.id.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '#${bill.id.length > 8 ? bill.id.substring(bill.id.length - 8).toUpperCase() : bill.id.toUpperCase()}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500, letterSpacing: 1.2),
                  ),
                ],
              ]),
            ),
          ]),
        ),

        // ── Body ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Customer / Vendor Info ──
              if (bill.vendorName.isNotEmpty) ...[
                _infoCard(
                  icon: Icons.person_rounded,
                  title: isSale
                      ? AppLang.tr(isEn, 'Customer', 'ग्राहक')
                      : AppLang.tr(isEn, 'Vendor', 'वेंडर'),
                  value: bill.vendorName,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
              ],

              // ── GST Info ──
              if (bill.isGstBill) ...[
                _infoCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'GST',
                  value: '₹${bill.gstAmount.toStringAsFixed(2)}',
                  color: AppColors.warning,
                ),
                const SizedBox(height: 12),
              ],

              // ── Notes ──
              if (bill.notes.isNotEmpty) ...[
                _infoCard(
                  icon: Icons.notes_rounded,
                  title: AppLang.tr(isEn, 'Notes', 'नोट्स'),
                  value: bill.notes,
                  color: AppColors.purple,
                ),
                const SizedBox(height: 12),
              ],

              // ── Sale Items Breakdown ──
              if (isSale) ...[
                const SizedBox(height: 8),
                _sectionHeader(
                  icon: Icons.inventory_2_rounded,
                  title: AppLang.tr(isEn, 'Items Sold', 'बेचे गए आइटम'),
                ),
                const SizedBox(height: 10),
                if (_isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  ))
                else if (_saleItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.textHint, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        AppLang.tr(isEn, 'No item details available', 'आइटम विवरण उपलब्ध नहीं'),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ]),
                  )
                else
                  ..._saleItems.map((sale) => _saleItemCard(sale, isEn)),
              ],

              const SizedBox(height: 24),

              // ── Action Buttons ──
              if (isSale) ...[
                _sectionHeader(
                  icon: Icons.flash_on_rounded,
                  title: AppLang.tr(isEn, 'Quick Actions', 'त्वरित कार्य'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _actionBtn(
                    icon: Icons.add_shopping_cart_rounded,
                    label: AppLang.tr(isEn, 'New Sale', 'नई बिक्री'),
                    color: AppColors.success,
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const SaleEntryScreen()),
                      );
                      if (result == true && mounted) {
                        ref.invalidate(filteredBillsProvider);
                        ref.invalidate(dashboardStatsProvider);
                        ref.invalidate(stockItemsProvider);
                        Navigator.pop(context, true);
                      }
                    },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _actionBtn(
                    icon: Icons.share_rounded,
                    label: AppLang.tr(isEn, 'Share', 'शेयर'),
                    color: const Color(0xFF25D366),
                    onTap: () => _shareBill(isEn),
                  )),
                ]),
              ],

              const SizedBox(height: 30),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _headerChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _infoCard({required IconData icon, required String title, required String value, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ])),
      ]),
    );
  }

  Widget _sectionHeader({required IconData icon, required String title}) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 18),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    ]);
  }

  Widget _saleItemCard(SaleModel sale, bool isEn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_rounded, color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sale.itemName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(
              '${sale.quantity.toStringAsFixed(sale.quantity == sale.quantity.roundToDouble() ? 0 : 2)} ${sale.unit} × ₹${sale.sellingPrice.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${sale.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success)),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _paymentColor(sale.paymentMode).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sale.paymentMode.toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _paymentColor(sale.paymentMode)),
              ),
            ),
          ]),
        ]),
      ]),
    );
  }

  Color _paymentColor(String mode) {
    switch (mode) {
      case 'upi': return const Color(0xFF5C6BC0);
      case 'card': return const Color(0xFFE91E63);
      default: return AppColors.success;
    }
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Future<void> _shareBill(bool isEn) async {
    final bill = widget.bill;
    String itemsText = '';
    if (_saleItems.isNotEmpty) {
      itemsText = _saleItems.map((s) =>
        '• ${s.itemName}: ${s.quantity.toStringAsFixed(s.quantity == s.quantity.roundToDouble() ? 0 : 2)} ${s.unit} × ₹${s.sellingPrice.toStringAsFixed(0)} = ₹${s.totalAmount.toStringAsFixed(0)}'
      ).join('\n');
    }
    await ShareService.shareBill(
      vendorName: bill.vendorName,
      amount: bill.amount,
      billType: bill.billType,
      billDate: bill.billDate,
      isGstBill: bill.isGstBill,
      gstAmount: bill.gstAmount,
      notes: itemsText.isNotEmpty ? '$itemsText\n${bill.notes}' : bill.notes,
    );
  }
}
