import 'package:flutter/material.dart';
import 'package:saafhisaab/services/general_service.dart';
import 'package:saafhisaab/services/system_params_service.dart';
import 'package:saafhisaab/services/order_sysparam_service.dart';
import 'package:saafhisaab/services/app_cache.dart';
import 'package:saafhisaab/widgets/app_loader.dart';
import 'package:saafhisaab/services/global_data.dart';
import 'package:intl/intl.dart';
import 'package:saafhisaab/screens/orderPages/allHeaderDetailRecord.dart';
import 'package:saafhisaab/screens/orderPages/salesOrder/AddItemDialog.dart';
import 'package:saafhisaab/screens/orderPages/salesOrder/createSalesOrderModel.dart'
    hide AddItemResult, AddItemAction;
import 'package:saafhisaab/screens/orderPages/salesPurchaseOrderClass.dart';
import 'package:saafhisaab/screens/orderPages/salesPurchaseOrderDetails.dart';
import 'package:flutter/foundation.dart';
import 'package:saafhisaab/screens/orderPages/widgets/IndianNumberFormat.dart';
import 'package:saafhisaab/screens/orderPages/widgets/PartySearchDialog.dart';
import 'package:saafhisaab/screens/orderPages/widgets/TransportSearchDialog.dart';

// ── Broker search screen (simple list, same pattern as PartySearchScreen) ──
class BrokerSearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> brokers;
  const BrokerSearchScreen({super.key, required this.brokers});

  @override
  State<BrokerSearchScreen> createState() => _BrokerSearchScreenState();
}

class _BrokerSearchScreenState extends State<BrokerSearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.brokers;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      final searchLower = query.toLowerCase();
      _filtered =
          widget.brokers.where((b) {
            final name =
                (b['AcName'] ?? b['Name'] ?? '').toString().toLowerCase();
            return name.contains(searchLower);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        title: const Text(
          'Select Broker',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search broker...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child:
                _filtered.isEmpty
                    ? const Center(
                      child: Text(
                        'No broker found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 1,
                            color: Colors.grey.shade200,
                            indent: 16,
                            endIndent: 16,
                          ),
                      itemBuilder: (_, i) {
                        final broker = _filtered[i];
                        final name =
                            broker['AcName'] ?? broker['Name'] ?? 'Unknown';
                        return InkWell(
                          onTap: () => Navigator.pop(context, broker),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.person_outline,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────

class OrderFormPage extends StatefulWidget {
  final String orderType; // 'SALES' or 'PURCHASE'
  final int? initialPartyId;
  final String? initialPartyName;
  final String? partyGSTNo;
  final int? orderId;
  final Map<String, dynamic>? orderHeaderData;
  final List<Map<String, dynamic>>? orderDetailsData;

  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  const OrderFormPage({
    super.key,
    required this.orderType,
    this.initialPartyId,
    this.initialPartyName,
    this.partyGSTNo,
    this.orderId,
    this.orderHeaderData,
    this.orderDetailsData,
    this.canAdd = true,
    this.canEdit = false,
    this.canDelete = false,
  });

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final GlobalData _global = GlobalData();
  final _sysParamService = SysparamService();
  final FocusNode _refNoFocusNode = FocusNode();

  // ─── Derived rights ────────────────────────────────────────────────────────
  bool get _canSaveOrder => isEditMode ? widget.canEdit : true;
  bool get _canAddItem => isEditMode ? widget.canEdit : true;
  bool get _canOpenItemEdit => true;
  bool get _canDeleteItem => isEditMode ? widget.canEdit : true;
  bool get _readOnlyMode => isEditMode && !widget.canEdit;

  // ─── Helpers ───────────────────────────────────────────────────────────────
  String get _ordSR =>
      widget.orderType == 'SALES' ? 'SALESORDER' : 'PURCHASEORDER';
  String get _spFlag => widget.orderType == 'SALES' ? 'SALE' : 'PURCHASE';
  String get _pageTitle =>
      widget.orderType == 'SALES' ? 'Sales Order' : 'Purchase Order';
  Color get _primaryColor => Colors.blue;

  // ─── Static data ───────────────────────────────────────────────────────────
  final deliveryModeData = const [
    {'id': 'Buyer', 'name': 'Ex-Buyer PLANT'},
    {'id': 'Seller', 'name': 'Ex-Seller PLANT'},
    {'id': 'Plant', 'name': 'Ex-PLANT'},
    {'id': 'Local', 'name': 'Ex-LOCAL'},
    {'id': 'OnSite', 'name': 'Ex-ONSITE'},
    {'id': 'Depo', 'name': 'Ex-Depo'},
  ];

  final paymentModeData = const [
    {'id': 'ADV', 'name': 'Advance'},
    {'id': 'CRD', 'name': 'Credit'},
  ];

  // ─── State ─────────────────────────────────────────────────────────────────
  final List<OrderItem> items = [];
  List<Map<String, dynamic>> partyList = [];
  Map<int, Map<String, dynamic>> partyById = {};
  List<Map<String, dynamic>> salesRepList = [];
  List<Map<String, dynamic>> salesPersonList = [];

  // ── Broker list — loaded from GeneralService.getAllDalalAccounts()
  // Mirrors Angular: initialiseDropdown() → BrokerData = GetAllDalalAccounts$()
  List<Map<String, dynamic>> brokerList = [];

  List<Map<String, dynamic>> transportList = [];

  int? selectedPartyId;
  String? selectedPartyName;
  String? selectedPartyGSTNo;
  String? selectedPartyPANNo;
  String? selectedPartyTINNo;
  String? selectedPartyCategoryName;
  double currentBalance = 0;
  double combinedBalance = 0;

  // ── Broker — pre-filled from party's DLAccountId (same as Angular)
  int? selectedBrokerId;
  String? selectedBrokerName;

  int? selectedSalesRepId;
  int? selectedSalesPersonId;
  int? selectedTransportId;
  String? selectedDeliveryMode = 'Local';
  String? selectedPaymentMode = 'CRD';

  DateTime orderDate = DateTime.now();
  DateTime refDate = DateTime.now();
  DateTime deliveryDate = DateTime.now();
  DateTime toDate = DateTime.now().add(const Duration(days: 3));

  final orderNoController = TextEditingController(text: 'AUTO');
  final refNoController = TextEditingController();
  final remarkController = TextEditingController();

  late final Future<void> _initFuture;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  bool get isEditMode => widget.orderId != null && widget.orderId! > 0;
  Map<int, String> itemNameById = {};

  bool _brokerWiseOrders = false;

  double totalBags = 0;
  double totalQty = 0;
  double totalAmount = 0;
  double totalWeight = 0;
  double totalPcsRate = 0;
  int totalNoOfPcs = 0;

  // ── Sys param for broker visibility
  // Mirrors Angular: Sysparamdata.SI_ReadBroker && OrdHdr_SysParms[0].BrokerWiseOrders
  bool get _showBrokerField {
    final siReadBroker =
        _sysParamService.cachedData?.sysparam.siReadBroker ?? false;
    return siReadBroker && _brokerWiseOrders;
  }

  @override
  void initState() {
    super.initState();
    _initFuture = _initializePage();
  }

  @override
  void dispose() {
    _refNoFocusNode.dispose();
    orderNoController.dispose();
    refNoController.dispose();
    remarkController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await Future.wait([_loadItemMaster(), _loadInitialData()]);

    if (isEditMode) {
      await _prefillOrderData();
    } else {
      selectedPartyId = widget.initialPartyId;
      selectedPartyName = widget.initialPartyName;
      selectedPartyGSTNo = widget.partyGSTNo;
      if (selectedPartyId != null) await _loadPartyDetails(selectedPartyId!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !isEditMode) _refNoFocusNode.requestFocus();
    });
  }

  Future<void> _loadItemMaster() async {
    try {
      if (AppCache.hasItems(widget.orderType)) {
        final cached = AppCache.getItems(widget.orderType);
        itemNameById = {
          for (final i in cached)
            (i['id'] as num).toInt(): (i['Name'] ?? '').toString(),
        };
        return;
      }

      int partyId = 0;
      if (widget.orderType == 'SALES') {
        partyId =
            isEditMode
                ? (widget.orderHeaderData?['PtAccountId'] ?? 0)
                : (widget.initialPartyId ?? 0);
      }

      final loadedItems = await GeneralService.getAllItems(
        clientRegId: _global.clientRegId ?? 0,
        coSoftId: _global.coSoftId ?? 0,
        coFinyear: _global.CofinYear ?? 0,
        userId: _global.mobileAppUserId ?? 0,
        divId: _global.divId ?? 0,
        ptAccountId: widget.orderType == 'SALES' ? partyId : 0,
        itemGroupId: 0,
        userWise: true,
        forSalesOrder: true,
        commonSalesOrder: _global.CommonSalesOrder ?? false,
        SPflag: _spFlag,
      );

      AppCache.setItems(widget.orderType, loadedItems);
      itemNameById = {
        for (final i in loadedItems)
          (i['id'] as num).toInt(): (i['Name'] ?? '').toString(),
      };
    } catch (e) {
      debugPrint('Error loading item master: $e');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final fetchedParties = await _loadParties();
      final result = await compute(_preparePartyCache, fetchedParties);
      partyList = fetchedParties;
      partyById = Map<int, Map<String, dynamic>>.from(result['partyById']);

      try {
        await OrderSysParamService().getOrderSysParams(srFlag: _ordSR);
        _brokerWiseOrders = OrderSysParamService().brokerWiseOrders;
      } catch (e) {
        debugPrint('OrderSysParam load error: $e');
        _brokerWiseOrders = false;
      }

      await Future.wait([
        _loadBrokers(), // load brokers alongside other dropdowns
        _loadSalesReps(),
        _loadSalesPersons(),
        _loadTransports(),
      ]);
    } catch (e) {
      debugPrint('Error in _loadInitialData: $e');
    }
  }

  static Map<String, dynamic> _preparePartyCache(
    List<Map<String, dynamic>> partyList,
  ) {
    final partyById = <int, Map<String, dynamic>>{};
    for (final p in partyList) {
      final id = p['PtAccountId'] as int;
      partyById[id] = p;
    }
    return {'partyById': partyById};
  }

  Future<List<Map<String, dynamic>>> _loadParties() async {
    if (AppCache.hasPartyList(widget.orderType)) {
      return AppCache.getPartyList(widget.orderType);
    }

    final data = await GeneralService.getPartyList(
      clientRegId: _global.clientRegId ?? 0,
      coSoftId: _global.coSoftId ?? 0,
      SPflag: _spFlag,
    );

    List<Map<String, dynamic>> filtered;
    if (widget.orderType == 'SALES') {
      filtered =
          data.where((p) => p['PtType'] == 'C' || p['PtType'] == 'B').toList();
    } else {
      filtered =
          data.where((p) => p['PtType'] == 'S' || p['PtType'] == 'B').toList();
    }

    AppCache.setPartyList(widget.orderType, filtered);
    return filtered;
  }

  Future<void> _loadSalesReps() async {
    try {
      if (AppCache.salesRepresentatives != null) {
        salesRepList = AppCache.salesRepresentatives!;
      } else {
        final data = await GeneralService.getSalesRepresentatives(
          coSoftId: _global.coSoftId ?? 0,
          commonSalesOrder: _global.CommonSalesOrder ?? false,
        );
        AppCache.salesRepresentatives = data;
        salesRepList = data;
      }
    } catch (e) {
      debugPrint('Error loading sales reps: $e');
    }
  }

  Future<void> _loadSalesPersons() async {
    try {
      salesPersonList = [];
    } catch (e) {
      debugPrint('Error loading sales persons: $e');
    }
  }

  // ── Load brokers — mirrors Angular: GetAllDalalAccounts$()
  // Returns accounts with AcGroupId = dalal/broker group.
  // Cached in AppCache.brokerList to avoid repeated API calls.
  Future<void> _loadBrokers() async {
    try {
      if (AppCache.brokerList != null && AppCache.brokerList!.isNotEmpty) {
        brokerList = AppCache.brokerList!;
        return;
      }
      final data = await GeneralService.getAllDalalAccounts(
        clientRegId: _global.clientRegId ?? 0,
        coSoftId: _global.coSoftId ?? 0,
        divId: _global.divId ?? 0, // matches Angular: DivId param
      );
      AppCache.brokerList = data;
      brokerList = data;
    } catch (e) {
      debugPrint('_loadBrokers error: $e');
      brokerList = [];
    }
  }

  Future<void> _loadTransports() async {
    try {
      if (AppCache.transportList != null) {
        transportList = AppCache.transportList!;
      } else {
        final data = await GeneralService.getAllTransportData(
          coSoftId: _global.coSoftId ?? 0,
          divId: _global.divId,
          clientRegId: _global.clientRegId ?? 0,
          commonSalesOrder: _global.CommonSalesOrder ?? false,
        );
        AppCache.transportList = data;
        transportList = data;
      }
    } catch (e) {
      debugPrint('Error loading transports: $e');
    }
  }

  // ── When a party is selected, pre-fill broker from party.DLAccountId
  // Mirrors Angular: getSelectionValue() → BrokerD = e.DLAccountId
  Future<void> _loadPartyDetails(int partyId) async {
    final party = partyById[partyId];
    if (party != null) {
      setState(() {
        selectedPartyGSTNo = party['GSTNo'];
        selectedPartyPANNo = party['PANNo'];
        selectedPartyTINNo = party['TINNo'];
        selectedPartyCategoryName = party['PtCatgName'];

        // ── Broker pre-fill from party.DLAccountId ─────────────────────────
        // Angular: BrokerD = e.DLAccountId  (set on party selection)
        // We store the id and resolve the name for display.
        final dlAccountId = party['DLAccountId'];
        if (dlAccountId != null && dlAccountId != 0) {
          selectedBrokerId = dlAccountId;
          selectedBrokerName = _getBrokerName(dlAccountId);
        } else {
          selectedBrokerId = null;
          selectedBrokerName = null;
        }

        selectedSalesPersonId = _safeDropdownValue(
          party['SalesPersonId'],
          salesPersonList,
        );
        selectedTransportId = _safeDropdownValue(
          party['TransportId'],
          transportList,
        );
      });
      await _loadAccountBalance(partyId);
    }
  }

  // ── Resolve broker display name from loaded brokerList
  String? _getBrokerName(int? id) {
    if (id == null || id == 0) return null;
    final match = brokerList.firstWhere(
      (b) => (b['id'] ?? b['Id']) == id,
      orElse: () => {},
    );
    return match.isNotEmpty ? (match['AcName'] ?? match['Name']) : null;
  }

  Future<void> _loadAccountBalance(int accountId) async {
    try {
      setState(() {
        currentBalance = 0;
        combinedBalance = 0;
      });
    } catch (e) {
      debugPrint('Error loading account balance: $e');
    }
  }

  Future<void> _prefillOrderData() async {
    if (widget.orderHeaderData != null) {
      final header = widget.orderHeaderData!;

      selectedPartyId = header['PtAccountId'];
      if (selectedPartyId != null) {
        selectedPartyName = await _resolvePartyName(selectedPartyId!);
        await _loadPartyDetails(selectedPartyId!);
      }

      // ── Broker from saved header (overrides party default on edit) ──────
      // Angular: patchItemValue() → BrokerD = data[0].DLAccountId
      final savedBrokerId = header['DLAccountId'];
      if (savedBrokerId != null && savedBrokerId != 0) {
        setState(() {
          selectedBrokerId = savedBrokerId;
          selectedBrokerName = _getBrokerName(savedBrokerId);
        });
      }

      selectedSalesRepId = header['SalesRepresentative'];
      selectedSalesPersonId = header['SPId'];
      selectedTransportId = header['TransportId'];
      selectedDeliveryMode = header['DelvMode'] ?? 'Local';
      selectedPaymentMode = header['PymtMode'] ?? 'CRD';

      orderDate = _parseDate(header['OrdDate']) ?? DateTime.now();
      refDate = _parseDate(header['RefDate']) ?? DateTime.now();
      deliveryDate = _parseDate(header['DelvDateFrom']) ?? DateTime.now();
      toDate =
          _parseDate(header['DelvDateTo']) ??
          DateTime.now().add(const Duration(days: 3));

      orderNoController.text = header['OrdSeqNo']?.toString() ?? 'AUTO';
      refNoController.text = header['RefNo'] ?? '';
      remarkController.text = header['Remark'] ?? '';
    }

    if (widget.orderDetailsData != null) {
      for (int i = 0; i < widget.orderDetailsData!.length; i++) {
        try {
          final detail = widget.orderDetailsData![i];
          final int itemId = (detail['ItemId'] as num?)?.toInt() ?? 0;

          final masterItem = AppCache.getItems(widget.orderType).firstWhere(
            (m) => (m['id'] as num?)?.toInt() == itemId,
            orElse: () => {},
          );

          final String calUnit = masterItem['CalUnit'] ?? 'Bag';
          final String valUnit = masterItem['ValUnit'] ?? 'Qty';
          final String rateUnit =
              masterItem['SOrdUnitName'] ?? masterItem['RUnitName'] ?? 'Unit';

          items.add(
            OrderItem(
              itemId: itemId,
              itemName: itemNameById[itemId] ?? 'Item #$itemId',
              bag: (detail['OrdBag'] as num?)?.toInt() ?? 0,
              qty: (detail['OrdQty'] as num?)?.toDouble() ?? 0.0,
              rate: (detail['OrdRate'] as num?)?.toDouble() ?? 0.0,
              tpRate: (detail['OrdSTPRate'] as num?)?.toDouble() ?? 0.0,
              amount: (detail['Amount'] as num?)?.toDouble() ?? 0.0,
              weight: (detail['Weight'] as num?)?.toDouble() ?? 0.0,
              brandId: (detail['BrandId'] as num?)?.toInt() ?? 0,
              brandName: detail['BrandName'] ?? '',
              godownId: (detail['GodownId'] as num?)?.toInt() ?? 0,
              godownName: detail['GodownName'] ?? '',
              gdSlipNo: detail['GdSlipNo'] ?? '',
              brokerageRate: (detail['BrRate'] as num?)?.toDouble() ?? 0.0,
              minRate: (detail['OrdMinRate'] as num?)?.toDouble() ?? 0.0,
              discPrice: (detail['DiscPr'] as num?)?.toDouble() ?? 0.0,
              noOfPcs: (detail['NoOfPcs'] as num?)?.toInt() ?? 0,
              pcsRate: (detail['PCSRate'] as num?)?.toDouble() ?? 0.0,
              remark: detail['OrdRemark'] ?? '',
              itemDesc: detail['ItemDesc'] ?? '',
              itemGroupId: (detail['ItemGroupId'] as num?)?.toInt() ?? 0,
              itemGroupName: detail['ItemGroupName'] ?? '',
              calUnit: calUnit,
              valUnit: valUnit,
              rateUnit: rateUnit,
            ),
          );
        } catch (e, st) {
          debugPrint('❌ Item[$i] parse error: $e\n$st');
        }
      }
      _calculateTotals();
    }
  }

  DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null || dateStr == '' || dateStr == '1975-01-01T00:00:00')
      return null;
    try {
      return DateTime.parse(dateStr.toString());
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolvePartyName(int partyId) async {
    if (partyById.containsKey(partyId)) {
      return partyById[partyId]?['PartyFullName'];
    }
    if (AppCache.partyList.isNotEmpty) {
      final match = AppCache.partyList.firstWhere(
        (p) => p['PtAccountId'] == partyId,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        partyById[partyId] = match;
        return match['PartyFullName'];
      }
    }
    return 'Party #$partyId';
  }

  Future<void> _openPartySearch() async {
    if (isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot change party in edit mode'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (partyList.isEmpty) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => PartySearchScreen(parties: partyList)),
    );

    if (result != null && mounted) {
      setState(() {
        selectedPartyId = result['PtAccountId'];
        selectedPartyName = result['PartyFullName'];
      });
      if (selectedPartyId != null) {
        await _loadPartyDetails(selectedPartyId!);
      }
    }
  }

  // ── Open broker search screen — same as party/transport search pattern
  Future<void> _openBrokerSearch() async {
    if (_readOnlyMode || brokerList.isEmpty) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => BrokerSearchScreen(brokers: brokerList),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        selectedBrokerId = result['id'] ?? result['Id'];
        selectedBrokerName = result['AcName'] ?? result['Name'];
      });
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != initialDate) {
      setState(() => onDateSelected(picked));
    }
  }

  Future<void> openAddItemPopup() async {
    if (selectedPartyId == null) return;
    bool keepAdding = true;
    while (keepAdding) {
      final result = await showDialog<AddItemResult>(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => AddItemDialog(
              partyName: selectedPartyName!,
              partyId: selectedPartyId!,
              orderType: widget.orderType,
              canAdd: true,
              canEdit: true,
            ),
      );
      if (result == null) break;
      setState(() {
        items.add(result.item);
        _calculateTotals();
      });
      keepAdding = result.action == AddItemAction.saveAndNew;
    }
  }

  Future<void> openEditItemPopup(OrderItem item, int index) async {
    final bool editAllowed = isEditMode ? widget.canEdit : true;
    final result = await showDialog<AddItemResult>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AddItemDialog(
            partyName: selectedPartyName!,
            partyId: selectedPartyId!,
            editItem: item,
            orderType: widget.orderType,
            canAdd: isEditMode ? widget.canAdd : true,
            canEdit: editAllowed,
          ),
    );
    if (result != null && editAllowed) {
      setState(() {
        items[index] = result.item;
        _calculateTotals();
      });
    }
  }

  void _calculateTotals() {
    totalBags = items.fold(0, (s, i) => s + i.bag);
    totalQty = items.fold(0, (s, i) => s + i.qty);
    totalAmount = items.fold(0, (s, i) => s + i.amount);
    totalWeight = items.fold(0, (s, i) => s + i.weight);
    totalPcsRate = items.fold(0, (s, i) => s + i.pcsRate);
    totalNoOfPcs = items.fold(0, (s, i) => s + i.noOfPcs);
  }

  ORDHDRRecord buildHeader() {
    return ORDHDRRecord(
      id: isEditMode ? widget.orderId : null,
      ordSR: _ordSR,
      ordSeqNo: isEditMode ? int.tryParse(orderNoController.text) ?? 0 : 0,
      ordDate: orderDate,
      ptAccountId: selectedPartyId ?? 0,
      // ── Broker saved as DLAccountId — mirrors Angular's OrderHdr.DLAccountId
      dlAccountId: selectedBrokerId ?? 0,
      spId: selectedSalesPersonId ?? 0,
      salesRepresentative: selectedSalesRepId ?? 0,
      transportId: selectedTransportId ?? 0,
      refNo: refNoController.text,
      refDate: refDate,
      delvMode: selectedDeliveryMode ?? '',
      pymtMode: selectedPaymentMode ?? '',
      remark: remarkController.text,
      delvDateFrom: deliveryDate,
      delvDateTo: toDate,
      coSoftId: _global.coSoftId ?? 0,
      coFinyear: _global.CofinYear ?? 0,
      userId: _global.mobileAppUserId ?? 1,
      divId: _global.divId ?? 1,
    );
  }

  List<OrdDtlRecord> buildOrderDetails() {
    return List.generate(items.length, (index) {
      final item = items[index];
      int? detailId;
      int? oHId;

      if (isEditMode && widget.orderDetailsData != null) {
        if (index < widget.orderDetailsData!.length) {
          final existingDetail = widget.orderDetailsData![index];
          detailId = (existingDetail['id'] as num?)?.toInt();
          oHId = widget.orderId;
        } else {
          oHId = widget.orderId;
        }
      }

      return OrdDtlRecord(
        id: detailId,
        oHId: oHId,
        ordSR: _ordSR,
        itemId: item.itemId,
        godownId: item.godownId,
        gdSlipNo: item.gdSlipNo,
        brandId: item.brandId,
        ordQty: item.qty,
        ordBag: item.bag,
        ordRate: item.rate,
        brRate: item.brokerageRate,
        ordSTPRate: item.tpRate,
        ordRemark: item.remark,
        itemDesc: item.itemDesc,
        amount: item.amount,
        weight: item.weight,
        ordMinRate: item.minRate,
        pcsRate: item.pcsRate,
        noOfPcs: item.noOfPcs,
        coSoftId: _global.coSoftId ?? 0,
        divId: _global.divId ?? 1,
      );
    });
  }

  Future<void> saveOrder() async {
    final payload = AllOrdHdrDtl(
      orderHdr: buildHeader(),
      orderDtl: buildOrderDetails(),
    );

    final response = await GeneralService.saveSalesOrder(payload);
    if (!mounted) return;

    final isSuccess = response.statusCode == 200;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSuccess
              ? (isEditMode
                  ? '✅ Order updated successfully'
                  : '✅ Order saved successfully')
              : '❌ Failed: ${response.body}',
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );

    if (isSuccess) {
      Navigator.pop(context);
      Navigator.pop(context, true);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sysParams = _sysParamService.cachedData?.sysparam;

    String appBarTitle;
    if (_readOnlyMode) {
      appBarTitle = 'View $_pageTitle';
    } else if (isEditMode) {
      appBarTitle = 'Edit $_pageTitle';
    } else {
      appBarTitle = 'Create $_pageTitle';
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions:
            _readOnlyMode
                ? [
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'VIEW ONLY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ]
                : null,
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: AppLoader());
          }
          if (partyList.isEmpty) {
            return const Center(child: Text('Failed to load parties'));
          }
          return _buildForm(sysParams);
        },
      ),
    );
  }

  Widget _buildForm(sysParams) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Read-only banner ───────────────────────────────────────────
            if (_readOnlyMode)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You have view-only access. Changes cannot be saved.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Order No + Date ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: orderNoController,
                    label: 'Order No',
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'Order Date',
                    date: orderDate,
                    onTap:
                        _readOnlyMode
                            ? () {}
                            : () => _selectDate(
                              context,
                              orderDate,
                              (p) => orderDate = p,
                            ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Party ──────────────────────────────────────────────────────
            _buildPartyField(),
            if (selectedPartyGSTNo != null || currentBalance != 0)
              _buildPartyDetailsBanner(),

            const SizedBox(height: 16),

            // ── Ref No + Date ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: refNoController,
                    focusNode: _refNoFocusNode,
                    readOnly: _readOnlyMode,
                    decoration: InputDecoration(
                      labelText: 'Ref No',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.blue.shade700,
                          width: 2,
                        ),
                      ),
                      filled: _readOnlyMode,
                      fillColor: _readOnlyMode ? Colors.grey.shade100 : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'Ref Date',
                    date: refDate,
                    onTap:
                        _readOnlyMode
                            ? () {}
                            : () => _selectDate(
                              context,
                              refDate,
                              (p) => refDate = p,
                            ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Broker field ───────────────────────────────────────────────
            // Mirrors Angular: shown when SI_ReadBroker && BrokerWiseOrders
            // On party select → pre-filled from party.DLAccountId
            // Searchable list, same UX as Transport field
            if (_showBrokerField) ...[
              _buildBrokerField(),
              const SizedBox(height: 16),
            ],

            // ── Sales Representative ───────────────────────────────────────
            if (widget.orderType == 'SALES' &&
                (sysParams?.sysparamCommon?.useSalesRepresentative ??
                    false)) ...[
              _buildDropdown(
                label: 'Sales Representative',
                value: selectedSalesRepId,
                items: salesRepList,
                onChanged:
                    _readOnlyMode
                        ? (_) {}
                        : (v) => setState(() => selectedSalesRepId = v),
                enabled: !_readOnlyMode,
              ),
              const SizedBox(height: 16),
            ],

            // ── Sales Person ───────────────────────────────────────────────
            if (sysParams?.sysparamCommon.useSalesPerson == true) ...[
              _buildDropdown(
                label: 'Sales Person',
                value: selectedSalesPersonId,
                items: salesPersonList,
                onChanged:
                    _readOnlyMode
                        ? (_) {}
                        : (v) => setState(() => selectedSalesPersonId = v),
                enabled: !_readOnlyMode,
              ),
              const SizedBox(height: 16),
            ],

            // ── Transport ──────────────────────────────────────────────────
            _buildTransportField(),
            const SizedBox(height: 16),

            // ── Delivery Mode + Payment Mode ───────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;
                final dMode = _buildDropdown(
                  label: 'Delivery Mode',
                  value: selectedDeliveryMode,
                  items:
                      deliveryModeData
                          .map((e) => {'id': e['id'], 'Name': e['name']})
                          .toList(),
                  onChanged:
                      _readOnlyMode
                          ? (_) {}
                          : (v) => setState(() => selectedDeliveryMode = v),
                  isString: true,
                  enabled: !_readOnlyMode,
                );
                final pMode = _buildDropdown(
                  label: 'Payment Mode',
                  value: selectedPaymentMode,
                  items:
                      paymentModeData
                          .map((e) => {'id': e['id'], 'Name': e['name']})
                          .toList(),
                  onChanged:
                      _readOnlyMode
                          ? (_) {}
                          : (v) => setState(() => selectedPaymentMode = v),
                  isString: true,
                  enabled: !_readOnlyMode,
                );
                return isNarrow
                    ? Column(
                      children: [dMode, const SizedBox(height: 16), pMode],
                    )
                    : Row(
                      children: [
                        Expanded(child: dMode),
                        const SizedBox(width: 12),
                        Expanded(child: pMode),
                      ],
                    );
              },
            ),

            const SizedBox(height: 16),

            // ── Delivery Dates ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Delivery Date',
                    date: deliveryDate,
                    onTap:
                        _readOnlyMode
                            ? () {}
                            : () => _selectDate(
                              context,
                              deliveryDate,
                              (p) => deliveryDate = p,
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'To Date',
                    date: toDate,
                    onTap:
                        _readOnlyMode
                            ? () {}
                            : () =>
                                _selectDate(context, toDate, (p) => toDate = p),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Remark ─────────────────────────────────────────────────────
            _buildTextField(
              controller: remarkController,
              label: 'Remark',
              maxLines: 2,
              readOnly: _readOnlyMode,
            ),

            const SizedBox(height: 24),

            // ── Items table ────────────────────────────────────────────────
            _buildItemsTable(sysParams),

            const SizedBox(height: 24),

            // ── Save / Update button ───────────────────────────────────────
            if (_canSaveOrder)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    if (selectedPartyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a party')),
                      );
                      return;
                    }
                    if (items.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please add at least one item'),
                        ),
                      );
                      return;
                    }
                    saveOrder();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isEditMode ? 'Update Order' : 'Save Order',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Items table ───────────────────────────────────────────────────────────
  Widget _buildItemsTable(sysParams) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Item Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
                if (_canAddItem)
                  ElevatedButton.icon(
                    onPressed: openAddItemPopup,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No items added',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (_, i) => _buildItemCard(items[i], i, sysParams),
            ),
          if (items.isNotEmpty) _buildTotalsRow(sysParams),
        ],
      ),
    );
  }

  Widget _buildItemCard(OrderItem item, int index, sysParams) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_canOpenItemEdit)
                IconButton(
                  icon: Icon(Icons.edit, size: 18, color: _primaryColor),
                  onPressed: () => openEditItemPopup(item, index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (_canOpenItemEdit) const SizedBox(width: 8),
              if (_canDeleteItem)
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      items.removeAt(index);
                      _calculateTotals();
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildItemDetail(item.calUnit, item.bag.toString()),
              _buildItemDetail(item.valUnit, item.qty.toStringAsFixed(3)),
              _buildItemDetail('Rate', '₹${item.rate.toStringAsFixed(4)}'),
              if (item.tpRate > 0)
                _buildItemDetail(
                  'TP Rate',
                  '₹${item.tpRate.toStringAsFixed(4)}',
                ),
              _buildItemDetail('Amount', '₹${item.amount.toStringAsFixed(2)}'),
              if (item.weight > 0)
                _buildItemDetail('Weight', item.weight.toStringAsFixed(3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetail(String label, String value) {
    return Text(
      '$label: $value',
      style: const TextStyle(fontSize: 12, color: Colors.black87),
    );
  }

  Widget _buildTotalsRow(sysParams) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTotalItem(
                'Items',
                items.length.toString(),
                Icons.inventory_2,
              ),
              _buildTotalItem(
                'Bags',
                totalBags.toIndianNumber(),
                Icons.shopping_bag,
              ),
              _buildTotalItem('Qty', totalQty.toIndianQty(), Icons.scale),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount:'),
                Text(
                  totalAmount.toIndianCurrency(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // ─── Field builders ────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dateFormat.format(date)),
            Icon(
              Icons.calendar_today,
              size: 18,
              color: _readOnlyMode ? Colors.grey.shade400 : _primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyField() {
    return FormField<int>(
      validator: (_) => selectedPartyId == null ? 'Party is required' : null,
      builder: (state) {
        return InkWell(
          onTap: (isEditMode || _readOnlyMode) ? null : _openPartySearch,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Party *',
              errorText: state.errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: isEditMode || _readOnlyMode,
              fillColor:
                  (isEditMode || _readOnlyMode) ? Colors.grey.shade100 : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedPartyName ?? 'Select Party',
                    style: TextStyle(
                      color:
                          selectedPartyName != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                    ),
                  ),
                ),
                if (!isEditMode && !_readOnlyMode)
                  Icon(Icons.search, size: 20, color: _primaryColor),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Broker field widget — same look as Transport field (search icon, tap to open)
  // Mirrors Angular: ng-select for Broker with Ctrl+A shortcut and + button
  Widget _buildBrokerField() {
    return InkWell(
      onTap: _readOnlyMode ? null : _openBrokerSearch,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Broker',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: _readOnlyMode,
          fillColor: _readOnlyMode ? Colors.grey.shade100 : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          // Clear button to deselect broker
          suffixIcon:
              selectedBrokerId != null && !_readOnlyMode
                  ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed:
                        () => setState(() {
                          selectedBrokerId = null;
                          selectedBrokerName = null;
                        }),
                  )
                  : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedBrokerName ?? 'Select Broker',
                style: TextStyle(
                  color:
                      selectedBrokerName != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                ),
              ),
            ),
            if (!_readOnlyMode) Icon(Icons.search, color: _primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyDetailsBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          if (selectedPartyGSTNo != null && selectedPartyGSTNo!.isNotEmpty)
            _buildInfoRow('GST No', selectedPartyGSTNo!),
          if (selectedPartyPANNo != null && selectedPartyPANNo!.isNotEmpty)
            _buildInfoRow('PAN No', selectedPartyPANNo!),
          if (selectedPartyCategoryName != null)
            _buildInfoRow('Category', selectedPartyCategoryName!),
          _buildInfoRow(
            'Current Balance',
            combinedBalance <= 0
                ? '₹${combinedBalance.toStringAsFixed(2)} Dr'
                : '₹${combinedBalance.toStringAsFixed(2)} Cr',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<Map<String, dynamic>> items,
    required Function(dynamic) onChanged,
    bool isString = false,
    bool enabled = true,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        return DropdownButtonFormField(
          value: items.any((e) => (e['Id'] ?? e['id']) == value) ? value : null,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: !enabled,
            fillColor: !enabled ? Colors.grey.shade100 : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 8 : 12,
              vertical: isNarrow ? 10 : 14,
            ),
          ),
          style: TextStyle(fontSize: isNarrow ? 12 : 14, color: Colors.black87),
          isExpanded: true,
          items:
              items.map((item) {
                final id =
                    isString
                        ? item['id'] as String
                        : (item['Id'] ?? item['id']);
                return DropdownMenuItem(
                  value: id,
                  child: Text(
                    item['Name'] ?? 'Unknown',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
          onChanged: enabled ? onChanged : null,
        );
      },
    );
  }

  Widget _buildTransportField() {
    return InkWell(
      onTap:
          _readOnlyMode
              ? null
              : () async {
                if (transportList.isEmpty) return;
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => TransportSearchScreen(transports: transportList),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    selectedTransportId = result['Id'] ?? result['id'];
                  });
                }
              },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Transport',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: _readOnlyMode,
          fillColor: _readOnlyMode ? Colors.grey.shade100 : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _getTransportName(),
                style: TextStyle(
                  color:
                      selectedTransportId != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                ),
              ),
            ),
            Icon(
              Icons.search,
              color: _readOnlyMode ? Colors.grey.shade400 : _primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  dynamic _safeDropdownValue(dynamic value, List<Map<String, dynamic>> items) {
    if (value == null) return null;
    return items.any((e) => e['Id'] == value || e['id'] == value)
        ? value
        : null;
  }

  String _getTransportName() {
    if (selectedTransportId == null) return 'Select Transport';
    final match = transportList.firstWhere(
      (t) => t['Id'] == selectedTransportId || t['id'] == selectedTransportId,
      orElse: () => {},
    );
    return match.isNotEmpty
        ? (match['Name'] ?? match['TransportName'] ?? 'Unknown')
        : 'Select Transport';
  }
}
