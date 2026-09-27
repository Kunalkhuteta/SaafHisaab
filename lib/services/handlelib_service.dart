import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'global_data.dart';
import 'general_service.dart';
import 'supabase_service.dart';
import 'package:saafhisaab/utils/indian_date_time.dart';

class HandleLibService {
  static final GlobalData globalData = GlobalData();

  // ── Check Duplicate Invoice Number ──
  static Future<bool> checkDuplicateInvNo(
    dynamic invoiceId,
    int dummy,
    String type,
    int invSeq,
  ) async {
    final shopId = GlobalData().shopId;
    if (shopId == null) return false;

    final client = Supabase.instance.client;
    try {
      final response = await client
          .from('bills')
          .select('id, notes')
          .eq('shop_id', shopId)
          .eq('bill_type', 'sale');

      for (final row in response) {
        final id = row['id'] as String;
        if (id == invoiceId) continue;
        final notes = row['notes'] as String? ?? '';
        if (notes.contains('"InvSeqNo":$invSeq') || notes.contains('"InvSeqno":$invSeq')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // ── Save Sales Invoice ──
  static Future<Map<String, dynamic>> saveSalesInvoice(Map<String, dynamic> payload) async {
    final shopId = GlobalData().shopId;
    final userId = GlobalData().userId;
    if (shopId == null || userId == null) {
      return {
        'statusCode': 400,
        'message': 'No active shop or user session',
      };
    }

    final client = Supabase.instance.client;

    final invTranTbl = payload['InvTranTbl'] as Map<String, dynamic>;
    final sihdr = payload['SIHDR'] as Map<String, dynamic>;
    final stockDtlList = payload['StockDtlList'] as List<dynamic>;

    final String? billId = (invTranTbl['InvTranId'] ?? invTranTbl['id']) as String?;
    final bool isUpdate = billId != null && billId.isNotEmpty;
    String resolvedBillId = billId ?? '';

    // 1. Prepare bill fields
    final double netAmount = (invTranTbl['EIInvAmt'] ?? sihdr['NetAmt'] ?? 0.0).toDouble();
    final String vendorName = (invTranTbl['BuyerName'] ?? 'Walk-in Customer') as String;
    final DateTime billDate = DateTime.tryParse(invTranTbl['InvDate']?.toString() ?? '') ?? IndianDateTime.now();

    // 2. Financial settlement & Payment Mode Normalization
    final double cashReceived = (invTranTbl['CashReceived'] ?? invTranTbl['RecdAmt'] ?? sihdr['CashReceived'] ?? 0.0).toDouble();
    final double ePayAmount = (sihdr['EPymtAmt'] ?? 0.0).toDouble();
    final String rawMode = (sihdr['PymtMode'] ?? sihdr['PymtFlag'] ?? 'C').toString().toUpperCase();

    String normalizedPaymentMode = 'cash';
    if (rawMode == 'C' || rawMode == 'CASH') {
      normalizedPaymentMode = 'cash';
    } else if (rawMode == 'E' || rawMode == 'E-PAYMENT' || rawMode == 'UPI' || rawMode == 'ONLINE' || rawMode == 'CARD') {
      normalizedPaymentMode = 'upi';
    } else if (rawMode == 'R' || rawMode == 'CREDIT') {
      normalizedPaymentMode = 'credit';
    } else if (rawMode == 'D' || rawMode == 'CASH & E-PAY' || rawMode == 'SPLIT') {
      normalizedPaymentMode = 'split';
    } else {
      normalizedPaymentMode = rawMode.toLowerCase();
    }

    double creditAmount = 0.0;
    if (normalizedPaymentMode == 'credit') {
      creditAmount = netAmount;
    } else if (normalizedPaymentMode == 'split') {
      creditAmount = (netAmount - (cashReceived + ePayAmount)).clamp(0.0, netAmount);
    }

    final double totalAdvance = (cashReceived + ePayAmount).clamp(0.0, netAmount);
    final String creditAdvanceMarker = '__saafhisaab_credit_advance:${totalAdvance.toStringAsFixed(2)};credit:${creditAmount.toStringAsFixed(2)}__';

    // Serialize payload inside notes with marker
    final String notes = '${creditAdvanceMarker}__sales_invoice_payload__${jsonEncode(payload)}';

    final billData = {
      'shop_id': shopId,
      'user_id': userId,
      'amount': netAmount,
      'bill_date': billDate.toIso8601String().split('T')[0],
      'vendor_name': vendorName,
      'category': 'General',
      'bill_type': 'sale',
      'is_gst_bill': true,
      'gst_amount': ((invTranTbl['TotalCGST'] ?? 0.0) as num).toDouble() +
          ((invTranTbl['TotalSGST'] ?? 0.0) as num).toDouble() +
          ((invTranTbl['TotalIGST'] ?? 0.0) as num).toDouble(),
      'notes': notes,
    };

    DateTime? oldBillDate;

    try {
      if (isUpdate) {
        // A. Fetch old bill date for daily balance comparison
        final oldBillRow = await client
            .from('bills')
            .select('bill_date')
            .eq('id', resolvedBillId)
            .maybeSingle();
        if (oldBillRow != null && oldBillRow['bill_date'] != null) {
          oldBillDate = DateTime.tryParse(oldBillRow['bill_date'].toString());
        }

        // B. Reverse existing stock movement for this bill
        final oldSales = await client
            .from('sales')
            .select('stock_item_id, quantity')
            .eq('bill_id', resolvedBillId);

        for (final os in oldSales) {
          final String? itemUuid = os['stock_item_id'];
          final double qty = (os['quantity'] as num?)?.toDouble() ?? 0.0;
          if (itemUuid != null && itemUuid.isNotEmpty) {
            await SupabaseService.addMasterStockById(itemUuid, qty);
          }
        }

        // Delete old sale line items
        await client.from('sales').delete().eq('bill_id', resolvedBillId);

        // Update the Bill row
        await client.from('bills').update(billData).eq('id', resolvedBillId);
      } else {
        // C. Insert new Bill row and fetch generated ID
        final insertResult = await client
            .from('bills')
            .insert(billData)
            .select('id')
            .single();
        resolvedBillId = insertResult['id'] as String;
      }

      // 3. Save new sale line items and deduct inventory stock
      for (final wrapper in stockDtlList) {
        final item = wrapper['StockDtl'] as Map<String, dynamic>;

        final int itemIntId = (item['ItemId'] ?? item['itemId'] ?? 0) as int;
        String? itemUuid = GeneralService.getItemUuid(itemIntId);
        final String itemName = (item['ItemName'] ?? item['itemName'] ?? 'Unnamed Item') as String;
        final double qty = ((item['STQty'] ?? item['qty'] ?? 1.0) as num).toDouble();
        final double rate = ((item['Rate'] ?? item['rate'] ?? 0.0) as num).toDouble();
        final double amt = ((item['Amount'] ?? item['amount'] ?? 0.0) as num).toDouble();
        final String unit = (item['SOrdUnitName'] ?? item['rateUnit'] ?? 'piece') as String;

        // Fallback: If UUID mapping was missing, find or auto-create item in item_master
        if (itemUuid == null || itemUuid.isEmpty) {
          final existingItem = await client
              .from('item_master')
              .select('id')
              .eq('shop_id', shopId)
              .ilike('item_name', itemName.trim())
              .maybeSingle();

          if (existingItem != null) {
            itemUuid = existingItem['id'] as String;
          } else {
            final newItem = await client
                .from('item_master')
                .insert({
                  'shop_id': shopId,
                  'user_id': userId,
                  'item_name': itemName.trim(),
                  'current_stock': 0,
                  'item_category': unit,
                  'item_group': (item['ItemGroupName'] ?? 'General').toString(),
                })
                .select('id')
                .single();
            itemUuid = newItem['id'] as String;
          }
          if (itemUuid.isNotEmpty) {
            GeneralService.setItemUuidMapping(itemIntId, itemUuid);
          }
        }

        // Pack item wrapper JSON inside sale notes
        final String itemNotes = '${creditAdvanceMarker}__item_payload__${jsonEncode(wrapper)}';

        final saleData = {
          'shop_id': shopId,
          'user_id': userId,
          'item_name': itemName,
          'quantity': qty,
          'unit': unit,
          'selling_price': rate,
          'total_amount': amt,
          'payment_mode': normalizedPaymentMode,
          'category': (item['ItemGroupName'] ?? 'General').toString(),
          'bill_id': resolvedBillId,
          'notes': itemNotes,
          'sale_date': billDate.toIso8601String().split('T')[0],
          if (itemUuid.isNotEmpty) 'stock_item_id': itemUuid,
        };

        // Insert sale item
        await client.from('sales').insert(saleData);

        // Deduct inventory stock
        if (itemUuid.isNotEmpty) {
          await SupabaseService.deductMasterStockById(itemUuid, qty);
        }
      }

      // 4. Update Udhar / Credit Ledger for Customer
      try {
        final dynamic ptAccRaw = invTranTbl['AccountId'] ?? invTranTbl['PtAccountId'] ?? sihdr['PtAccountId'];
        final int? partyIntId = ptAccRaw != null ? int.tryParse(ptAccRaw.toString()) : null;
        String? customerUuid;
        if (partyIntId != null && partyIntId > 0) {
          customerUuid = GeneralService.getPartyUuid(partyIntId);
        }

        if (customerUuid == null || customerUuid.isEmpty) {
          final customerMatch = await client
              .from('udhar_customers')
              .select('id')
              .eq('shop_id', shopId)
              .ilike('customer_name', vendorName.trim())
              .maybeSingle();

          if (customerMatch != null) {
            customerUuid = customerMatch['id'] as String;
          } else if (creditAmount > 0) {
            // Auto-create customer in udhar_customers
            final newCust = await client
                .from('udhar_customers')
                .insert({
                  'shop_id': shopId,
                  'user_id': userId,
                  'customer_name': vendorName.trim(),
                  'customer_phone': (invTranTbl['BuyerGstNo'] ?? '').toString(),
                  'total_due': 0,
                })
                .select('id')
                .single();
            customerUuid = newCust['id'] as String;
          }
          if (partyIntId != null && customerUuid != null) {
            GeneralService.setPartyUuidMapping(partyIntId, customerUuid);
          }
        }

        // Remove previous credit entries for this bill
        final oldEntries = await client
            .from('udhar_entries')
            .select('id, customer_id')
            .eq('shop_id', shopId)
            .ilike('note', '%__saafhisaab_credit_bill:${resolvedBillId}__%');

        final Set<String> affectedCustomerIds = {};
        for (final entry in oldEntries) {
          final cId = entry['customer_id'] as String?;
          if (cId != null) affectedCustomerIds.add(cId);
          await client.from('udhar_entries').delete().eq('id', entry['id']);
        }

        // If this bill has credit amount, insert credit entry
        if (creditAmount > 0 && customerUuid != null && customerUuid.isNotEmpty) {
          affectedCustomerIds.add(customerUuid);
          final String invSeq = (invTranTbl['InvSeqNo'] ?? invTranTbl['InvSeqno'] ?? '').toString();
          await client.from('udhar_entries').insert({
            'shop_id': shopId,
            'user_id': userId,
            'customer_id': customerUuid,
            'entry_type': 'credit',
            'amount': creditAmount,
            'entry_date': billDate.toIso8601String().split('T')[0],
            'note': '__saafhisaab_credit_bill:${resolvedBillId}__ Invoice #${invSeq.isNotEmpty ? invSeq : 'SIN'} - $vendorName',
          });
        }

        // Recalculate customer balances for all affected customers
        for (final cId in affectedCustomerIds) {
          await SupabaseService.recalculateCustomerTotalDue(cId);
        }
      } catch (e) {
        debugPrint('Udhar credit sync error (non-fatal): $e');
      }

      // 5. Trigger daily balance sync (for new date and old date if changed)
      try {
        await SupabaseService.syncAndGetDailyBalances(shopId, billDate.month, billDate.year);
        if (oldBillDate != null && (oldBillDate.month != billDate.month || oldBillDate.year != billDate.year)) {
          await SupabaseService.syncAndGetDailyBalances(shopId, oldBillDate.month, oldBillDate.year);
        }
      } catch (_) {}

      // 6. Save to sales_invoice_headers table for reliable edit-mode patching
      try {
        final headerData = {
          'bill_id': resolvedBillId,
          'shop_id': shopId,
          'inv_seq_no': (invTranTbl['InvSeqNo'] ?? invTranTbl['InvSeqno'] ?? 0),
          'party_account_id': (invTranTbl['AccountId'] ?? invTranTbl['PtAccountId']),
          'buyer_name': (invTranTbl['BuyerName'] ?? 'Walk-in Customer'),
          'payment_mode': normalizedPaymentMode,
          'net_amount': netAmount,
          'inv_date': billDate.toIso8601String().split('T')[0],
          'sihdr_data': sihdr,
          'inv_tran_data': invTranTbl,
          'stock_dtl_data': stockDtlList,
        };

        if (isUpdate) {
          final existing = await client
              .from('sales_invoice_headers')
              .select('id')
              .eq('bill_id', resolvedBillId)
              .maybeSingle();

          if (existing != null) {
            await client
                .from('sales_invoice_headers')
                .update(headerData)
                .eq('bill_id', resolvedBillId);
          } else {
            await client
                .from('sales_invoice_headers')
                .insert(headerData);
          }
        } else {
          await client
              .from('sales_invoice_headers')
              .insert(headerData);
        }
      } catch (e) {
        debugPrint('sales_invoice_headers save error (non-fatal): $e');
      }

      return {
        'statusCode': 200,
        'message': 'Invoice saved successfully',
        'billId': resolvedBillId,
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'message': 'Error saving invoice: $e',
      };
    }
  }

  // ── Delete Sales Invoice ──
  static Future<Map<String, dynamic>> deleteSalesInvoice(String billId) async {
    final client = Supabase.instance.client;

    try {
      // 1. Fetch bill details
      final bill = await client
          .from('bills')
          .select('id, shop_id, bill_date, vendor_name')
          .eq('id', billId)
          .maybeSingle();

      if (bill == null) {
        return {
          'statusCode': 404,
          'message': 'Invoice not found',
        };
      }

      final String shopId = bill['shop_id'] as String;
      final DateTime billDate = DateTime.tryParse(bill['bill_date'].toString()) ?? IndianDateTime.now();

      // 2. Reverse inventory stock from line items
      final sales = await client
          .from('sales')
          .select('stock_item_id, quantity')
          .eq('bill_id', billId);

      for (final s in sales) {
        final String? itemUuid = s['stock_item_id'];
        final double qty = (s['quantity'] as num?)?.toDouble() ?? 0.0;
        if (itemUuid != null && itemUuid.isNotEmpty) {
          await SupabaseService.addMasterStockById(itemUuid, qty);
        }
      }

      // 3. Remove linked Udhar / Credit entries and recalculate customer balance
      final oldEntries = await client
          .from('udhar_entries')
          .select('id, customer_id')
          .eq('shop_id', shopId)
          .ilike('note', '%__saafhisaab_credit_bill:$billId%');

      final Set<String> affectedCustomerIds = {};
      for (final entry in oldEntries) {
        final cId = entry['customer_id'] as String?;
        if (cId != null) affectedCustomerIds.add(cId);
        await client.from('udhar_entries').delete().eq('id', entry['id']);
      }
      for (final cId in affectedCustomerIds) {
        await SupabaseService.recalculateCustomerTotalDue(cId);
      }

      // 4. Delete sales_invoice_headers
      await client.from('sales_invoice_headers').delete().eq('bill_id', billId);

      // 5. Delete child sales rows
      await client.from('sales').delete().eq('bill_id', billId);

      // 6. Delete parent bill row
      await client.from('bills').delete().eq('id', billId);

      // 7. Re-sync daily balances
      try {
        await SupabaseService.syncAndGetDailyBalances(shopId, billDate.month, billDate.year);
      } catch (_) {}

      return {
        'statusCode': 200,
        'message': 'Invoice deleted successfully',
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'message': 'Error deleting invoice: $e',
      };
    }
  }

  // ── Load Sales Invoice by ID ──
  static Future<Map<String, dynamic>> getSalesInvoiceByInvTranId(String invoiceId) async {
    final client = Supabase.instance.client;

    // ── Try loading from sales_invoice_headers first (preferred) ──
    try {
      final header = await client
          .from('sales_invoice_headers')
          .select()
          .eq('bill_id', invoiceId)
          .maybeSingle();

      if (header != null) {
        final Map<String, dynamic> invTranData =
            Map<String, dynamic>.from(header['inv_tran_data'] ?? {});
        final Map<String, dynamic> sihdrData =
            Map<String, dynamic>.from(header['sihdr_data'] ?? {});
        final List<dynamic> stockDtlData =
            List<dynamic>.from(header['stock_dtl_data'] ?? []);

        // Ensure IDs are stamped for update-mode
        invTranData['InvTranId'] = invoiceId;
        invTranData['id'] = invoiceId;
        sihdrData['InvTranId'] = invoiceId;
        sihdrData['InvId'] = invoiceId;

        return {
          'statusCode': 200,
          'data': {
            'InvTranTbl': invTranData,
            'SIHDR': sihdrData,
            'StockDtlList': stockDtlData,
          },
        };
      }
    } catch (e) {
      debugPrint('sales_invoice_headers load error (falling back): $e');
    }

    // ── Fallback: load from bills.notes ──
    try {
      final bill = await client
          .from('bills')
          .select()
          .eq('id', invoiceId)
          .maybeSingle();

      if (bill == null) {
        return {
          'statusCode': 404,
          'message': 'Invoice not found',
        };
      }

      final String notes = bill['notes'] ?? '';
      const payloadMarker = '__sales_invoice_payload__';
      final payloadIndex = notes.indexOf(payloadMarker);

      if (payloadIndex >= 0) {
        final jsonText = notes.substring(payloadIndex + payloadMarker.length);
        final payload = jsonDecode(jsonText);

        payload['InvTranTbl']['InvTranId'] = invoiceId;
        payload['InvTranTbl']['id'] = invoiceId;
        payload['SIHDR']['InvTranId'] = invoiceId;
        payload['SIHDR']['InvId'] = invoiceId;

        return {
          'statusCode': 200,
          'data': payload,
        };
      }

      // Backward Compatibility: build custom payload from standard bills and sales records
      final sales = await client
          .from('sales')
          .select()
          .eq('bill_id', invoiceId);

      final String vendorName = bill['vendor_name'] ?? 'Walk-in Customer';
      final int partyIntId = GeneralService.getPartyIntId(vendorName);

      final invTranMap = {
        'InvTranId': invoiceId,
        'InvTranIdNo': invoiceId,
        'InvId': invoiceId,
        'id': invoiceId,
        'AccountId': partyIntId,
        'PtAccountId': partyIntId,
        'EIDocNo': 'AUTO',
        'InvSeqNo': 0,
        'InvBookId': 1,
        'BookId': 1,
        'EIDocDate': bill['bill_date'],
        'InvDate': bill['bill_date'],
        'InvTime': '12:00:00',
        'Time': '12:00:00',
        'InvSR': 'SIN',
        'BuyerName': vendorName,
        'EIInvAmt': bill['amount'],
      };

      final sihdrMap = {
        'InvTranId': invoiceId,
        'InvId': invoiceId,
        'InvTranIdNo': invoiceId,
        'id': invoiceId,
        'InvSeqNo': 0,
        'InvBookId': 1,
        'BookId': 1,
        'InvDate': bill['bill_date'],
        'PtAccountId': partyIntId,
        'PymtMode': sales.isNotEmpty ? sales.first['payment_mode'] : 'cash',
        'NetAmt': bill['amount'],
        'EIInvAmt': bill['amount'],
      };

      final List<Map<String, dynamic>> stockDtlList = [];
      for (int i = 0; i < sales.length; i++) {
        final s = sales[i];
        final String itemUuid = s['stock_item_id'] ?? '';
        final int itemIntId = GeneralService.getItemIntId(itemUuid);

        final String sNotes = s['notes'] ?? '';
        Map<String, dynamic> stockDtl = {};
        List<dynamic> stock2 = [];
        List<dynamic> sidtl = [];

        const itemPayloadMarker = '__item_payload__';
        final itemPayloadIndex = sNotes.indexOf(itemPayloadMarker);

        if (itemPayloadIndex >= 0) {
          final jsonText = sNotes.substring(itemPayloadIndex + itemPayloadMarker.length);
          final decoded = jsonDecode(jsonText);
          stockDtl = decoded['StockDtl'] ?? decoded;
          stock2 = decoded['Stock2'] ?? [];
          sidtl = decoded['SIDtl'] ?? [];
        } else {
          stockDtl = {
            'id': s['id'].hashCode.abs(),
            'InvDtlId': s['id'].hashCode.abs(),
            'InvDtlIdNo': s['id'].hashCode.abs(),
            'InvTranIdNo': invoiceId,
            'InvId': invoiceId,
            'itemId': itemIntId,
            'ItemId': itemIntId,
            'itemName': s['item_name'],
            'ItemName': s['item_name'],
            'bag': 0,
            'STBag': 0,
            'qty': s['quantity'],
            'STQty': s['quantity'],
            'rate': s['selling_price'],
            'Rate': s['selling_price'],
            'amount': s['total_amount'],
            'Amount': s['total_amount'],
            'TaxId': 5,
            'cgstAmt': 0.0,
            'sgstAmt': 0.0,
            'igstAmt': 0.0,
          };
        }

        stockDtlList.add({
          'id': invoiceId,
          'STIRIdNo': invoiceId,
          'StockDtl': stockDtl,
          'Stock2': stock2,
          'SIDtl': sidtl,
          'ItemName': s['item_name'],
        });
      }

      return {
        'statusCode': 200,
        'data': {
          'InvTranTbl': invTranMap,
          'SIHDR': sihdrMap,
          'StockDtlList': stockDtlList,
        }
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'message': 'Error loading invoice: $e',
      };
    }
  }
}
