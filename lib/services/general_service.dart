import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'global_data.dart';
import 'supabase_service.dart';
import 'app_cache.dart';

class ServiceResponse {
  final int statusCode;
  final String body;
  ServiceResponse({required this.statusCode, this.body = ''});
}

class GeneralService {
  // Bi-directional ID mappings for UUIDs (String) to Integer IDs (int)
  static final Map<int, String> _partyIntIdToUuid = {};
  static final Map<String, int> _partyUuidToIntId = {};
  
  static final Map<int, String> _itemIntIdToUuid = {};
  static final Map<String, int> _itemUuidToIntId = {};

  static final Map<int, String> _transporterIntIdToUuid = {};
  static final Map<String, int> _transporterUuidToIntId = {};

  static String? getPartyUuid(int intId) => _partyIntIdToUuid[intId];
  static int getPartyIntId(String uuid) {
    if (_partyUuidToIntId.containsKey(uuid)) {
      return _partyUuidToIntId[uuid]!;
    }
    final intId = uuid.hashCode.abs();
    _partyUuidToIntId[uuid] = intId;
    _partyIntIdToUuid[intId] = uuid;
    return intId;
  }
  static void setPartyUuidMapping(int intId, String uuid) {
    _partyIntIdToUuid[intId] = uuid;
    _partyUuidToIntId[uuid] = intId;
  }

  static String? getItemUuid(int intId) => _itemIntIdToUuid[intId];
  static int getItemIntId(String uuid) {
    if (_itemUuidToIntId.containsKey(uuid)) {
      return _itemUuidToIntId[uuid]!;
    }
    final intId = uuid.hashCode.abs();
    _itemUuidToIntId[uuid] = intId;
    _itemIntIdToUuid[intId] = uuid;
    return intId;
  }
  static void setItemUuidMapping(int intId, String uuid) {
    _itemIntIdToUuid[intId] = uuid;
    _itemUuidToIntId[uuid] = intId;
  }

  static String? getTransporterUuid(int intId) => _transporterIntIdToUuid[intId];
  static int getTransporterIntId(String uuid) {
    if (_transporterUuidToIntId.containsKey(uuid)) {
      return _transporterUuidToIntId[uuid]!;
    }
    final intId = uuid.hashCode.abs();
    _transporterUuidToIntId[uuid] = intId;
    _transporterIntIdToUuid[intId] = uuid;
    return intId;
  }
  static void setTransporterUuidMapping(int intId, String uuid) {
    _transporterIntIdToUuid[intId] = uuid;
    _transporterUuidToIntId[uuid] = intId;
  }

  // ── Party List ──
  static Future<List<Map<String, dynamic>>> getPartyList({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    final shopId = GlobalData().shopId;
    if (shopId == null) return [];

    final client = Supabase.instance.client;
    final List<Map<String, dynamic>> list = [];

    try {
      if (SPflag == 'SALE') {
        final response = await client
            .from('udhar_customers')
            .select()
            .eq('shop_id', shopId);
        
        for (final row in response) {
          final String uuid = row['id'] ?? '';
          final int intId = getPartyIntId(uuid);
          list.add({
            'PtAccountId': intId,
            'PartyFullName': row['customer_name'] ?? 'Unnamed Customer',
            'GSTNo': row['customer_phone'] ?? '',
            'PtType': 'C',
            'AcOs': true,
            'AcmDeActivate': false,
          });
        }
      } else {
        final response = await client
            .from('purchase_parties')
            .select()
            .eq('shop_id', shopId);
        
        for (final row in response) {
          final String uuid = row['id'] ?? '';
          final int intId = getPartyIntId(uuid);
          list.add({
            'PtAccountId': intId,
            'PartyFullName': row['name'] ?? 'Unnamed Supplier',
            'GSTNo': row['gst_number'] ?? '',
            'PtType': 'S',
            'AcOs': true,
            'AcmDeActivate': false,
          });
        }
      }
    } catch (_) {}

    return list;
  }

  // ── Item Master ──
  static Future<List<Map<String, dynamic>>> getAllItems({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    final shopId = GlobalData().shopId;
    if (shopId == null) return [];

    final client = Supabase.instance.client;
    final List<Map<String, dynamic>> list = [];

    try {
      final response = await client
          .from('item_master')
          .select()
          .eq('shop_id', shopId);
      
      for (final row in response) {
        final String uuid = row['id'] ?? '';
        final int intId = getItemIntId(uuid);
        list.add({
          'id': intId,
          'ItemId': intId,
          'Name': row['item_name'] ?? 'Unnamed Item',
          'ItemName': row['item_name'] ?? 'Unnamed Item',
          'currentStock': (row['current_stock'] as num?)?.toDouble() ?? 0.0,
          'unit': row['item_category'] ?? 'piece',
          'ItemGroupId': 1,
          'ItemGroupName': row['item_group'] ?? 'General',
          'Active': true,
          'HSNcode': 'N/A',
        });
      }
    } catch (_) {}

    return list;
  }

  // ── States ──
  static Future<List<Map<String, dynamic>>> getAllStates({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    return [
      { 'StateId': 1, 'StateName': 'Delhi', 'StateCode': '07' },
      { 'StateId': 2, 'StateName': 'Maharashtra', 'StateCode': '27' },
      { 'StateId': 3, 'StateName': 'Gujarat', 'StateCode': '24' },
      { 'StateId': 4, 'StateName': 'Karnataka', 'StateCode': '29' },
      { 'StateId': 5, 'StateName': 'Uttar Pradesh', 'StateCode': '09' },
      { 'StateId': 6, 'StateName': 'Haryana', 'StateCode': '06' },
      { 'StateId': 7, 'StateName': 'Punjab', 'StateCode': '03' },
      { 'StateId': 8, 'StateName': 'Rajasthan', 'StateCode': '08' },
      { 'StateId': 9, 'StateName': 'West Bengal', 'StateCode': '19' },
      { 'StateId': 10, 'StateName': 'Madhya Pradesh', 'StateCode': '23' },
      { 'StateId': 11, 'StateName': 'Tamil Nadu', 'StateCode': '33' },
      { 'StateId': 12, 'StateName': 'Telangana', 'StateCode': '36' },
      { 'StateId': 13, 'StateName': 'Andhra Pradesh', 'StateCode': '37' },
      { 'StateId': 14, 'StateName': 'Bihar', 'StateCode': '10' },
      { 'StateId': 15, 'StateName': 'Kerala', 'StateCode': '32' },
    ];
  }

  // ── Tax Slabs ──
  static Future<List<Map<String, dynamic>>> getAllTaxTypes({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    return [
      { 'TaxId': 1, 'TaxName': 'GST 18%', 'TaxRate': 18.0, 'CGSTRate': 9.0, 'SGSTRate': 9.0, 'IGSTRate': 18.0 },
      { 'TaxId': 2, 'TaxName': 'GST 12%', 'TaxRate': 12.0, 'CGSTRate': 6.0, 'SGSTRate': 6.0, 'IGSTRate': 12.0 },
      { 'TaxId': 3, 'TaxName': 'GST 5%', 'TaxRate': 5.0, 'CGSTRate': 2.5, 'SGSTRate': 2.5, 'IGSTRate': 5.0 },
      { 'TaxId': 4, 'TaxName': 'GST 28%', 'TaxRate': 28.0, 'CGSTRate': 14.0, 'SGSTRate': 14.0, 'IGSTRate': 28.0 },
      { 'TaxId': 5, 'TaxName': 'Exempt', 'TaxRate': 0.0, 'CGSTRate': 0.0, 'SGSTRate': 0.0, 'IGSTRate': 0.0 },
    ];
  }

  static Future<Map<String, dynamic>?> getTaxTypeById({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    final list = await getAllTaxTypes();
    return list.firstWhere((t) => t['TaxId'] == taxId, orElse: () => list.last);
  }

  // ── Default Configs ──
  static Future<Map<String, dynamic>> getSIHdrSysparamData({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? siSr,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    return {
      'BookId': 1,
      'InvBookId': 1,
      'DefaultGodownId': 1,
    };
  }

  static Future<List<Map<String, dynamic>>> getAllBookMaster({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    return [
      { 'BookId': 1, 'BookName': 'General Sales' },
    ];
  }

  static Future<Map<String, dynamic>> getCurBalanceOfAccount({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    int? accountId,
    String? spFlag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    if (accountId == null) return { 'CurrBal': 0.0, 'CombineCurrBal': 0.0 };
    final uuid = getPartyUuid(accountId);
    if (uuid == null) return { 'CurrBal': 0.0, 'CombineCurrBal': 0.0 };
    try {
      double balance = 0.0;
      if (spFlag == 'SALE' || spFlag == null) {
        balance = await SupabaseService.getCustomerTotalDue(uuid);
      } else {
        balance = await SupabaseService.getPurchasePartyPendingAmount(uuid);
      }
      return {
        'CurrBal': balance,
        'CombineCurrBal': balance,
      };
    } catch (_) {
      return { 'CurrBal': 0.0, 'CombineCurrBal': 0.0 };
    }
  }

  // ── Godowns ──
  static Future<List<Map<String, dynamic>>> getAllGodowns({
    int? coSoftId,
    int? clientRegId,
    int? divId,
    String? StrCond,
    int? AcGroupId,
    String? FormFlag,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    return [
      { 'GodownId': 1, 'GodownName': 'Main Store' },
      { 'GodownId': 2, 'GodownName': 'Godown A' },
    ];
  }

  // ── Item Groups ──
  static Future<List<Map<String, dynamic>>> getItemGroups({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    return [
      { 'ItemGroupId': 1, 'ItemGroupName': 'General' },
    ];
  }

  // ── Calculation Method ──
  static Future<List<Map<String, dynamic>>> getAllCalculate({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    return [];
  }

  static Future<int> getCalculationMethodIdByItemId({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    return 1;
  }

  static Future<List<Map<String, dynamic>>> getAllMastById_AcMast([String? type]) async {
    if (type == 'METHOD') {
      return [
        { 'Id': 1, 'Name': 'Basic rate calculation' },
      ];
    }
    return [];
  }

  // ── Outstanding & Auto-generation Mocks ──
  static Future<Map<String, dynamic>?> getInvDataForOutstanding({
    int? invTranId,
    String? invSr,
    int? dlAccountId,
    int? coSoftId,
  }) async {
    return {
      'GlAccountId': 1,
      'Amount': 0.0,
      'InvDate': DateTime.now().toIso8601String(),
    };
  }

  static Future<bool> addEditGLOS({
    Map<String, dynamic>? glLedgerData,
    int? dueDays,
    int? dlAccountId,
    int? salePersonId,
    int? costCentreId,
    int? coSoftId,
    int? coFinYear,
  }) async {
    return true;
  }

  // ── Mocks / Fallbacks ──
  static Future<List<Map<String, dynamic>>> getAllDalalAccounts({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async => [];

  static Future<List<Map<String, dynamic>>> getAllTransportData({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async {
    final shopId = GlobalData().shopId;
    if (shopId == null) return [];
    try {
      final rows = await SupabaseService.getTransporters(shopId);
      return rows.map((row) {
        final uuid = row['id'] as String;
        final intId = getTransporterIntId(uuid);
        return {
          'Id': intId,
          'id': intId,
          'TransporterId': intId,
          'TransportId': intId,
          'Name': row['name'] ?? '',
          'ContactPerson': row['contact_person'] ?? '',
          'MobileNo': row['mobile_no'] ?? '',
          'Phone1': row['phone1'] ?? '',
          'Phone2': row['phone2'] ?? '',
          'Address': row['address'] ?? '',
          'GSTINNo': row['gstin_no'] ?? '',
          'PanNo': row['pan_no'] ?? '',
          'dbUuid': uuid,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching transporters: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllLocalTransportData({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async => [];

  static Future<List<Map<String, dynamic>>> getAllLocationData({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async => [];

  static Future<List<Map<String, dynamic>>> getAllStationData({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async => [];

  static Future<List<Map<String, dynamic>>> getSalesRepresentatives({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async => [];

  static Future<List<Map<String, dynamic>>> getItemWiseBrands({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async => [];

  static Future<Map<String, dynamic>> getBrokerageRate({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    int? accountId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async => { 'Brokerate': 0.0 };

  static Future<List<Map<String, dynamic>>> getAllTransport() async {
    return getAllTransportData();
  }

  static Future<Map<String, dynamic>?> addEditTransporter(dynamic transporterModel) async {
    final shopId = GlobalData().shopId;
    if (shopId == null) return null;

    final String? uuid = transporterModel.id ?? (transporterModel.transporterId != null ? getTransporterUuid(transporterModel.transporterId!) : null);

    final data = {
      if (uuid != null) 'id': uuid,
      'shop_id': shopId,
      'name': transporterModel.name,
      'contact_person': transporterModel.contactPerson,
      'mobile_no': transporterModel.mobileNo,
      'phone1': transporterModel.phone1,
      'phone2': transporterModel.phone2,
      'address': transporterModel.address,
      'gstin_no': transporterModel.gstinNo,
      'pan_no': transporterModel.panNo,
    };

    try {
      final saved = await SupabaseService.saveTransporter(data);
      if (saved.isNotEmpty) {
        final newUuid = saved['id'] as String;
        final intId = getTransporterIntId(newUuid);
        transporterModel.transporterId = intId;
        transporterModel.id = newUuid;
      }
      AppCache.transportList = null; // Clear cache so page loads fresh list
      return saved;
    } catch (e) {
      debugPrint('Error saving transporter: $e');
      rethrow;
    }
  }

  static Future<void> deleteTransporterByIntId(int transporterId) async {
    final uuid = getTransporterUuid(transporterId);
    if (uuid != null) {
      await SupabaseService.deleteTransporter(uuid);
      AppCache.transportList = null; // Clear cache so page loads fresh list
    }
  }

  static Future<List<Map<String, dynamic>>> getAllAddressMasterByAccountId({int? accountId}) async => [];
  static Future<Map<String, dynamic>?> getItranDataForEInv({int? invTranId}) async => null;
  static Future<bool> updateFieldInAnyTable({String? tbl, String? col, dynamic val, String? cond}) async => true;
  static Future<Map<String, dynamic>> updateEInvData({Map<String, dynamic>? payload}) async => { 'statusCode': 200 };
  
  static Future<ServiceResponse> saveSalesOrder(dynamic payload) async {
    return ServiceResponse(statusCode: 200, body: 'Order saved successfully');
  }

  static Future<List<Map<String, dynamic>>> getAllAccountsData({
    int? clientRegId,
    int? coSoftId,
    int? divId,
    int? coFinyear,
    dynamic userId,
    dynamic ptAccountId,
    bool? commonSalesOrder,
    int? itemId,
    int? taxId,
    int? methodId,
    int? brokerId,
    int? itemGroupId,
    String? SPflag,
    String? date,
    String? bkType,
    String? FormFlag,
    int? AcGroupId,
    String? flag,
    bool? userWise,
    String? stsr,
    String? salePurchFlag,
    bool? forSalesOrder,
    dynamic effDate,
    String? cmtFlag,
    bool? forSales,
    bool? byMethodId,
  }) async => [];
}
