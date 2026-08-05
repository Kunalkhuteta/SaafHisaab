import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saafhisaab/services/general_service.dart';
import 'package:saafhisaab/services/system_params_service.dart';
import 'package:saafhisaab/services/app_cache.dart';
import 'package:saafhisaab/widgets/app_loader.dart';
import 'package:saafhisaab/services/global_data.dart';
import 'package:saafhisaab/services/handlelib_service.dart';
import 'package:saafhisaab/screens/orderPages/salesOrder/AddItemDialog.dart';
import 'package:saafhisaab/screens/orderPages/salesOrder/createSalesOrderModel.dart'
    show OrderItem;
import 'package:saafhisaab/screens/orderPages/salesOrder/createSalesOrderPage.dart'
    show BrokerSearchScreen;
import 'package:saafhisaab/screens/orderPages/widgets/IndianNumberFormat.dart';
import 'package:saafhisaab/screens/orderPages/widgets/PartySearchDialog.dart';
import 'package:saafhisaab/screens/orderPages/widgets/TransportSearchDialog.dart';
import 'package:saafhisaab/screens/orderPages/widgets/CalculationEngine.dart';
import 'package:saafhisaab/screens/orderPages/widgets/TransportDetailDialog.dart';

class CreateSalesInvoicePage extends StatefulWidget {
  final String? invoiceId;
  final int? initialPartyId;
  final String? initialPartyName;
  final String? partyGSTNo;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  const CreateSalesInvoicePage({
    super.key,
    this.invoiceId,
    this.initialPartyId,
    this.initialPartyName,
    this.partyGSTNo,
    this.canAdd = true,
    this.canEdit = true,
    this.canDelete = false,
  });

  @override
  State<CreateSalesInvoicePage> createState() => _CreateSalesInvoicePageState();
}

class _CreateSalesInvoicePageState extends State<CreateSalesInvoicePage> {
  final GlobalData _global = GlobalData();
  final _sysParamService = SysparamService();
  final _formKey = GlobalKey<FormState>();

  final FocusNode _partyFocusNode = FocusNode();
  final FocusNode _refNoFocusNode = FocusNode();
  final FocusNode _cashReceivedFocusNode = FocusNode();
  final FocusNode _ePayAmountFocusNode = FocusNode();

  // Controllers
  final invNoController = TextEditingController(text: 'AUTO');
  final refNoController = TextEditingController();
  final remarkController = TextEditingController();
  final brokerShareController = TextEditingController(text: '100');
  final eWayBillController = TextEditingController();
  final dueDaysController = TextEditingController();
  final freightAmtController = TextEditingController(text: '0.00');
  final tcsAmountController = TextEditingController(text: '0.00');
  final roundDiffController = TextEditingController(text: '0.00');
  final cashReceivedController = TextEditingController(text: '0.00');
  final ePayAmountController = TextEditingController(text: '0.00');

  // Dates and Time
  DateTime invDate = DateTime.now();
  TimeOfDay invTime = TimeOfDay.now();
  DateTime refDate = DateTime.now();

  // Lists
  List<Map<String, dynamic>> partyList = [];
  Map<int, Map<String, dynamic>> partyById = {};
  List<Map<String, dynamic>> brokerList = [];
  List<Map<String, dynamic>> transportList = [];
  List<Map<String, dynamic>> salesPersonList = [];
  List<Map<String, dynamic>> salesRepList = [];
  List<Map<String, dynamic>> taxDataList = [];
  List<Map<String, dynamic>> bookMasterList = [];
  List<Map<String, dynamic>> stateList = [];
  List<Map<String, dynamic>> localTransportList = [];   // ← ADD
  List<Map<String, dynamic>> locationList = [];

  int? selectedBookId;
  int? selectedPlaceOfSupplyId;
  String? selectedPlaceOfSupplyName;

  // Selected values
  int? selectedPartyId;
  String? selectedPartyName;
  String? selectedPartyGSTNo;
  String? selectedPartyPANNo;
  String? selectedPartyCategoryName;
  double currentBalance = 0;
  double combinedBalance = 0;

  /// Whether the selected party is interstate (GSTNo state code != company state)
  /// Set this properly when you have access to the company's state code.
  /// For now we derive it from GSTNo prefix vs a stored company state code.
  bool _isInterStateParty = false;

  int? selectedBrokerId;
  String? selectedBrokerName;

  int? selectedSalesPersonId;
  int? selectedSalesRepId;
  int? selectedTransportId;
  String? selectedPaymentMode = 'R';
  int? sihdrId;
  Map<String, dynamic>? _originalInvTran;
  Map<String, dynamic>? _originalSIHDR;

  // Items
  List<OrderItem> items = [];
  List<Map<String, dynamic>> originalDetailsList = [];

  late final Future<void> _initFuture;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  bool get isEditMode => widget.invoiceId != null && widget.invoiceId!.isNotEmpty;
  bool get _readOnlyMode => isEditMode && !widget.canEdit;
  bool get _canSaveOrder => isEditMode ? widget.canEdit : true;
  bool get _canAddItem => isEditMode ? widget.canEdit : true;
  bool get _canOpenItemEdit => true;
  bool get _canDeleteItem => isEditMode ? widget.canEdit : true;

  /// Formatted invoice date string for CalculationDetailDialog effDate
  String get _effDateStr => _dateFormat.format(invDate);
  Map<String, dynamic>? _siHdrSysparam;
  TransportDetailData? _transportData;          // ← ADD  mirrors TransportForm data
  int _saveClickCount = 0;    
  List<Map<String, dynamic>> stationList = [];

  // Static Data
  final paymentModeData = const [
    {'id': 'C', 'Name': 'Cash'},
    {'id': 'R', 'Name': 'Credit'},
    {'id': 'E', 'Name': 'E-Payment'},
    {'id': 'D', 'Name': 'Cash & E-Pay'},
  ];

  bool get _showBrokerField =>
      _sysParamService.cachedData?.sysparam.siReadBroker ?? false;

  bool get _showSalesPersonField =>
      _sysParamService.cachedData?.sysparam.sysparamCommon.useSalesPerson ??
      false;

  bool get _showSalesRepField =>
      _sysParamService
          .cachedData?.sysparam.sysparamCommon.useSalesRepresentative ??
      false;

  // ── Payment mode field visibility — mirrors Angular's PaymentData semantics ──
  // C = Cash, R = Credit, E = E-Payment, D = Cash & E-Payment
  bool get _showCashReceivedField =>
      selectedPaymentMode == 'C' || selectedPaymentMode == 'D';

  bool get _showEPayField =>
      selectedPaymentMode == 'E' || selectedPaymentMode == 'D';

  bool get _showDueDaysField => selectedPaymentMode == 'R';

  @override
  void initState() {
    super.initState();
    _initFuture = _initializePage();

    // ── Live listeners for footer fields ──
    freightAmtController.addListener(_onFreightOrTcsChanged);
    tcsAmountController.addListener(_onFreightOrTcsChanged);
    roundDiffController.addListener(_onRoundDiffChanged);

    // ── Payment mode auto-derivation (Angular changePayMode) — fires on blur, not keystroke ──
    _cashReceivedFocusNode.addListener(() {
      if (!_cashReceivedFocusNode.hasFocus) _changePayMode();
    });
    _ePayAmountFocusNode.addListener(() {
      if (!_ePayAmountFocusNode.hasFocus) _changePayMode();
    });
  }

  @override
  void dispose() {
    _partyFocusNode.dispose();
    _refNoFocusNode.dispose();
    invNoController.dispose();
    refNoController.dispose();
    remarkController.dispose();
    brokerShareController.dispose();
    eWayBillController.dispose();
    dueDaysController.dispose();

    freightAmtController.removeListener(_onFreightOrTcsChanged);
    freightAmtController.dispose();

    tcsAmountController.removeListener(_onFreightOrTcsChanged);
    tcsAmountController.dispose();

    roundDiffController.removeListener(_onRoundDiffChanged);
    roundDiffController.dispose();

    _cashReceivedFocusNode.dispose();
    _ePayAmountFocusNode.dispose();
    cashReceivedController.dispose();
    ePayAmountController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await _loadInitialData();

    if (isEditMode) {
      await _prefillInvoiceData();
    } else {
      selectedPartyId = widget.initialPartyId;
      selectedPartyName = widget.initialPartyName;
      selectedPartyGSTNo = widget.partyGSTNo;
      if (selectedPartyId != null) {
        await _loadPartyDetails(selectedPartyId!);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !isEditMode && !_readOnlyMode) {
        _partyFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      try {
        if (_sysParamService.cachedData == null) {
          await _sysParamService.getSysParams(
              globalData: HandleLibService.globalData);
        }
      } catch (e) {
        debugPrint('SysParams load error: $e');
      }

      // In _loadInitialData(), after the existing sysParams try/catch block:
try {
  _siHdrSysparam = await GeneralService.getSIHdrSysparamData(
    coSoftId: _global.coSoftId ?? 0,
    clientRegId: _global.clientRegId ?? 0,
    siSr: 'SIN',
    divId: _global.divId ?? 0,
  );
  debugPrint('SIHdrSysparam: $_siHdrSysparam');
} catch (e) {
  debugPrint('SIHdrSysparam load error: $e');
}

      const partyCacheKey = 'SIN';
      if (AppCache.hasPartyList(partyCacheKey)) {
        partyList = AppCache.getPartyList(partyCacheKey);
      } else {
        final parties = await GeneralService.getPartyList(
          clientRegId: _global.clientRegId ?? 0,
          coSoftId: _global.coSoftId ?? 0,
          SPflag: 'SALE',
        );
        partyList = parties
            .where((p) => p['PtType'] == 'C' || p['PtType'] == 'B')
            .toList();
        AppCache.setPartyList(partyCacheKey, partyList);
      }
      partyById.clear();
      for (final p in partyList) {
        final id = (p['PtAccountId'] as num?)?.toInt();
        if (id != null) partyById[id] = p;
      }

      if (AppCache.brokerList != null && AppCache.brokerList!.isNotEmpty) {
        brokerList = AppCache.brokerList!;
      } else {
        brokerList = await GeneralService.getAllDalalAccounts(
          clientRegId: _global.clientRegId ?? 0,
          coSoftId: _global.coSoftId ?? 0,
          divId: _global.divId ?? 0,
        );
        AppCache.brokerList = brokerList;
      }

      if (AppCache.transportList != null && AppCache.transportList!.isNotEmpty) {
        transportList = AppCache.transportList!;
      } else {
        transportList = await GeneralService.getAllTransportData(
          coSoftId: _global.coSoftId ?? 0,
          divId: _global.divId ?? 0,
          clientRegId: _global.clientRegId ?? 0,
          commonSalesOrder: _global.CommonSalesOrder ?? false,
        );
        AppCache.transportList = transportList;
      }

      localTransportList = await GeneralService.getAllLocalTransportData(
        coSoftId: _global.coSoftId ?? 0,
        divId: _global.divId ?? 0,
        clientRegId: _global.clientRegId ?? 0,
      );

      locationList = await GeneralService.getAllLocationData(
        coSoftId: _global.coSoftId ?? 0,
        divId: _global.divId ?? 0,
        clientRegId: _global.clientRegId ?? 0,
      );

      if (AppCache.stationList != null && AppCache.stationList!.isNotEmpty) {
        stationList = AppCache.stationList!;
      } else {
        stationList = await GeneralService.getAllStationData(
          coSoftId: _global.coSoftId ?? 0,
          clientRegId: _global.clientRegId ?? 0,
        );
        AppCache.stationList = stationList;
      }

      salesRepList = await GeneralService.getSalesRepresentatives(
        coSoftId: _global.coSoftId ?? 0,
        commonSalesOrder: _global.CommonSalesOrder ?? false,
      );

      taxDataList = await GeneralService.getAllTaxTypes(
        clientRegId: _global.clientRegId ?? 0,
        coSoftId: _global.coSoftId ?? 0,
        commonSalesOrder: GlobalData().CommonSalesOrder ?? false,
        flag: 'S',
      );

      stateList = await GeneralService.getAllStates(
        clientRegId: _global.clientRegId ?? 0,
      );

      // Load BookMaster — userId=0 in edit mode like Angular does
      bookMasterList = await GeneralService.getAllBookMaster(
        userId: isEditMode ? 0 : (_global.mobileAppUserId ?? 0),
        coSoftId: _global.coSoftId ?? 0,
        clientRegId: _global.clientRegId ?? 0,
        bkType: 'SALE',
      );

      // Auto-select BookId — mirrors Angular updateBookIdD()
      if (!isEditMode) {
        _resolveDefaultBookId();
      }

      salesPersonList = [];
    } catch (e) {

      debugPrint('Error in _loadInitialData: $e');
    }
  }

  Future<void> _prefillInvoiceData() async {
    _suppressPayModeAutoDerive = true;
    try {
      final response =
          await HandleLibService.getSalesInvoiceByInvTranId(widget.invoiceId!);
      if (response != null && response['statusCode'] == 200) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final sihdr = data['SIHDR'] ?? {};
        final invTran = data['InvTranTbl'] ?? {};

        setState(() {
          _originalSIHDR = Map<String, dynamic>.from(sihdr);
          _originalInvTran = Map<String, dynamic>.from(invTran);
          sihdrId = int.tryParse((sihdr['id'] ?? 0).toString());
          invNoController.text =
              (sihdr['InvSeqNo'] ?? sihdr['InvSeqno'] ?? invTran['InvSeqNo'] ?? invTran['InvSeqno'] ?? '')
                  .toString();

          final dateStr = sihdr['InvDate'] ?? invTran['EIDocDate'] ?? '';
          if (dateStr.isNotEmpty) {
            try {
              invDate = DateTime.parse(dateStr);
            } catch (_) {}
          }

          final refDateStr = sihdr['RefDate'] ?? invTran['RefDate'] ?? '';
          if (refDateStr.isNotEmpty) {
            try {
              refDate = DateTime.parse(refDateStr);
            } catch (_) {}
          }

          final timeStr =
              sihdr['InvTime'] ?? sihdr['Time'] ?? invTran['InvTime'] ?? '';
          if (timeStr.isNotEmpty) {
            try {
              final parts = timeStr.split(':');
              if (parts.length >= 2) {
                invTime = TimeOfDay(
                    hour: int.parse(parts[0]), minute: int.parse(parts[1]));
              }
            } catch (_) {}
          }

          selectedPartyId = int.tryParse((invTran['AccountId'] ??
                      invTran['PtAccountId'] ??
                      sihdr['PtAccountId'] ??
                      0)
                  .toString());

          selectedBrokerId =
              int.tryParse((sihdr['BR1AccountId'] ?? 0).toString());
          if (selectedBrokerId != null && selectedBrokerId != 0) {
            selectedBrokerName = _getBrokerName(selectedBrokerId);
          }

          selectedSalesRepId =
              int.tryParse((sihdr['SalePersonId'] ?? 0).toString());
          selectedSalesPersonId =
              int.tryParse((sihdr['SalePersonId'] ?? 0).toString());
          selectedTransportId =
              int.tryParse((sihdr['TransportId'] ?? 0).toString());

          selectedPaymentMode =
              sihdr['PymtFlag'] ?? sihdr['PymtMode'] ?? sihdr['PayMode'] ?? 'R';

              // Mirrors Angular patchHeaderDatainControls():
          // this.BookIdD = this.IRHdrData.InvTranTbl.InvBookId
          final invBookId = int.tryParse(
              (invTran['InvBookId'] ?? invTran['BookId'] ?? 0).toString());
          if (invBookId != null && invBookId > 0) {
            selectedBookId = invBookId;
          } else if (bookMasterList.isNotEmpty) {
            // fallback to first available book
            selectedBookId =
                (bookMasterList.first['id'] as num?)?.toInt();
          }

          refNoController.text =
              (sihdr['RefNo'] ?? invTran['RefNo'] ?? '').toString();
          remarkController.text = (invTran['InvRemark'] ?? '').toString();

          final share = sihdr['ShareB1'] ?? sihdr['Share1'] ?? 100;
          brokerShareController.text = share.toString();

          eWayBillController.text = (invTran['EWBillNoManual'] ?? '').toString();

          final due = sihdr['DueDays'] ?? sihdr['DueD'] ?? 0;
          dueDaysController.text = due.toString();

          freightAmtController.text =
              (sihdr['FreightAmt'] ?? sihdr['FrieghtAmt'] ?? 0.0)
                  .toStringAsFixed(2);
          tcsAmountController.text =
              (sihdr['TCSAmount'] ?? 0.0).toStringAsFixed(2);
          roundDiffController.text =
              (sihdr['RndAmt'] ?? 0.0).toStringAsFixed(2);
          cashReceivedController.text =
              (invTran['RecdAmt'] ?? 0.0).toStringAsFixed(2);
          ePayAmountController.text =
              (sihdr['EPymtAmt'] ?? 0.0).toStringAsFixed(2);
          _transportData = TransportDetailData(                           // ← ADD
            localTransportId:                                             // ← ADD
                int.tryParse((sihdr['LTransportId'] ?? 0).toString()),   // ← ADD
            transportId: selectedTransportId,                            // ← ADD
            grNo: (invTran['EWGRNo'] ?? '').toString(),                  // ← ADD
            vehicleNo: (invTran['ViehicalNo'] ?? '').toString(),         // ← ADD
            grDate: _parseDateSafe(invTran['EWGRDate']),                 // ← ADD
            cases: int.tryParse(                                         // ← ADD
                    (sihdr['SICases'] ?? 0).toString()) ?? 0,           // ← ADD
            deliverAtStationId:                                          // ← ADD
                int.tryParse((sihdr['TRStationId'] ?? 0).toString()),   // ← ADD
            locationId:                                                  // ← ADD
                int.tryParse((sihdr['LocationId'] ?? 0).toString()),    // ← ADD
            shipToStateId:                                               // ← ADD
                int.tryParse((sihdr['ShiptoState'] ?? 0).toString()),   // ← ADD
          );        

          final dtl = data['StockDtlList'] as List<dynamic>? ??
              data['SIDtl'] as List<dynamic>? ??
              [];
          originalDetailsList = List<Map<String, dynamic>>.from(dtl);
          items = dtl
              .map<OrderItem>(
                  (e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList();
        });

        if (selectedPartyId != null) {
          await _loadPartyDetails(selectedPartyId!);
        }

        _calculateTotals();
      }
    } catch (e) {
      debugPrint('Prefill invoice error: $e');
    } finally {
      _suppressPayModeAutoDerive = false;
    }
  }

  Future<void> _loadPartyDetails(int partyId) async {
    final party = partyById[partyId];
    if (party != null) {
      setState(() {
        selectedPartyGSTNo = party['GSTNo'];
        selectedPartyPANNo = party['PANNo'];
        selectedPartyCategoryName = party['PtCatgName'];
        selectedPartyName = party['PartyFullName'] ?? party['PartyName'];

        final dlAccountId = party['DLAccountId'];
        final hasInvoiceBroker =
            isEditMode && selectedBrokerId != null && selectedBrokerId != 0;
        if (!hasInvoiceBroker && dlAccountId != null && dlAccountId != 0) {
          selectedBrokerId = dlAccountId;
        }
        if (selectedBrokerId != null && selectedBrokerId != 0) {
          selectedBrokerName = _getBrokerName(selectedBrokerId);
        }

        final hasInvoiceTransport =
            isEditMode && selectedTransportId != null && selectedTransportId != 0;
        if (!hasInvoiceTransport) {
          selectedTransportId =
              _safeDropdownValue(party['TransportId'], transportList);
        }

        // Auto-fill Place of Supply from party's StateId
        final partyStateId = (party['StateId'] as num?)?.toInt();
        if (partyStateId != null && partyStateId != 0 && stateList.isNotEmpty) {
          final stateMatch = stateList.firstWhere(
            (s) => (s['id'] as num?)?.toInt() == partyStateId,
            orElse: () => {},
          );
          if (stateMatch.isNotEmpty) {
            selectedPlaceOfSupplyId = partyStateId;
            selectedPlaceOfSupplyName =
                (stateMatch['StateName'] ?? stateMatch['Name'] ?? '').toString();
          }
        }

        // Determine interstate: compare Place of Supply state vs company state
        // Mirrors Angular checkPartyInterstate(): CompanyStateId != PosStateId
        _isInterStateParty = _computeIsInterStateByPosId(selectedPlaceOfSupplyId);
      });
      await _loadAccountBalance(partyId);
    }
  }
  /// Exact port of Angular's changePayMode(e).
  /// Derives PayModeD from CashReceived + EPayAmt vs InvAmount(netAmount).
  void _changePayMode() {
    if (_suppressPayModeAutoDerive) return;
    final cashReceived = double.tryParse(cashReceivedController.text) ?? 0.0;
    final ePayAmount = double.tryParse(ePayAmountController.text) ?? 0.0;
    final total = cashReceived + ePayAmount;

    String newMode;
    if (total == netAmount && ePayAmount == 0) {
      newMode = 'C';
    } else if (ePayAmount > 0 && cashReceived > 0 && total == netAmount) {
      newMode = 'D';
    } else if (ePayAmount == netAmount && cashReceived == 0) {
      newMode = 'E';
    } else {
      newMode = 'R';
    }

    if (newMode != selectedPaymentMode) {
      setState(() => selectedPaymentMode = newMode);
    }
  }

  /// Mirrors Angular's updateBookIdD() logic
  /// Priority: InvBookId match → SIHdrSysparam.BookId → first book in list
  void _resolveDefaultBookId() {
    if (bookMasterList.isEmpty) return;

    final sysParamBookId = int.tryParse((_siHdrSysparam?['BookId'] ??
            _siHdrSysparam?['InvBookId'] ??
            0)
        .toString()) ??
        0;

    if (sysParamBookId > 0) {
      final match = bookMasterList.firstWhere(
        (b) => (b['id'] as num?)?.toInt() == sysParamBookId,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        selectedBookId = sysParamBookId;
        return;
      }
    }

    // Fallback: first book in filtered list
    final firstBook = bookMasterList.first;
    selectedBookId = (firstBook['id'] as num?)?.toInt();
  }

  // Mirrors Angular checkPartyInterstate():
  /// IsInterStateParty = CompanyStateId != PosStateId
  bool _computeIsInterStateByPosId(int? posStateId) {
    if (posStateId == null || posStateId == 0) {
      // fallback: use GST prefix comparison
      return _computeIsInterStateByGst(selectedPartyGSTNo);
    }
    final companyStateId = _global.StateId ?? 0;
    if (companyStateId == 0) return false;
    return posStateId != companyStateId;
  }

  /// Fallback: compare first 2 chars of GSTIN with company state code
  bool _computeIsInterStateByGst(String? partyGST) {
    if (partyGST == null || partyGST.length < 2) return false;
    final companyStateCode =
        (_global.companyStateCode ?? '').toString().padLeft(2, '0');
    if (companyStateCode.isEmpty) return false;
    return partyGST.substring(0, 2) != companyStateCode;
  }

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
      final data = await GeneralService.getCurBalanceOfAccount(
        accountId: accountId,
        date: DateFormat('yyyyMMdd').format(invDate),
        coSoftId: _global.coSoftId ?? 0,
      );

      if (!mounted) return;
      setState(() {
        currentBalance =
            (data['CurrBal'] as num?)?.toDouble() ??
            double.tryParse(data['CurrBal']?.toString() ?? '') ??
            0;
        combinedBalance =
            (data['CombineCurrBal'] as num?)?.toDouble() ??
            double.tryParse(data['CombineCurrBal']?.toString() ?? '') ??
            currentBalance;
      });
    } catch (e) {
      debugPrint('Error loading account balance: $e');
      if (!mounted) return;
      setState(() {
        currentBalance = 0;
        combinedBalance = 0;
      });
    }
  }

  dynamic _safeDropdownValue(
      dynamic value, List<Map<String, dynamic>> items) {
    if (value == null) return null;
    return items.any((e) => e['Id'] == value || e['id'] == value)
        ? value
        : null;
  }

  Future<void> _openPartySearch() async {
    if (isEditMode || _readOnlyMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot change party in edit mode'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (partyList.isEmpty) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => PartySearchScreen(parties: partyList)),
    );

    if (result != null && mounted) {
      setState(() {
        selectedPartyId =
            result['PtAccountId'] ?? result['id'] ?? result['Id'];
        selectedPartyName =
            result['PartyFullName'] ?? result['PartyName'] ?? result['Name'];
      });
      if (selectedPartyId != null) {
        await _loadPartyDetails(selectedPartyId!);
      }
    }
  }

  Future<void> _openBrokerSearch() async {
    if (_readOnlyMode || brokerList.isEmpty) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => BrokerSearchScreen(brokers: brokerList)),
    );
    if (result != null && mounted) {
      setState(() {
        selectedBrokerId = result['id'] ?? result['Id'];
        selectedBrokerName = result['AcName'] ?? result['Name'];
      });
    }
  }

  Future<void> _selectDate(BuildContext context, DateTime initialDate,
      Function(DateTime) onDateSelected) async {
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

  Future<void> _selectTime(BuildContext context) async {
    final picked =
        await showTimePicker(context: context, initialTime: invTime);
    if (picked != null && picked != invTime) {
      setState(() => invTime = picked);
    }
  }

  // ── Add / Edit item — passes broker + interstate context ─────────────────

  Future<void> openAddItemPopup() async {
    if (selectedPartyId == null) return;
    bool keepAdding = true;
    while (keepAdding) {
      final result = await showDialog<AddItemResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AddItemDialog(
          partyName: selectedPartyName!,
          partyId: selectedPartyId!,
          orderType: 'SIN',
          canAdd: true,
          canEdit: true,
          brokerId: selectedBrokerId,
          isInterStateParty: _isInterStateParty,
          effDate: _effDateStr,
          defaultGodownId: _siHdrSysparam?['DefaultGodownId'] as int?,
          // Sticky godown: last item's godownId, or null if no items yet
          previousGodownId: items.isNotEmpty ? items.last.godownId : null,
          // MT_ItemWiseSeperateMethod sysparam for method resolution
          mtItemWiseSeparateMethod:
              (_sysParamService.cachedData?.sysparam
                      .sysparamCommon.mtItemWiseSeperateMethod) ??
                  false,
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

  void _applyRounding() {
  final freight = double.tryParse(freightAmtController.text) ?? 0.0;
  final tcs = double.tryParse(tcsAmountController.text) ?? 0.0;

  // Raw sum before rounding (basic + overhead + freight + tcs)
  final rawSum = totalAmount + totalOverhead + freight + tcs;

  // Rounded invoice amount (to nearest rupee — mirrors Angular Math.round)
  final invAmount = double.parse(rawSum.toStringAsFixed(0));

  // Round diff = rounded - raw  (mirrors Angular: InvAmount - (TotalAmount + Freight + TCS))
  final rndAmt = double.parse((invAmount - rawSum).toStringAsFixed(2));

  // Update controllers without triggering _calculateTotals again
  roundDiffController.removeListener(_onRoundDiffChanged);
  roundDiffController.text = rndAmt.toStringAsFixed(2);
  roundDiffController.addListener(_onRoundDiffChanged);

  // Net = raw + rounding
  setState(() {
    netAmount = double.parse((rawSum + rndAmt).toStringAsFixed(2));
  });

  // Re-derive payment mode now that netAmount may have shifted
  _changePayMode();
}

  Future<void> openEditItemPopup(OrderItem item, int index) async {
    final bool editAllowed = isEditMode ? widget.canEdit : true;
    final result = await showDialog<AddItemResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddItemDialog(
        partyName: selectedPartyName!,
        partyId: selectedPartyId!,
        editItem: item,
        orderType: 'SIN',
        canAdd: isEditMode ? widget.canAdd : true,
        canEdit: editAllowed,
        brokerId: selectedBrokerId,
        isInterStateParty: _isInterStateParty,
        effDate: _effDateStr,
        defaultGodownId: _siHdrSysparam?['DefaultGodownId'] as int?,
        // In edit mode, sticky godown = the item being edited's own godown
        previousGodownId: index > 0 ? items[index - 1].godownId : null,
        mtItemWiseSeparateMethod:
            (_sysParamService.cachedData?.sysparam
                    .sysparamCommon.mtItemWiseSeperateMethod) ??
                false,
      ),
    );
    if (result != null && editAllowed) {
      setState(() {
        items[index] = result.item;
        _calculateTotals();
      });
    }
  }

  // ── Totals — now includes overhead ───────────────────────────────────────

  double totalBags = 0;
  double totalQty = 0;
  double totalAmount = 0;    // sum of basic amounts
  double totalOverhead = 0;  // sum of all payable overhead / extra amounts
  double totalCgst = 0;
  double totalSgst = 0;
  double totalIgst = 0;
  double netAmount = 0;

  double _itemOverheadAmount(OrderItem item) {
    if (item.totalOverHead != 0) return item.totalOverHead;

    // CalculationEngine's ExtraAmt includes the basic amount, while reloaded
    // API rows may store only the extra amount. Support both shapes.
    final basicAfterDisc = item.amount - item.discPrice;
    final derivedExtra = item.extraAmt - basicAfterDisc;
    if (derivedExtra > 0) return derivedExtra;
    if (derivedExtra == 0) return 0;
    return item.extraAmt > 0 ? item.extraAmt : 0;
  }

  void _calculateTotals() {
  setState(() {
    totalBags = items.fold<double>(0.0, (s, i) => s + i.bag);
    totalQty = items.fold<double>(0.0, (s, i) => s + i.qty);
    totalAmount = items.fold<double>(0.0, (s, i) => s + i.amount);
    totalOverhead = items.fold<double>(0.0, (s, i) => s + _itemOverheadAmount(i));
    totalCgst = items.fold<double>(0.0, (s, i) => s + i.cgstAmt);
    totalSgst = items.fold<double>(0.0, (s, i) => s + i.sgstAmt);
    totalIgst = items.fold<double>(0.0, (s, i) => s + i.igstAmt);
  });
  _applyRounding(); // computes rndAmt + netAmount
}

// ADD these two methods:

void _onRoundDiffChanged() {
  // User manually overrode the round diff — just recompute netAmount from it
  final freight = double.tryParse(freightAmtController.text) ?? 0.0;
  final tcs = double.tryParse(tcsAmountController.text) ?? 0.0;
  final rnd = double.tryParse(roundDiffController.text) ?? 0.0;
  setState(() {
    netAmount = double.parse(
      (totalAmount + totalOverhead + freight + tcs + rnd).toStringAsFixed(2),
    );
  });

  // Re-derive payment mode now that netAmount may have shifted
  _changePayMode();
}

void _onFreightOrTcsChanged() {
  // Freight or TCS changed — recompute rounding automatically
  _applyRounding();
}

  /// Prefers the snapshot stamped on the item in AddItemDialog; falls back
  /// to taxDataList for items loaded straight from an existing invoice.
  Map<String, dynamic>? _resolveTaxItem(OrderItem item) {
    if (item.taxId <= 0) return null;
    if (item.taxCode.isNotEmpty) {
      return {
        'TXCode': item.taxCode,
        'TXCgstRate': item.taxCgstRate,
        'TXSgstRate': item.taxSgstRate,
        'TXIgstRate': item.taxIgstRate,
      };
    }
    final match = taxDataList.firstWhere(
      (t) => (t['id'] ?? t['Id']) == item.taxId,
      orElse: () => {},
    );
    return match.isEmpty ? null : match;
  }

  /// Mirrors Angular's CheckTaxCondition() — first invalid item wins.
  String _checkTaxCondition() {
    for (final item in items) {
      final taxItem = _resolveTaxItem(item);
      if (taxItem == null) continue;

      final error = CalculationEngine.checkItemTaxCondition(
        itemName: item.itemName,
        txIgstRate: (taxItem['TXIgstRate'] as num?)?.toDouble() ?? 0,
        txCgstRate: (taxItem['TXCgstRate'] as num?)?.toDouble() ?? 0,
        txSgstRate: (taxItem['TXSgstRate'] as num?)?.toDouble() ?? 0,
        txCode: (taxItem['TXCode'] ?? '').toString(),
        igstAmt: item.igstAmt,
        cgstAmt: item.cgstAmt,
        sgstAmt: item.sgstAmt,
        taxOnAmt: item.taxOnAmt,
        isInterStateParty: _isInterStateParty,
      );
      if (error.isNotEmpty) return error;
    }
    return '';
  }

  Future<void> _showBlockingError(String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invalid Tax Calculated'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (selectedPartyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a party')));
      return;
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one item')));
      return;
    }
 
    // ── Angular Count==1 logic: first save click opens transport modal ──
    _saveClickCount++;                                                    // ← ADD
    if (_saveClickCount == 1) {                                           // ← ADD
      final result = await _openTransportDialog();                        // ← ADD
      // User cancelled the transport dialog → abort save                 // ← ADD
      if (result == null) {                                               // ← ADD
        _saveClickCount = 0; // reset so next tap tries again             // ← ADD
        return;                                                            // ← ADD
      }                                                                   // ← ADD
      _transportData = result;                                            // ← ADD
      // selectedTransportId kept in sync for display                     // ← ADD
      setState(() => selectedTransportId = result.transportId);          // ← ADD
    }                                                                     // ← ADD
 
    // ── rest of your existing _save() body continues unchanged ──────────
    final taxError = _checkTaxCondition();
    if (taxError.isNotEmpty) {
      await _showBlockingError(taxError);
      return;
    }

    // ── Place of Supply / GST type cross-check (mirrors Angular SaveInvoiceData) ──
    final int companyStateId = _global.StateId ?? 0;
    if (companyStateId != 0 && selectedPlaceOfSupplyId != null) {
      final isInterState = selectedPlaceOfSupplyId != companyStateId;
      if (isInterState &&
          totalIgst == 0 &&
          (totalCgst + totalSgst) > 0) {
        await _showBlockingError(
          "CGST+SGST Tax Amount Can't be apply for Interstate Party.",
        );
        return;
      }
      if (!isInterState &&
          totalIgst > 0 &&
          (totalCgst + totalSgst) == 0) {
        await _showBlockingError(
          "IGST Tax Amount Can't be apply for Local State Party.",
        );
        return;
      }
      if (totalIgst > 0 && (totalCgst + totalSgst) > 0) {
        await _showBlockingError(
          'Invalid tax selection: You cannot apply both IGST and CGST/SGST at the same time.',
        );
        return;
      }
    }

    if (!isEditMode) {
      final invSeq = int.tryParse(invNoController.text) ?? 0;
      if (invSeq > 0) {
        setState(() => loading = true);
        try {
          final isDup = await HandleLibService.checkDuplicateInvNo(
              widget.invoiceId ?? '', 0, 'SIN', invSeq);
          if (isDup) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Duplicate invoice number')));
            setState(() => loading = false);
            return;
          }
        } catch (e) {
          debugPrint('Duplicate check error: $e');
        }
      }
    }

    final List<Map<String, dynamic>> stockDtlList =
        List.generate(items.length, (index) {
      final i = items[index];
      int? detailId;
      String? oHId;

      if (isEditMode && originalDetailsList.isNotEmpty) {
        if (index < originalDetailsList.length) {
          final rawDetail = originalDetailsList[index];
          final existingDetail = rawDetail.containsKey('StockDtl')
              ? (rawDetail['StockDtl'] as Map<String, dynamic>?) ?? rawDetail
              : rawDetail;
          final rawId = existingDetail['id'] ??
              existingDetail['InvDtlId'] ??
              existingDetail['InvDtlIdNo'];
          detailId = rawId != null ? int.tryParse(rawId.toString()) : null;
          oHId = widget.invoiceId;
        } else {
          oHId = widget.invoiceId;
        }
      }

      final stockDtl = {
        'id': detailId,
        'InvDtlId': detailId,
        'InvDtlIdNo': detailId,
        'InvTranIdNo': oHId,
        'InvId': oHId,
        'InvTranId': oHId,
        'STIRIdNo': oHId,
        'itemId': i.itemId,
        'ItemId': i.itemId,
        'itemName': i.itemName,
        'ItemName': i.itemName,
        'bag': i.bag,
        'STBag': i.bag,
        'OrdBag': i.bag,
        'qty': i.qty,
        'STQty': i.qty,
        'OrdQty': i.qty,
        'rate': i.rate,
        'Rate': i.rate,
        'OrdRate': i.rate,
        'tpRate': i.tpRate,
        'OrdSTPRate': i.tpRate,
        'amount': i.amount,
        'Amount': i.amount,
        'weight': i.weight,
        'Weight': i.weight,
        'GrossWeight': i.weight,
        'BardanaWeight': i.bardanaWeight,
        'brandId': i.brandId,
        'BrandId': i.brandId,
        'brandName': i.brandName,
        'BrandName': i.brandName,
        'godownId': i.godownId,
        'GodownId': i.godownId,
        'godownName': i.godownName,
        'GodownName': i.godownName,
        'gdSlipNo': i.gdSlipNo,
        'GdSlipNo': i.gdSlipNo,
        'brokerageRate': i.brokerageRate,
        'BrRate': i.brokerageRate,
        'minRate': i.minRate,
        'OrdMinRate': i.minRate,
        'discPrice': i.discPrice,
        'DiscPr': i.discPrice,
        'noOfPcs': i.noOfPcs,
        'NoOfPcs': i.noOfPcs,
        'pcsRate': i.pcsRate,
        'PCSRate': i.pcsRate,
        'remark': i.remark,
        'OrdRemark': i.remark,
        'itemDesc': i.itemDesc,
        'ItemDesc': i.itemDesc,
        'calUnit': i.calUnit,
        'CalUnit': i.calUnit,
        'valUnit': i.valUnit,
        'ValUnit': i.valUnit,
        'rateUnit': i.rateUnit,
        'SOrdUnitName': i.rateUnit,
        'itemGroupId': i.itemGroupId,
        'ItemGroupId': i.itemGroupId,
        'itemGroupName': i.itemGroupName,
        'ItemGroupName': i.itemGroupName,
        'coSoftId': _global.coSoftId ?? 0,
        'divId': _global.divId ?? 1,
        'TaxId': i.taxId,    // ⬅ ADD — needed for save + edit-mode reload
        'taxId': i.taxId,
        'MethodId': i.methodId,
        'methodId': i.methodId,
        'STAccountId': -1,
        'StkFlag': 'S',
        'CGSTAmt': i.cgstAmt,
        'SGSTAmt': i.sgstAmt,
        'IGSTAmt': i.igstAmt,
        'GSTCessAmt': i.gstCessAmt,
        'TaxOnAmt': i.taxOnAmt,
        'ExtraAmt': double.parse(
          (i.extraAmt - (i.amount - i.discPrice)).toStringAsFixed(2)),
        'STIncAmt': double.parse(
          (i.incAmt - (i.amount - i.discPrice)).toStringAsFixed(2)),
        'IncAmt': double.parse(
          (i.incAmt - (i.amount - i.discPrice)).toStringAsFixed(2)),      
        'TotalOverHead': i.totalOverHead,
      };

      final List<Map<String, dynamic>> siDtlRows = i.siDtl.isNotEmpty
    ? i.siDtl.map((row) {
        final r = Map<String, dynamic>.from(row);

        // ── Stamp parent ids ──────────────────────────────────────────
        r['InvDtlIdNo']  = detailId;
        r['InvTranIdNo'] = oHId;
        r['CoSoftId']    = _global.coSoftId ?? 0;
        r['DivId']       = _global.divId ?? 1;

        // SIIdno / SIIdNo — links this SIDtl row back to its StockDtl row.
        // Angular sets: item.SIidno = '' (new rows) or the real DB id (existing).
        // Must be the StockDtl's own id (detailId), NOT the invoice id.
        // Must be string — .NET model is System.String.
        final existingSeq =
            r['SIISeqNo'] ?? r['SIIdNo'] ?? r['SIidno'] ?? 0;
        final seqInt = existingSeq is num
            ? existingSeq.toInt()
            : int.tryParse(existingSeq.toString()) ?? 0;
        if (seqInt == 0) {
          // New row — server assigns the real id; send empty string
          r['SIIdNo'] = '';
          r['SIidno'] = '';
        } else {
          // Existing row — preserve the real id as string
          r['SIIdNo'] = seqInt.toString();
          r['SIidno'] = seqInt.toString();
        }

        // SISr — always "SIN" for sales invoice
        if ((r['SISr'] ?? '').toString().isEmpty) r['SISr'] = 'SIN';

        // CalcOnAccountId — string field
        r['CalcOnAccountId'] = (r['CalcOnAccountId'] ?? '').toString();

        // DedTDS — must be bool
        final dedRaw = r['DedTDS'];
        if (dedRaw is String) {
          r['DedTDS'] = dedRaw.toLowerCase() == 'true';
        }
        r['DedTDS'] ??= false;

        return r;
      }).toList()
    : [
        // Fallback minimal SIDtl when item has no overhead rows
        {
          'id':          0,
          'SNo':         1,
          'InvDtlIdNo':  detailId,
          'InvTranIdNo': oHId,
          'CoSoftId':    _global.coSoftId ?? 0,
          'DivId':       _global.divId ?? 1,
          'SISr':        'SIN',
          'SIIdNo':      '',      // string — not int
          'SIidno':      '',      // string — not int
          'ItemId':      i.itemId,
          'Amount':      i.amount,
          'STBag':       i.bag,
          'STQty':       i.qty,
          'Rate':        i.rate,
          'CalcFlag':    'B',
          'Chrble':      'B',
          'Incl':        'P',
          'DedTDS':      false,   // bool — not string
          'EditAmt':     false,
          'RndBy':       0.01,
          'RndType':     'N',
          'CalcOnAmt':   0.0,
          'CalcOnAccountId': '',  // string
        }
      ];

      final List<Map<String, dynamic>> stock2RowsPayload =
          i.stock2Rows.asMap().entries.map((entry) {
        final r = entry.value;
        return {
          'id': 0,
          'SNo': entry.key + 1,
          'STSr': 'SIN',
          'STIRIdNo': oHId,
          'STISeqNo': index + 1,
          'STBag': (r['STBag'] as num?)?.toDouble() ?? 0,
          'WtPerBag': (r['WtPerBag'] as num?)?.toDouble() ?? 0,
          'STQty': (r['STQty'] as num?)?.toDouble() ?? 0,
          'CoSoftId': _global.coSoftId ?? 0,
          'CoFinyear': _global.CofinYear ?? 0,
          'Recstatus': 0,
        };
      }).toList();

      return {
        'id': oHId,
        'STIRIdNo': oHId,
        'StockDtl': stockDtl,
        'Stock2': stock2RowsPayload,
        'SIDtl': siDtlRows,
        'ConsDtl': [],
        'ConsPurchDtl': null,
        'PLotMast': null,
        'ItemName': i.itemName,
        // Also preserve overhead totals at wrapper level for easy read-back
        'totalOverHead': i.totalOverHead,
        'cgstAmt': i.cgstAmt,
        'sgstAmt': i.sgstAmt,
        'igstAmt': i.igstAmt,
        'gstCessAmt': i.gstCessAmt,
        'taxOnAmt': i.taxOnAmt,
        'incAmt': i.incAmt,
        'extraAmt': i.extraAmt,
      };
    });

    final Map<String, dynamic> invTranMap = _originalInvTran != null
        ? Map<String, dynamic>.from(_originalInvTran!)
        : <String, dynamic>{};
    final Map<String, dynamic> sihdrMap = _originalSIHDR != null
        ? Map<String, dynamic>.from(_originalSIHDR!)
        : <String, dynamic>{};

    invTranMap.addAll({
      'InvTranId': isEditMode ? widget.invoiceId : null,
      'InvTranIdNo': isEditMode ? widget.invoiceId : null,
      'InvId': isEditMode ? widget.invoiceId : null,
      'id': isEditMode ? widget.invoiceId : null,
      'AccountId': selectedPartyId,
      'PtAccountId': selectedPartyId,
      'EIDocNo': invNoController.text,
      'InvSeqNo': int.tryParse(invNoController.text) ?? 0,
      'InvSeqno': int.tryParse(invNoController.text) ?? 0,
      'InvBookId': selectedBookId ?? 0,
      'BookId': selectedBookId ?? 0,
      'EIDocDate': invDate.toIso8601String(),
      'InvDate': invDate.toIso8601String(),
      'InvTime':
          "${invTime.hour.toString().padLeft(2, '0')}:${invTime.minute.toString().padLeft(2, '0')}:00",
      'Time':
          "${invTime.hour.toString().padLeft(2, '0')}:${invTime.minute.toString().padLeft(2, '0')}:00",
      'InvSR': 'SIN',
      'BuyerName': selectedPartyName,
      'BuyerGstNo': selectedPartyGSTNo,
      'Consignee': selectedPartyName,
      'CoSoftId': _global.coSoftId,
      'CoFinyear': _global.CofinYear,
      'DivId': _global.divId,
      'UserId':
          int.tryParse(_global.userId ?? '') ?? _global.mobileAppUserId ?? 0,
      'RndAmt': double.tryParse(roundDiffController.text) ?? 0.0,
      'RecdAmt': double.tryParse(cashReceivedController.text) ?? 0.0,
      'CashReceived': double.tryParse(cashReceivedController.text) ?? 0.0,
      'EIInvAmt': netAmount,
      'RefNo': refNoController.text,
      'RefDate': refDate.toIso8601String(),
      'InvRemark': remarkController.text,
      'EWBillNoManual': eWayBillController.text,
      'TaxOnAmt': totalAmount,
      // GST totals at header level
      'TotalCGST': totalCgst,
      'TotalSGST': totalSgst,
      'TotalIGST': totalIgst,
      'PosStateId': selectedPlaceOfSupplyId ?? 0,
      ...?_transportData?.toInvTranMap(_dateFormat), 
    });

    sihdrMap.addAll({
      'InvTranId': isEditMode ? widget.invoiceId : null,
      'InvId': isEditMode ? widget.invoiceId : null,
      'InvTranIdNo': isEditMode ? widget.invoiceId : null,
      'id': isEditMode ? sihdrId : null,
      'InvSeqNo': int.tryParse(invNoController.text) ?? 0,
      'InvSeqno': int.tryParse(invNoController.text) ?? 0,
      'InvBookId': selectedBookId ?? 0,
      'BookId': selectedBookId ?? 0,
      'InvDate': invDate.toIso8601String(),
      'EIDocDate': invDate.toIso8601String(),
      'Time':
          "${invTime.hour.toString().padLeft(2, '0')}:${invTime.minute.toString().padLeft(2, '0')}:00",
      'InvTime':
          "${invTime.hour.toString().padLeft(2, '0')}:${invTime.minute.toString().padLeft(2, '0')}:00",
      'PtAccountId': selectedPartyId,
      'SPId': selectedSalesPersonId,
      'SalePersonId': selectedSalesPersonId,
      'PymtMode': selectedPaymentMode,
      'PymtFlag': selectedPaymentMode,
      'RefNo': refNoController.text,
      'RefDate': refDate.toIso8601String(),
      'BR1AccountId': selectedBrokerId,
      'DLAccountId': selectedBrokerId,
      'ShareB1': double.tryParse(brokerShareController.text) ?? 100.0,
      'Share1': double.tryParse(brokerShareController.text) ?? 100.0,
      'EWayBillNo': eWayBillController.text,
      'EWayNo': eWayBillController.text,
      'DueDays': int.tryParse(dueDaysController.text) ?? 0,
      'DueD': int.tryParse(dueDaysController.text) ?? 0,
      'Remark': remarkController.text,
      'TransportId': selectedTransportId,
      'FreightAmt': double.tryParse(freightAmtController.text) ?? 0.0,
      'FrieghtAmt': double.tryParse(freightAmtController.text) ?? 0.0,
      'TCSAmount': double.tryParse(tcsAmountController.text) ?? 0.0,
      'RndAmt': double.tryParse(roundDiffController.text) ?? 0.0,
      'CashReceived': double.tryParse(cashReceivedController.text) ?? 0.0,
      'EPymtAmt': double.tryParse(ePayAmountController.text) ?? 0.0,
      'NetAmt': netAmount,
      'EIInvAmt': netAmount,
      'CoSoftId': _global.coSoftId,
      'CoFinyear': _global.CofinYear,
      'DivId': _global.divId,
      'UserId':
          int.tryParse(_global.userId ?? '') ?? _global.mobileAppUserId ?? 0,
      // GST totals
      'TotalCGST': totalCgst,
      'TotalSGST': totalSgst,
      'TotalIGST': totalIgst,
      'CGSTAmt': totalCgst,
      'SGSTAmt': totalSgst,
      'IGSTAmt': totalIgst,
      'PosStateId': selectedPlaceOfSupplyId ?? 0,
      ...?_transportData?.toSIHDRMap(), 
    });

    final payload = {
      'InvTranTbl': invTranMap,
      'SIHDR': sihdrMap,
      'StockDtlList': stockDtlList,
    };

    setState(() => loading = true);
    try {
      final resp = await HandleLibService.saveSalesInvoice(payload);
      final ok = resp['statusCode'] == 200;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (isEditMode
                ? '✅ Invoice updated successfully'
                : '✅ Invoice saved successfully')
            : '❌ Save failed: ${resp['message']}'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) {
        if (!isEditMode) {
          // Mirrors afterinvoicegenerationprocess: addEditFlag == 'add'
          // → auto-generate OS entry silently, then show success popup.
          final String? newBillId = resp['billId'] as String?;
          if (newBillId != null && newBillId.isNotEmpty) {
            await _autoGenerateOutstandingIfNeeded(newBillId.hashCode.abs());
          }
        } else {
          // Mirrors the else-branch in Angular (manual OS modal) —
          // instead of opening that modal in mobile, just inform the user.
          await _showEditOutstandingNoticeDialog();
        }
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

Future<TransportDetailData?> _openTransportDialog() async {
  // Merge selectedTransportId into initialData so the dialog always
  // shows the currently-selected transport as the default value.
  final partyStationId = selectedPartyId != null
    ? (partyById[selectedPartyId]?['Station'] as num?)?.toInt()
    : null;

  final seedData = (_transportData ?? TransportDetailData()).copyWith(
    transportId: _transportData?.transportId ?? selectedTransportId,
    deliverAtStationId: _transportData?.deliverAtStationId ?? partyStationId,
    grDate: _transportData?.grDate ?? DateTime.now(),
  );

  return showDialog<TransportDetailData>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TransportDetailDialog(
      initialData: seedData,
      transportList: transportList,
      localTransportList: localTransportList,
      stationList: stationList,
      locationList: locationList,
      stateList: stateList,
      showLocalTransport: localTransportList.isNotEmpty,
    ),
  );
}

  bool loading = false;
  bool _suppressPayModeAutoDerive = false;

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    String appBarTitle;
    if (_readOnlyMode) {
      appBarTitle = 'View Sales Invoice';
    } else if (isEditMode) {
      appBarTitle = 'Edit Sales Invoice';
    } else {
      appBarTitle = 'Create Sales Invoice';
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _readOnlyMode
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('VIEW ONLY',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                )
              ]
            : null,
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done || loading) {
            return const Center(child: AppLoader());
          }
          return _buildForm();
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    Icon(Icons.info_outline,
                        color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You have view-only access. Changes cannot be saved.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                    child: _buildTextField(
                        controller: invNoController,
                        label: 'Invoice No',
                        readOnly: true)),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'Doc Date',
                    date: invDate,
                    onTap: _readOnlyMode
                        ? () {}
                        : () => _selectDate(
                            context, invDate, (d) => invDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // REPLACE the entire Time + Spacer Row with:
// REPLACE WITH:
Row(
  children: [
    Expanded(
      child: InkWell(
        onTap: _readOnlyMode ? null : () => _selectTime(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Time',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(invTime.format(context)),
              Icon(Icons.access_time,
                  color: Colors.blue.shade700, size: 18),
            ],
          ),
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(child: _buildBookField()),
  ],
),
const SizedBox(height: 16),

_buildPartyField(),
if (selectedPartyGSTNo != null || currentBalance != 0 || combinedBalance != 0)
  _buildPartyDetailsBanner(),
const SizedBox(height: 16),

if (_showSalesPersonField) ...[
  _buildDropdown(
    label: 'Sales Person',
    value: selectedSalesPersonId,
    items: salesPersonList,
    onChanged: _readOnlyMode
        ? (_) {}
        : (v) => setState(() => selectedSalesPersonId = v),
    enabled: !_readOnlyMode,
  ),
  const SizedBox(height: 16),
],

if (_showSalesRepField) ...[
  _buildDropdown(
    label: 'Sales Representative',
    value: selectedSalesRepId,
    items: salesRepList,
    onChanged: _readOnlyMode
        ? (_) {}
        : (v) => setState(() => selectedSalesRepId = v),
    enabled: !_readOnlyMode,
  ),
  const SizedBox(height: 16),
],

            _buildPlaceOfSupplyField(),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Payment Mode',
                    value: selectedPaymentMode,
                    items: paymentModeData,
                    onChanged: _readOnlyMode
                        ? (_) {}
                        : (v) =>
                            setState(() => selectedPaymentMode = v),
                    isString: true,
                    enabled: !_readOnlyMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: refNoController,
                    label: 'Ref No',
                    focusNode: _refNoFocusNode,
                    readOnly: _readOnlyMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // WITH:
Row(
  children: [
    Expanded(
      child: _buildDateField(
        label: 'Ref Date',
        date: refDate,
        onTap: _readOnlyMode
            ? () {}
            : () => _selectDate(
                context, refDate, (d) => refDate = d),
      ),
    ),
    if (_showDueDaysField) ...[
      const SizedBox(width: 12),
      Expanded(
        child: _buildTextField(
          controller: dueDaysController,
          label: 'Due Days',
          keyboardType: TextInputType.number,
          readOnly: _readOnlyMode,
        ),
      ),
    ],
  ],
),
const SizedBox(height: 16),

            if (_showBrokerField) ...[
              Row(
                children: [
                  Expanded(flex: 2, child: _buildBrokerField()),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: brokerShareController,
                      label: 'Share %',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      readOnly: _readOnlyMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            Row(
  children: [
    Expanded(
      child: _buildTextField(
          controller: eWayBillController,
          label: 'E-Way Bill No',
          readOnly: _readOnlyMode),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _buildTransportField(),
    ),
  ],
),
const SizedBox(height: 16),

            _buildTextField(
                controller: remarkController,
                label: 'Remark',
                maxLines: 2,
                readOnly: _readOnlyMode),
            const SizedBox(height: 20),

            _buildActionButtonsRow(),
            const SizedBox(height: 24),

            _buildItemsTable(),
            const SizedBox(height: 24),

            _buildFooterTotals(),
            const SizedBox(height: 24),

            if (_canSaveOrder)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    _save();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isEditMode ? 'Update Invoice' : 'Save Invoice',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Helper Widgets ───────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2)),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dateFormat.format(date)),
            Icon(Icons.calendar_today,
                size: 18,
                color: _readOnlyMode
                    ? Colors.grey.shade400
                    : Colors.blue.shade700),
          ],
        ),
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
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 360;
      return DropdownButtonFormField(
        value: items.any((e) => (e['Id'] ?? e['id']) == value)
            ? value
            : null,
        decoration: InputDecoration(
          labelText: label,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          filled: !enabled,
          fillColor: !enabled ? Colors.grey.shade100 : null,
          contentPadding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 8 : 12,
              vertical: isNarrow ? 10 : 14),
        ),
        style: TextStyle(
            fontSize: isNarrow ? 12 : 14, color: Colors.black87),
        isExpanded: true,
        items: items.map((item) {
          final id = isString
              ? item['id'] as String
              : (item['Id'] ?? item['id']);
          return DropdownMenuItem(
              value: id,
              child: Text(item['Name'] ?? 'Unknown',
                  overflow: TextOverflow.ellipsis, maxLines: 1));
        }).toList(),
        onChanged: enabled ? onChanged : null,
      );
    });
  }

  Widget _buildPartyField() {
    return FormField<int>(
      validator: (_) => null,
      builder: (state) {
        return InkWell(
          focusNode: _partyFocusNode,
          onFocusChange: (_) => setState(() {}),
          onTap: (isEditMode || _readOnlyMode) ? null : _openPartySearch,
          child: InputDecorator(
            isFocused: _partyFocusNode.hasFocus,
            decoration: InputDecoration(
              labelText: 'Party *',
              errorText: state.errorText,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade700, width: 2)),
              filled: isEditMode || _readOnlyMode,
              fillColor: (isEditMode || _readOnlyMode)
                  ? Colors.grey.shade100
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedPartyName ?? 'Select Party',
                    style: TextStyle(
                        color: selectedPartyName != null
                            ? Colors.black87
                            : Colors.grey.shade500),
                  ),
                ),
                if (!isEditMode && !_readOnlyMode)
                  Icon(Icons.search,
                      size: 20, color: Colors.blue.shade700),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrokerField() {
    return InkWell(
      onTap: _readOnlyMode ? null : _openBrokerSearch,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Broker',
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          filled: _readOnlyMode,
          fillColor: _readOnlyMode ? Colors.grey.shade100 : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: selectedBrokerId != null && !_readOnlyMode
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() {
                        selectedBrokerId = null;
                        selectedBrokerName = null;
                      }))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedBrokerName ?? 'Select Broker',
                style: TextStyle(
                    color: selectedBrokerName != null
                        ? Colors.black87
                        : Colors.grey.shade500),
              ),
            ),
            if (!_readOnlyMode)
              Icon(Icons.search, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportField() {
    return InkWell(
      onTap: _readOnlyMode
          ? null
          : () async {
              if (transportList.isEmpty) return;
              final result =
                  await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                    builder: (_) => TransportSearchScreen(
                        transports: transportList)),
              );
              if (result != null && mounted) {
                setState(() {
                  selectedTransportId =
                      result['Id'] ?? result['id'];
                });
              }
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Transport',
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          filled: _readOnlyMode,
          fillColor: _readOnlyMode ? Colors.grey.shade100 : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _getTransportName(),
                style: TextStyle(
                    color: selectedTransportId != null
                        ? Colors.black87
                        : Colors.grey.shade500),
              ),
            ),
            Icon(Icons.search,
                color: _readOnlyMode
                    ? Colors.grey.shade400
                    : Colors.blue.shade700),
          ],
        ),
      ),
    );
  }

  String _getTransportName() {
    if (selectedTransportId == null) return 'Select Transport';
    final match = transportList.firstWhere(
        (t) =>
            t['Id'] == selectedTransportId ||
            t['id'] == selectedTransportId,
        orElse: () => {});
    return match.isNotEmpty
        ? (match['Name'] ?? match['TransportName'] ?? 'Unknown')
        : 'Select Transport';
  }

  Widget _buildBookField() {
    return LayoutBuilder(builder: (context, constraints) {
      return DropdownButtonFormField<int>(
        value: bookMasterList.any(
                (b) => (b['id'] as num?)?.toInt() == selectedBookId)
            ? selectedBookId
            : null,
        decoration: InputDecoration(
          labelText: 'Book',
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          // In edit mode lock the book — Angular disables BookId on edit
          filled: isEditMode || _readOnlyMode,
          fillColor: (isEditMode || _readOnlyMode)
              ? Colors.grey.shade100
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        isExpanded: true,
        // Mirrors Angular: SPHdrForm.get('BookId').disable() in edit mode
        onChanged: (isEditMode || _readOnlyMode)
            ? null
            : (v) {
                setState(() => selectedBookId = v);
              },
        items: bookMasterList.map((b) {
          final id = (b['id'] as num?)?.toInt() ?? 0;
          final name = (b['BKName'] ?? b['Name'] ?? b['AcName'] ?? '')
              .toString();
          return DropdownMenuItem<int>(
            value: id,
            child: Text(name, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        hint: Text('Select Book',
            style: TextStyle(color: Colors.grey.shade500)),
      );
    });
  }

  Widget _buildPlaceOfSupplyField() {
    return InkWell(
      onTap: _readOnlyMode || stateList.isEmpty
          ? null
          : () async {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (_) => _StateSearchDialog(states: stateList),
              );
              if (result != null && mounted) {
                setState(() {
                  selectedPlaceOfSupplyId = (result['id'] as num?)?.toInt() ?? 0;
                  selectedPlaceOfSupplyName =
                      (result['StateName'] ?? result['Name'] ?? '').toString();
                  // Recompute interstate when user manually changes POS
                  _isInterStateParty =
                      _computeIsInterStateByPosId(selectedPlaceOfSupplyId);
                });
              }
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Place of Supply',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          filled: _readOnlyMode,
          fillColor: _readOnlyMode ? Colors.grey.shade100 : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: Icon(
            Icons.arrow_drop_down,
            color: _readOnlyMode ? Colors.grey.shade400 : Colors.blue.shade700,
          ),
        ),
        child: Text(
          selectedPlaceOfSupplyName ?? 'Select Place of Supply',
          style: TextStyle(
            color: selectedPlaceOfSupplyName != null
                ? Colors.black87
                : Colors.grey.shade500,
          ),
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
          if (selectedPartyGSTNo != null &&
              selectedPartyGSTNo!.isNotEmpty)
            _buildInfoRow('GST No', selectedPartyGSTNo!),
          if (selectedPartyPANNo != null &&
              selectedPartyPANNo!.isNotEmpty)
            _buildInfoRow('PAN No', selectedPartyPANNo!),
          if (selectedPartyCategoryName != null)
            _buildInfoRow('Category', selectedPartyCategoryName!),
          _buildInfoRow(
            'Current Balance',
            combinedBalance <= 0
                ? '₹${combinedBalance.abs().toStringAsFixed(2)} Dr'
                : '₹${combinedBalance.toStringAsFixed(2)} Cr',
          ),
          if (_isInterStateParty)
            _buildInfoRow('GST Type', 'Inter-State (IGST)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13, color: Colors.blue.shade900))),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow() {                                       // ← REPLACE
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          'Transport Details',
          Icons.local_shipping,
          onTap: () async {                                               // ← ADD
            final result = await _openTransportDialog();                  // ← ADD
            if (result != null) {                                         // ← ADD
              setState(() {                                               // ← ADD
                _transportData = result;                                  // ← ADD
                selectedTransportId = result.transportId;                // ← ADD
              });                                                         // ← ADD
            }                                                             // ← ADD
          },
        ),
        _buildActionButton('Extra Fields', Icons.more_horiz),
        _buildActionButton('Overheads', Icons.request_quote),
        _buildActionButton('GST Summary', Icons.summarize),
      ],
    );
  }

 Widget _buildActionButton(
    String label,
    IconData icon, {
    VoidCallback? onTap,                                                  // ← ADD param
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onTap ??                                             // ← CHANGE
              () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label clicked'))),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade700,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.blue.shade200)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Colors.blue.shade300),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Expanded(
                    child: Text('Item Details',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue))),
                if (_canAddItem)
                  ElevatedButton.icon(
                    onPressed: openAddItemPopup,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0),
                  ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No items added',
                    style: TextStyle(color: Colors.grey)))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (_, i) => _buildItemCard(items[i], i),
            ),
          if (items.isNotEmpty) _buildTotalsRow(),
        ],
      ),
    );
  }

  Widget _buildItemCard(OrderItem item, int index) {
    final itemOverhead = _itemOverheadAmount(item);
    final hasOverhead = itemOverhead != 0;
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
                child: Text(item.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              if (_canOpenItemEdit)
                IconButton(
                  icon: Icon(Icons.edit,
                      size: 18, color: Colors.blue.shade700),
                  onPressed: () => openEditItemPopup(item, index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (_canOpenItemEdit) const SizedBox(width: 8),
              if (_canDeleteItem)
                IconButton(
                  icon: const Icon(Icons.delete,
                      size: 18, color: Colors.red),
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
              _buildItemDetail(
                  item.valUnit, item.qty.toStringAsFixed(3)),
              _buildItemDetail(
                  'Rate', '₹${item.rate.toStringAsFixed(4)}'),
              if (item.tpRate > 0)
                _buildItemDetail(
                    'TP Rate', '₹${item.tpRate.toStringAsFixed(4)}'),
              _buildItemDetail(
                  'Basic Amt', '₹${item.amount.toStringAsFixed(2)}'),
              if (item.weight > 0)
                _buildItemDetail(
                    'Weight', item.weight.toStringAsFixed(3)),
            ],
          ),

          // ── Overhead section — shown only when overhead exists ──────
          if (hasOverhead) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.request_quote,
                          size: 13, color: Colors.indigo.shade700),
                      const SizedBox(width: 4),
                      Text('Overhead',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.indigo.shade700)),
                      const Spacer(),
                      Text(
                        '₹${itemOverhead.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade800),
                      ),
                    ],
                  ),
                  if (item.cgstAmt != 0 ||
                      item.sgstAmt != 0 ||
                      item.igstAmt != 0) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        if (item.cgstAmt != 0)
                          _gstChip(
                              'CGST', item.cgstAmt, Colors.teal),
                        if (item.sgstAmt != 0)
                          _gstChip(
                              'SGST', item.sgstAmt, Colors.teal),
                        if (item.igstAmt != 0)
                          _gstChip(
                              'IGST', item.igstAmt, Colors.purple),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Net = basic + overhead
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Net: ',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600)),
                      Text(
                        '₹${(item.amount + itemOverhead).toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gstChip(String label, double amt, MaterialColor color) {
    return Text(
      '$label: ₹${amt.toStringAsFixed(2)}',
      style: TextStyle(
          fontSize: 11,
          color: color.shade700,
          fontWeight: FontWeight.w500),
    );
  }

  Widget _buildItemDetail(String label, String value) {
    return Text('$label: $value',
        style: const TextStyle(fontSize: 12, color: Colors.black87));
  }

  Widget _buildTotalsRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100]),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTotalItem(
                  'Items', items.length.toString(), Icons.inventory_2),
              _buildTotalItem(
                  'Bags', totalBags.toIndianNumber(), Icons.shopping_bag),
              _buildTotalItem(
                  'Qty', totalQty.toIndianQty(), Icons.scale),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Basic Amount:'),
                    Text(totalAmount.toIndianCurrency(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                if (totalOverhead != 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Overhead:',
                          style:
                              TextStyle(color: Colors.indigo.shade700)),
                      Text(
                        '+ ₹${totalOverhead.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.indigo.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (totalCgst != 0 || totalSgst != 0 || totalIgst != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 12,
                        children: [
                          if (totalCgst != 0)
                            _gstChip('CGST', totalCgst, Colors.teal),
                          if (totalSgst != 0)
                            _gstChip('SGST', totalSgst, Colors.teal),
                          if (totalIgst != 0)
                            _gstChip('IGST', totalIgst, Colors.purple),
                        ],
                      ),
                    ),
                  const Divider(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      (totalAmount + totalOverhead).toIndianCurrency(),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700),
                    ),
                  ],
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
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildFooterTotals() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Charges & Net Totals',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            const SizedBox(height: 12),
            Row(
              children: [
                // REPLACE the freight and tcs fields in _buildFooterTotals():
Expanded(
    child: _buildTextField(
        controller: freightAmtController,
        label: 'Freight Amt',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        readOnly: _readOnlyMode)),   // ← remove onChanged: (_) => _calculateTotals()
const SizedBox(width: 12),
Expanded(
    child: _buildTextField(
        controller: tcsAmountController,
        label: 'TCS Amount',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        readOnly: _readOnlyMode)),   // ← remove onChanged: (_) => _calculateTotals()
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(
                        controller: roundDiffController,
                        label: 'Round Diff',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        onChanged: (_) => _calculateTotals(),
                        readOnly: _readOnlyMode)),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Net Amount',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.green.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    child: Text(
                      netAmount.toIndianCurrency(),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Receipt Settlement',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            const SizedBox(height: 12),
            if (_showCashReceivedField || _showEPayField)
              Row(
                children: [
                  if (_showCashReceivedField)
                    Expanded(
                        child: _buildTextField(
                            controller: cashReceivedController,
                            label: 'Cash Received',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            focusNode: _cashReceivedFocusNode,
                            readOnly: _readOnlyMode)),
                  if (_showCashReceivedField && _showEPayField)
                    const SizedBox(width: 12),
                  if (_showEPayField)
                    Expanded(
                        child: _buildTextField(
                            controller: ePayAmountController,
                            label: 'E-Pay Amount',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            focusNode: _ePayAmountFocusNode,
                            readOnly: _readOnlyMode)),
                ],
              ),
          ],
        ),
      ),
    );
  }
  DateTime? _parseDateSafe(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }
  // Inside _CreateSalesInvoicePageState, add this new method:

  Future<void> _autoGenerateOutstandingIfNeeded(int invTranId) async {
    // Mirrors: if (SRFlag != 'PSI' && PartyAccountId > 0 && PayModeD == 'R')
    if (selectedPartyId == null || selectedPartyId! <= 0) return;
    if (selectedPaymentMode != 'R') return;

    try {
      final grLedgerData = await GeneralService.getInvDataForOutstanding(
        invTranId: invTranId,
        invSr: 'SIN',
        dlAccountId: selectedBrokerId ?? 0,
        coSoftId: _global.coSoftId ?? 0,
      );
      if (grLedgerData == null) return;

      // Mirrors: CheckLedgerAccountMaintainsOutstanding(AccountsData, GlAccountId)
      final glAccountId = grLedgerData['GlAccountId'];
      final party = partyById[glAccountId] ?? partyById[selectedPartyId];
      final maintainsOutstanding = party?['AcOs'] == true;
      if (!maintainsOutstanding) return;

      // Mirrors: createAutoGenerateEntry branch only — we never take the
      // "open OS modal" branch here, since that's edit-mode / manual entry.
      final dueDays = int.tryParse(dueDaysController.text) ?? 0;

      final ok = await GeneralService.addEditGLOS(
        glLedgerData: grLedgerData,
        dueDays: dueDays,
        dlAccountId: selectedBrokerId ?? 0,
        salePersonId: selectedSalesPersonId ?? 0,
        costCentreId: 0, // wire up if you track CostCentreId on invoice header
        coSoftId: _global.coSoftId ?? 0,
        coFinYear: _global.CofinYear ?? 0,
      );
      

      if (ok && mounted) {
        await _showOutstandingGeneratedDialog();
      }
    } catch (e) {
      debugPrint('Outstanding auto-generate error: $e');
      // silent — don't block the save flow the user already completed
    }
  }

  Future<void> _showOutstandingGeneratedDialog() {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Outstanding generated Successfully'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  Future<void> _showEditOutstandingNoticeDialog() {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Outstanding Not Updated'),
        content: const Text(
          'This invoice was updated. Outstanding entries are not '
          'auto-managed for edited invoices — please review/update '
          'the outstanding entry from the web app if required.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── State Search Dialog ───────────────────────────────────────────────────
class _StateSearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> states;
  const _StateSearchDialog({required this.states});
 
  @override
  State<_StateSearchDialog> createState() => _StateSearchDialogState();
}
 
class _StateSearchDialogState extends State<_StateSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];
 
  @override
  void initState() {
    super.initState();
    _filtered = widget.states;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = widget.states.where((s) {
          final name =
              ((s['StateName'] ?? s['Name'] ?? '') as String).toLowerCase();
          return name.contains(q);
        }).toList();
      });
    });
  }
 
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search state...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final s = _filtered[i];
                final name =
                    (s['StateName'] ?? s['Name'] ?? '').toString();
                return ListTile(
                  title: Text(name),
                  onTap: () => Navigator.pop(context, s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  // ← _parseDateSafe REMOVED from here — it lives in _CreateSalesInvoicePageState
}
