import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'global_data.dart';
import 'general_service.dart';
import 'supabase_service.dart';

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

    final String? billId = invTranTbl['InvTranId'] as String?;
    final bool isUpdate = billId != null && billId.isNotEmpty;
    String resolvedBillId = billId ?? '';

    // 1. Prepare bill fields
    final double netAmount = (invTranTbl['EIInvAmt'] ?? sihdr['NetAmt'] ?? 0.0) as double;
    final String vendorName = (invTranTbl['BuyerName'] ?? 'Walk-in Customer') as String;
    final DateTime billDate = DateTime.tryParse(invTranTbl['InvDate']?.toString() ?? '') ?? DateTime.now();

    // Serialize payload inside notes with marker
    final String notes = '__sales_invoice_payload__' + jsonEncode(payload);

    final billData = {
      'shop_id': shopId,
      'user_id': userId,
      'amount': netAmount,
      'bill_date': billDate.toIso8601String().split('T')[0],
      'vendor_name': vendorName,
      'category': 'General',
      'bill_type': 'sale',
      'is_gst_bill': true,
      'gst_amount': (invTranTbl['TotalCGST'] ?? 0.0) + (invTranTbl['TotalSGST'] ?? 0.0) + (invTranTbl['TotalIGST'] ?? 0.0),
      'notes': notes,
    };

    try {
      if (isUpdate) {
        // A. Reverse existing stock additions/deductions for this bill
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
        // B. Insert new Bill row and fetch generated ID
        final insertResult = await client
            .from('bills')
            .insert(billData)
            .select('id')
            .single();
        resolvedBillId = insertResult['id'] as String;
      }

      // 2. Save new sale line items and update inventory
      final String paymentMode = (sihdr['PymtMode'] ?? 'cash') as String;

      for (final wrapper in stockDtlList) {
        final item = wrapper['StockDtl'] as Map<String, dynamic>;
        
        final int itemIntId = (item['ItemId'] ?? item['itemId'] ?? 0) as int;
        final String? itemUuid = GeneralService.getItemUuid(itemIntId);
        final String itemName = (item['ItemName'] ?? item['itemName'] ?? 'Unnamed Item') as String;
        final double qty = (item['STQty'] ?? item['qty'] ?? 1.0) as double;
        final double rate = (item['Rate'] ?? item['rate'] ?? 0.0) as double;
        final double amt = (item['Amount'] ?? item['amount'] ?? 0.0) as double;
        final String unit = (item['SOrdUnitName'] ?? item['rateUnit'] ?? 'piece') as String;

        // Pack item wrapper JSON inside sale notes
        final String itemNotes = '__item_payload__' + jsonEncode(wrapper);

        final saleData = {
          'shop_id': shopId,
          'user_id': userId,
          'item_name': itemName,
          'quantity': qty,
          'unit': unit,
          'selling_price': rate,
          'total_amount': amt,
          'payment_mode': paymentMode,
          'category': 'General',
          'bill_id': resolvedBillId,
          'notes': itemNotes,
          'sale_date': billDate.toIso8601String().split('T')[0],
          if (itemUuid != null && itemUuid.isNotEmpty) 'stock_item_id': itemUuid,
        };

        // Insert sale item
        await client.from('sales').insert(saleData);

        // Deduct inventory stock
        if (itemUuid != null && itemUuid.isNotEmpty) {
          await SupabaseService.deductMasterStockById(itemUuid, qty);
        }
      }

      // 3. Trigger daily balance sync
      try {
        await SupabaseService.syncAndGetDailyBalances(shopId, billDate.month, billDate.year);
      } catch (_) {}

      // 4. Save to sales_invoice_headers table for reliable edit-mode patching
      try {
        final headerData = {
          'bill_id': resolvedBillId,
          'shop_id': shopId,
          'inv_seq_no': (invTranTbl['InvSeqNo'] ?? invTranTbl['InvSeqno'] ?? 0),
          'party_account_id': (invTranTbl['AccountId'] ?? invTranTbl['PtAccountId']),
          'buyer_name': (invTranTbl['BuyerName'] ?? 'Walk-in Customer'),
          'payment_mode': (sihdr['PymtMode'] ?? sihdr['PymtFlag'] ?? 'R'),
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
        // Non-fatal — bills + sales data is already saved
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
      // Fall through to bills-based fallback logic
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
      if (notes.startsWith('__sales_invoice_payload__')) {
        final jsonText = notes.substring('__sales_invoice_payload__'.length);
        final payload = jsonDecode(jsonText);
        
        // Ensure ID is matched in payload for updates
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

        if (sNotes.startsWith('__item_payload__')) {
          final jsonText = sNotes.substring('__item_payload__'.length);
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
            'TaxId': 5, // Exempt
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
