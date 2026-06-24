import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../services/share_service.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../models/udhar_model.dart';
import '../../globalVar.dart';
import '../../widgets/credit_entry_sheet.dart';
import 'sale_entry_screen.dart';
import 'sale_return_screen.dart';

class SaleDetailScreen extends ConsumerStatefulWidget {
  final BillModel bill;
  const SaleDetailScreen({super.key, required this.bill});
  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  List<SaleModel> _saleItems = [];
  _CreditBillStatus? _creditStatus;
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
          await _loadCreditStatus(linkedSales);
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
      await _loadCreditStatus(sales);
    } catch (e) {
      debugPrint('Load sale items error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCreditStatus(List<SaleModel> sales) async {
    if (sales.isEmpty ||
        !sales.any((sale) =>
            sale.paymentMode == 'credit' || sale.paymentMode == 'split')) {
      return;
    }

    try {
      final shop = await ref.read(shopProvider.future);
      if (shop == null) return;
      final customer =
          await SupabaseService.findCustomerByName(shop.id, widget.bill.vendorName);
      if (customer == null) return;
      final entries = await SupabaseService.getUdharEntriesForCustomer(customer.id);
      UdharEntryModel? creditEntry;
      SavedCreditSale? creditSale;

      for (final entry in entries.where((entry) => entry.entryType == 'credit')) {
        final parsed = SavedCreditSale.tryParseNote(
          entry.note,
          customerId: customer.id,
        );
        if (parsed == null) continue;
        final markerIndex = entry.note.indexOf(SavedCreditSale.noteMarker);
        if (markerIndex >= 0) {
          final jsonText =
              entry.note.substring(markerIndex + SavedCreditSale.noteMarker.length).trim();
          try {
            final payload = jsonDecode(jsonText) as Map<String, dynamic>;
            if (payload['billId'] == widget.bill.id) {
              creditEntry = entry;
              creditSale = parsed;
              break;
            }
          } catch (_) {}
        }
        if ((parsed.totalAmount - widget.bill.amount).abs() < 1.0) {
          creditEntry = entry;
          creditSale = parsed;
        }
      }

      if (creditSale == null) return;

      final payments = entries.where((entry) {
        final meta = UdharPaymentMeta.tryParseNote(entry.note);
        if (entry.entryType != 'debit' || meta == null) return false;
        return meta.appliedCreditEntryId == null ||
            creditEntry == null ||
            meta.appliedCreditEntryId == creditEntry.id;
      }).toList();
      final paid = payments.fold<double>(0, (sum, entry) => sum + entry.amount);
      payments.sort((a, b) => b.entryDate.compareTo(a.entryDate));
      _creditStatus = _CreditBillStatus(
        totalCredit: creditSale.creditAmount,
        paidAmount: paid.clamp(0, creditSale.creditAmount).toDouble(),
        paymentDate: payments.isEmpty ? null : payments.first.entryDate,
      );
    } catch (e) {
      debugPrint('Load credit status error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final bill = widget.bill;
    final isSale = bill.billType == 'sale';
    final namesMap = ref.watch(shopMemberNamesProvider).valueOrNull ?? const <String, String>{};
    final creatorName = namesMap[bill.userId] ?? '';

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
              // ── Created By Info ──
              if (creatorName.isNotEmpty) ...[
                _infoCard(
                  icon: Icons.create_rounded,
                  title: AppLang.tr(isEn, 'Created By', 'किसके द्वारा बनाया गया'),
                  value: creatorName,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
              ],

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

              if (_creditStatus != null) ...[
                _creditStatusCard(_creditStatus!, isEn),
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
                    icon: Icons.assignment_return_rounded,
                    label: AppLang.tr(isEn, 'Return', 'Wapsi'),
                    color: AppColors.warning,
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SaleReturnScreen(initialBill: bill),
                        ),
                      );
                      if (result == true && mounted) {
                        ref.invalidate(filteredBillsProvider);
                        ref.invalidate(dashboardStatsProvider);
                        ref.invalidate(itemMasterProvider);
                        Navigator.pop(context, true);
                      }
                    },
                  )),
                  const SizedBox(width: 10),
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
                        ref.invalidate(itemMasterProvider);
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

  Widget _creditStatusCard(_CreditBillStatus status, bool isEn) {
    final fullyPaid = status.remainingAmount <= 0;
    final hasPartPayment = status.paidAmount > 0 && !fullyPaid;
    final color = fullyPaid
        ? AppColors.success
        : hasPartPayment
            ? AppColors.warning
            : AppColors.error;
    final title = fullyPaid
        ? AppLang.tr(isEn, 'Paid', 'भुगतान')
        : hasPartPayment
            ? AppLang.tr(isEn, 'Part Payment', 'पार्ट पेमेंट')
            : AppLang.tr(isEn, 'Credit', 'उधार');
    final details = fullyPaid
        ? '${AppLang.tr(isEn, 'Paid on', 'भुगतान तारीख')} ${_formatDate(status.paymentDate!)}'
        : hasPartPayment
            ? 'Rs ${status.paidAmount.toStringAsFixed(0)} ${AppLang.tr(isEn, 'paid on', 'भुगतान')} ${_formatDate(status.paymentDate!)} | ${AppLang.tr(isEn, 'Remaining', 'बाकी')} Rs ${status.remainingAmount.toStringAsFixed(0)}'
            : AppLang.tr(isEn, 'Credit amount outstanding', 'उधार राशि बाकी है');

    return _infoCard(
      icon: fullyPaid
          ? Icons.check_circle_outline_rounded
          : hasPartPayment
              ? Icons.paid_outlined
              : Icons.schedule_rounded,
      title: title,
      value: details,
      color: color,
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
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

class _CreditBillStatus {
  final double totalCredit;
  final double paidAmount;
  final DateTime? paymentDate;

  const _CreditBillStatus({
    required this.totalCredit,
    required this.paidAmount,
    this.paymentDate,
  });

  double get remainingAmount =>
      (totalCredit - paidAmount).clamp(0, double.infinity).toDouble();
}
