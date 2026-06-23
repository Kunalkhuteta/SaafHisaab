import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../../constants/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../models/udhar_model.dart';
import '../../globalVar.dart';
import '../../widgets/credit_entry_sheet.dart';
import 'udhar_detail_screen.dart';
import 'package:saafhisaab/utils/indian_date_time.dart';


class UdharScreen extends ConsumerStatefulWidget {
  const UdharScreen({super.key});
  @override
  ConsumerState<UdharScreen> createState() => _UdharScreenState();
}

class _UdharScreenState extends ConsumerState<UdharScreen> {
  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final udharAsync = ref.watch(udharCustomersProvider);
    
    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(AppLang.tr(isEn, 'Credit Account', 'उधार खाता'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              GestureDetector(
                onTap: () => _openNewCreditEntry(context, isEn),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(AppLang.tr(isEn, 'Add', 'जोड़ें'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: udharAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (customers) => customers.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.people_outline_rounded, color: AppColors.textHint, size: 48),
                    const SizedBox(height: 12),
                    Text(AppLang.tr(isEn, 'No credit records', 'कोई उधार नहीं'), style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  ]))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(udharCustomersProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: customers.length,
                      itemBuilder: (_, i) => _customerCard(customers[i], isEn),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _customerCard(UdharCustomerModel customer, bool isEn) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UdharDetailScreen(customer: customer),
          ),
        ).then((_) {
          ref.invalidate(udharCustomersProvider);
          ref.invalidate(dashboardStatsProvider);
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(
            customer.customerName.isNotEmpty ? customer.customerName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.warning),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customer.customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (customer.customerPhone.isNotEmpty)
            Text(customer.customerPhone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Text('₹${customer.totalDue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint, size: 20),
          onSelected: (val) async {
            if (val == 'paid') {
              await _showPaymentSheet(context, isEn, customer);
            } else if (val == 'edit') {
              _showAddCustomerDialog(context, isEn, customerToEdit: customer);
            } else if (val == 'delete') {
              _deleteCustomer(context, isEn, customer);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'paid', child: Text(AppLang.tr(isEn, '✅ Mark as Paid', '✅ पूरा चुकाया'))),
            PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, size: 18), const SizedBox(width: 8), Text(AppLang.tr(isEn, 'Edit', 'एडिट'))])),
            PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), const SizedBox(width: 8), Text(AppLang.tr(isEn, 'Delete', 'हटाएं'), style: const TextStyle(color: AppColors.error))])),
          ],
        ),
      ]),
      ),
    );
  }

  Future<void> _showPaymentSheet(
    BuildContext context,
    bool isEn,
    UdharCustomerModel customer,
  ) async {
    final userId = AuthService.currentUserId;
    final shop = await ref.read(shopProvider.future);
    if (userId == null || shop == null) {
      _showSnack(AppLang.tr(isEn, 'Shop not found', 'दुकान नहीं मिली'), true);
      return;
    }

    final entries = await SupabaseService.getUdharEntriesForCustomer(customer.id);
    final creditEntries = entries.where((entry) => entry.entryType == 'credit');
    final appliedCreditEntryId =
        creditEntries.isEmpty ? null : creditEntries.first.id;

    if (!context.mounted) return;
    final result = await showModalBottomSheet<_UdharPaymentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _UdharPaymentSheet(
        customer: customer,
        isEn: isEn,
      ),
    );
    if (result == null) return;

    setState(() {});
    try {
      String receiptUrl = '';
      if (result.receiptBytes != null) {
        final compressed = await _compressImage(result.receiptBytes!);
        receiptUrl = await SupabaseService.uploadCreditReceipt(
          shop.id,
          compressed ?? result.receiptBytes!,
          result.receiptExtension,
        );
      }

      await SupabaseService.recordUdharPayment(
        shopId: shop.id,
        userId: userId,
        customer: customer,
        amount: result.amount,
        paymentMethod: result.paymentMethod,
        receiptImageUrl: receiptUrl,
        appliedCreditEntryId: appliedCreditEntryId,
      );
      ref.invalidate(udharCustomersProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        _showSnack(
          AppLang.tr(isEn, 'Payment recorded', 'भुगतान सेव हुआ'),
          false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Payment failed: $e', true);
      }
    }
  }

  Future<Uint8List?> _compressImage(Uint8List list) async {
    try {
      return await FlutterImageCompress.compressWithList(
        list,
        minWidth: 800,
        minHeight: 800,
        quality: 70,
      );
    } catch (e) {
      if (kIsWeb) {
        debugPrint('Web compress failed, using original bytes: $e');
        return list;
      }
      rethrow;
    }
  }

  Future<void> _openNewCreditEntry(BuildContext context, bool isEn) async {
    final userId = AuthService.currentUserId;
    final shop = await ref.read(shopProvider.future);
    final stockItems = await ref.read(itemMasterProvider.future);
    if (userId == null || shop == null) {
      _showSnack(AppLang.tr(isEn, 'Shop not found', 'दुकान नहीं मिली'), true);
      return;
    }

    if (!context.mounted) return;
    final result = await showModalBottomSheet<SavedCreditSale>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => CreditEntrySheet(
        shopId: shop.id,
        userId: userId,
        isEn: isEn,
        initialCustomerName: '',
        initialCustomerPhone: '',
        initialTotal: 0,
        stockItems: stockItems.cast(),
      ),
    );
    if (result == null || result.creditAmount <= 0) return;

    try {
      await _saveDirectCredit(shop.id, userId, result);
      ref.invalidate(udharCustomersProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        _showSnack(
          AppLang.tr(
            isEn,
            'Credit saved for ${result.customerName}',
            '${result.customerName} के लिए उधार सेव हुआ',
          ),
          false,
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnack(
          AppLang.tr(isEn, 'Credit save failed', 'उधार सेव नहीं हुआ'),
          true,
        );
      }
    }
  }

  Future<void> _saveDirectCredit(
    String shopId,
    String userId,
    SavedCreditSale credit,
  ) async {
    UdharCustomerModel? customer =
        await SupabaseService.findCustomerByName(shopId, credit.customerName);
    customer ??=
        await SupabaseService.findCustomerByPhone(shopId, credit.customerPhone);
    customer ??= await SupabaseService.createUdharCustomer(
      shopId: shopId,
      userId: userId,
      customerName: credit.customerName,
      phone: credit.customerPhone,
    );

    final oldDue = await SupabaseService.getCustomerTotalDue(customer.id);
    UdharEntryModel? creditEntry;
    UdharEntryModel? debitEntry;
    try {
      creditEntry = await SupabaseService.addCreditEntry(
        shopId: shopId,
        userId: userId,
        customerId: customer.id,
        amount: credit.creditAmount,
        note: credit.toEntryNote(),
      );
      await SupabaseService.updateCustomerTotalDue(
        customer.id,
        oldDue + credit.creditAmount,
      );
    } catch (_) {
      if (creditEntry != null) await SupabaseService.deleteUdharEntry(creditEntry.id);
      if (debitEntry != null) await SupabaseService.deleteUdharEntry(debitEntry.id);
      await SupabaseService.updateCustomerTotalDue(customer.id, oldDue);
      rethrow;
    }
  }

  void _showSnack(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _deleteCustomer(BuildContext context, bool isEn, UdharCustomerModel customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLang.tr(isEn, 'Delete Record?', 'रिकॉर्ड हटाएं?')),
        content: Text('${AppLang.tr(isEn, 'Delete credit record for', 'उधार रिकॉर्ड हटाएं')} "${customer.customerName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLang.tr(isEn, 'Cancel', 'रद्द करें'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: Text(AppLang.tr(isEn, 'Delete', 'हटाएं'))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deleteUdharCustomer(customer.id);
        ref.invalidate(udharCustomersProvider);
        ref.invalidate(dashboardStatsProvider);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(isEn, 'Record deleted', 'रिकॉर्ड हटा दिया गया')), backgroundColor: AppColors.error));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _showAddCustomerDialog(BuildContext context, bool isEn, {UdharCustomerModel? customerToEdit}) {
    final nameCtrl = TextEditingController(text: customerToEdit?.customerName);
    final phoneCtrl = TextEditingController(text: customerToEdit?.customerPhone);
    final amountCtrl = TextEditingController(text: customerToEdit?.totalDue.toStringAsFixed(0));
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            customerToEdit == null
              ? AppLang.tr(isEn, 'New Credit Customer', 'नया उधार ग्राहक')
              : AppLang.tr(isEn, 'Edit Credit Record', 'उधार रिकॉर्ड एडिट करें'), 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)
          ),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl, decoration: _inputDeco(AppLang.tr(isEn, 'Customer Name *', 'ग्राहक का नाम *'))),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: _inputDeco(AppLang.tr(isEn, 'Phone number', 'फ़ोन नंबर'))),
          const SizedBox(height: 12),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco(AppLang.tr(isEn, 'Credit amount (₹) *', 'उधार राशि (₹) *'))),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
              try {
                final userId = AuthService.currentUserId;
                final shop = await ref.read(shopProvider.future);
                if (userId == null || shop == null) throw Exception('User or shop not found');
                
                final udharData = UdharCustomerModel(
                  id: customerToEdit?.id ?? '', 
                  shopId: shop.id, 
                  userId: userId,
                  customerName: nameCtrl.text.trim(), 
                  customerPhone: phoneCtrl.text.trim(),
                  totalDue: double.tryParse(amountCtrl.text) ?? 0, 
                  createdAt: customerToEdit?.createdAt ?? IndianDateTime.now(),
                );

                if (customerToEdit == null) {
                  await SupabaseService.saveUdharCustomer(udharData);
                } else {
                  await SupabaseService.updateUdharCustomer(udharData);
                }

                ref.invalidate(udharCustomersProvider);
                ref.invalidate(dashboardStatsProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      customerToEdit == null
                        ? AppLang.tr(isEn, 'Customer saved successfully!', 'ग्राहक सफलतापूर्वक सहेजा गया!')
                        : AppLang.tr(isEn, 'Record updated successfully!', 'रिकॉर्ड सफलतापूर्वक अपडेट किया गया!')
                    ),
                    backgroundColor: AppColors.success,
                  ));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Action failed: $e'),
                    backgroundColor: AppColors.error,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: Text(
              customerToEdit == null
                ? AppLang.tr(isEn, 'Save', 'सहेजें')
                : AppLang.tr(isEn, 'Update', 'अपडेट करें'), 
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)
            ),
          )),
        ])),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderBlue)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

class _UdharPaymentDraft {
  final double amount;
  final String paymentMethod;
  final Uint8List? receiptBytes;
  final String receiptExtension;

  const _UdharPaymentDraft({
    required this.amount,
    required this.paymentMethod,
    this.receiptBytes,
    this.receiptExtension = 'jpg',
  });
}

class _UdharPaymentSheet extends StatefulWidget {
  final UdharCustomerModel customer;
  final bool isEn;

  const _UdharPaymentSheet({
    required this.customer,
    required this.isEn,
  });

  @override
  State<_UdharPaymentSheet> createState() => _UdharPaymentSheetState();
}

class _UdharPaymentSheetState extends State<_UdharPaymentSheet> {
  final _amountCtrl = TextEditingController();
  String _method = 'cash';
  Uint8List? _receiptBytes;
  String _receiptExtension = 'jpg';

  bool get _needsReceipt => _method == 'upi' || _method == 'bank';

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.customer.totalDue.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final ext = path.extension(pickedFile.path).replaceAll('.', '');
    final bytes = await pickedFile.readAsBytes();
    setState(() {
      _receiptBytes = bytes;
      _receiptExtension = ext.isEmpty ? 'jpg' : ext;
    });
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.customer.totalDue) {
      _showError(AppLang.tr(
        widget.isEn,
        'Enter amount up to pending balance',
        'बाकी रकम तक राशि दर्ज करें',
      ));
      return;
    }
    Navigator.pop(
      context,
      _UdharPaymentDraft(
        amount: amount,
        paymentMethod: _method,
        receiptBytes: _receiptBytes,
        receiptExtension: _receiptExtension,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPartial =
        (double.tryParse(_amountCtrl.text.trim()) ?? 0) < widget.customer.totalDue;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              AppLang.tr(widget.isEn, 'Record Payment', 'भुगतान दर्ज करें'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${widget.customer.customerName} | Pending Rs ${widget.customer.totalDue.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: _decoration(
                AppLang.tr(widget.isEn, 'Amount Paid', 'भुगतान राशि'),
                Icons.currency_rupee_rounded,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _methodChip('upi', 'UPI', Icons.qr_code_rounded),
                _methodChip('cash', AppLang.tr(widget.isEn, 'Cash', 'नकद'),
                    Icons.payments_rounded),
                _methodChip('bank', AppLang.tr(widget.isEn, 'Bank', 'बैंक'),
                    Icons.account_balance_rounded),
              ],
            ),
            if (_needsReceipt) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickReceipt,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderBlue),
                  ),
                  child: Row(children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _receiptBytes == null
                            ? AppLang.tr(widget.isEn,
                                'Upload receipt image (optional)',
                                'रसीद फोटो अपलोड करें (वैकल्पिक)')
                            : AppLang.tr(widget.isEn, 'Receipt selected',
                                'रसीद चुनी गई'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPartial
                    ? AppColors.warning.withOpacity(0.12)
                    : AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isPartial
                    ? AppLang.tr(widget.isEn, 'Part Payment', 'पार्ट पेमेंट')
                    : AppLang.tr(widget.isEn, 'Full Payment', 'पूरा भुगतान'),
                style: TextStyle(
                  color: isPartial ? AppColors.warning : AppColors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(AppLang.tr(widget.isEn, 'Save Payment',
                    'भुगतान सेव करें')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _methodChip(String value, String label, IconData icon) {
    final selected = _method == value;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => setState(() => _method = value),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
