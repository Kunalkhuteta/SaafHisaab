import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saafhisaab/services/general_service.dart';
import 'package:saafhisaab/services/global_data.dart';
import 'package:saafhisaab/widgets/bottom_contact_bar.dart';
import 'package:url_launcher/url_launcher.dart';

enum TransType { regular, billToShipTo, billFromDispatchFrom, both }

extension TransTypeX on TransType {
  int get id => index + 1;
  static TransType fromId(int id) => TransType.values[(id - 1).clamp(0, 3)];
}

class EWayBillEinvoiceDialog extends StatefulWidget {
  final int invTranIdNo;
  final bool isEWayBill; // flag: true = E-Way Bill form, false = E-Invoice form
  final bool isUpdateOnly;

  const EWayBillEinvoiceDialog({
    super.key,
    required this.invTranIdNo,
    required this.isEWayBill,
    this.isUpdateOnly = false,
  });

  @override
  State<EWayBillEinvoiceDialog> createState() => _EWayBillEinvoiceDialogState();
}

// lib/models/address_master.dart
class AddressMaster {
  final int id;
  final String firmName;
  final String address;
  final String address1;
  final String station;
  final String pincode;
  final int stateId;

  AddressMaster({
    this.id = 0,
    this.firmName = '',
    this.address = '',
    this.address1 = '',
    this.station = '',
    this.pincode = '',
    this.stateId = 0,
  });

  factory AddressMaster.fromJson(Map<String, dynamic> json) {
    return AddressMaster(
      id: json['id'] ?? 0,
      firmName: json['FirmName'] ?? '',
      address: json['Address'] ?? '',
      address1: json['Address1'] ?? '',
      station: json['Station'] ?? '',
      pincode: json['Pincode'] ?? '',
      stateId: json['StateId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'FirmName': firmName,
      'Address': address,
      'Address1': address1,
      'Station': station,
      'Pincode': pincode,
      'StateId': stateId,
    };
  }
}

class _EWayBillEinvoiceDialogState extends State<EWayBillEinvoiceDialog> {
  final GlobalData _gd = GlobalData();
  bool _loading = true;
  Map<String, dynamic>? _itranData;

  // ── Header fields (EWayBillForm) ──────────────────────────────────
  int? subType;
  int? supplyType;
  final subTypeDescCtrl = TextEditingController();
  int? billType;
  int? transTypeId;

  String companyPincode = '';
  String companyGstNo = '';
  String consigneePincode = '';
  String buyerGstNo = '';
  String companyStateName = '';
  String partyStateName = '';
  String partyName = '';
  String invoiceNo = '';
  String invoiceDate = '';
  String netAmount = '';
  bool _showValidationErrors = false;

  // ── Transport form ─────────────────────────────────────────────────
  int transportMode = 1;
  String vehicleType = 'R';
  final distanceCtrl = TextEditingController();
  final transportNameCtrl = TextEditingController();
  final transportIdCtrl = TextEditingController(); // GST No of transporter
  final vehicleNoCtrl = TextEditingController();
  final grNoCtrl = TextEditingController();
  DateTime grDate = DateTime.now();

  // ── Dispatch (Consignor) form ───────────────────────────────────────
  final consignorCtrl = TextEditingController();
  final consignorAdd1Ctrl = TextEditingController();
  final consignorAdd2Ctrl = TextEditingController();
  final consignorPlaceCtrl = TextEditingController();
  final consignorPinCtrl = TextEditingController();
  int? consignorStateId;

  // ── Consignee form ────────────────────────────────────────────────
  final consigneeCtrl = TextEditingController();
  final consigneeAdd1Ctrl = TextEditingController();
  final consigneeAdd2Ctrl = TextEditingController();
  final consigneePlaceCtrl = TextEditingController();
  final consigneePinCtrl = TextEditingController();
  final shipToGstCtrl = TextEditingController();
  int? consigneeStateId;

  double mDistance = 0;
  int mAccountId = 0;

  List<Map<String, dynamic>> transportData = [];
  List<Map<String, dynamic>> stateData = [];
  List<AddressMaster> addressTypeData = []; // ← add this
  String? _errorMessage;

  static const subTypeData = [
    {'id': 1, 'name': '1-Supply'},
    {'id': 2, 'name': '2-Import'},
    {'id': 3, 'name': '3-Export'},
    {'id': 4, 'name': '4-Job Work'},
    {'id': 5, 'name': '5-For Own Use'},
    {'id': 6, 'name': '6-Job work Returns'},
    {'id': 7, 'name': '7-Sales Return'},
    {'id': 8, 'name': '8-Others'},
    {'id': 9, 'name': '9-SKD/CKD'},
    {'id': 11, 'name': '11-Recipient Not Known'},
    {'id': 12, 'name': '12-Exhibition or Fairs'},
    {'id': 13, 'name': '13-Line Sales'},
  ];
  static const supplyTypeData = [
    {'id': 'O', 'name': 'Outward'},
    {'id': 'I', 'name': 'Inward'},
  ];
  static const billTypeData = [
    {'id': 1, 'name': 'Regular'},
    {'id': 2, 'name': 'Bill To - Ship To'},
    {'id': 3, 'name': 'Bill From - Dispatch From'},
    {'id': 4, 'name': 'SKD/CKD/Lots'},
  ];
  static const transTypeData = [
    {'id': 1, 'name': '1- Regular'},
    {'id': 2, 'name': '2- Bill To-Ship To'},
    {'id': 3, 'name': '3- Bill From-Dispatch From'},
    {'id': 4, 'name': '4- Combination of 2 & 3'},
  ];
  static const transportModeData = [
    {'id': 1, 'name': 'Road'},
    {'id': 2, 'name': 'Rail'},
    {'id': 3, 'name': 'Air'},
    {'id': 4, 'name': 'Ship'},
  ];
  static const vehicleTypeData = [
    {'id': 'R', 'name': 'Regular'},
    {'id': 'O', 'name': 'ODC'},
  ];

  bool get _showConsigneeForm => transTypeId == 2 || transTypeId == 4;
  bool get _showDispatchForm => transTypeId == 3 || transTypeId == 4;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Mirrors Angular constructor: stateService.getAllStates1$().subscribe(...)
      // Called unconditionally, first, independent of AppSoftCode/UseMultiAddressFeature
      try {
        stateData = await GeneralService.getAllStates(
          clientRegId: _gd.clientRegId ?? 0,
        );
      } catch (e) {
        debugPrint('getAllStates error: $e');
        stateData = [];
      }

      // Mirrors: if (this.globalData.AppSoftCode != "CCWIN") this.GetTransportData();
      if (_gd.appSoftCode != 'CCWIN') {
        try {
          transportData = await GeneralService.getAllTransport();
        } catch (e) {
          debugPrint('getAllTransport error: $e');
          transportData = [];
        }
      }

      // Mirrors: if (this.SysParamAccountData.UseMultiAddressFeature) { AddressTypeData = ...getAllAddressMasterByAccountId(-1) }
      if (GlobalData().sysParamAccountData?.useMultiAddressFeature == true) {
        try {
          addressTypeData = await GeneralService.getAllAddressMasterByAccountId(
            -1,
          );
        } catch (e) {
          debugPrint('getAllAddressMasterByAccountId error: $e');
          addressTypeData = [];
        }
      }

      if (widget.invTranIdNo > 0) {
        final data = await GeneralService.getItranDataForEInv(
          widget.invTranIdNo,
        );
        if (data != null) {
          _itranData = data;
          _assignFormValues(data);
        } else {
          _errorMessage = 'No E-Invoice data found for this invoice.';
        }
      }
    } catch (e, st) {
      debugPrint('EWayBillEinvoiceDialog init error: $e\n$st');
      _errorMessage = 'Failed to load invoice details: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  void _assignFormValues(Map<String, dynamic> data) {
    partyName = (data['BuyerName'] ?? data['PartyName'] ?? '').toString();
    invoiceNo = (data['EIDocNo'] ?? data['InvNo'] ?? '').toString();
    final invDateRaw = data['EIDocDate'] ?? data['InvDate'];
    invoiceDate =
        invDateRaw != null && invDateRaw.toString().isNotEmpty
            ? DateFormat(
              'dd/MM/yyyy',
            ).format(DateTime.tryParse(invDateRaw.toString()) ?? DateTime.now())
            : '';
    netAmount = (data['EIInvAmt'] ?? data['NetAmount'] ?? '').toString();
    mDistance = (data['Distance'] as num?)?.toDouble() ?? 0;
    mAccountId = _toInt(data['AccountId']) ?? 0;

    subType = _toInt(data['EWSubType']);
    supplyType = _toInt(data['EISupplyType']);
    subTypeDescCtrl.text = (data['SubTypeDesc'] ?? '').toString();
    billType = _toInt(data['EWBillType']);
    transTypeId = _toInt(data['EWTransType']);

    companyPincode = (data['CompanyPinCode'] ?? '').toString();
    companyGstNo = (data['CompanyGSTNo'] ?? '').toString();
    consigneePincode = (data['ConsigneePincode'] ?? '').toString();
    buyerGstNo = (data['BuyerGstNo'] ?? '').toString();
    companyStateName = (data['CompanyStateName'] ?? '').toString();
    partyStateName = (data['PartyStateName'] ?? '').toString();

    transportMode = _toInt(data['TPMode']) ?? 1;
    vehicleType = (data['ViehicalType'] ?? 'R').toString();
    distanceCtrl.text = (data['Distance'] ?? '').toString();
    transportNameCtrl.text = (data['TransportName'] ?? '').toString();
    transportIdCtrl.text = (data['TransportId'] ?? '').toString();
    vehicleNoCtrl.text = (data['ViehicalNo'] ?? '').toString();
    grNoCtrl.text = (data['EWGRNo'] ?? '').toString();
    final grDateRaw = data['EWGRDate'];
    if (grDateRaw != null && grDateRaw.toString().isNotEmpty) {
      grDate = DateTime.tryParse(grDateRaw.toString()) ?? DateTime.now();
    }

    consignorCtrl.text = (data['Consignor'] ?? '').toString();
    consignorAdd1Ctrl.text = (data['ConsignorAdd1'] ?? '').toString();
    consignorAdd2Ctrl.text = (data['ConsignorAdd2'] ?? '').toString();
    consignorPlaceCtrl.text = (data['ConsignorPlace'] ?? '').toString();
    consignorPinCtrl.text = (data['ConsignorPincode'] ?? '').toString();
    consignorStateId = _toInt(data['DispFromStateId']);

    consigneeCtrl.text = (data['Consignee'] ?? '').toString();
    consigneeAdd1Ctrl.text = (data['ConsigneeAdd1'] ?? '').toString();
    consigneeAdd2Ctrl.text = (data['ConsigneeAdd2'] ?? '').toString();
    consigneePlaceCtrl.text = (data['ConsigneePlace'] ?? '').toString();
    consigneePinCtrl.text = (data['ConsigneePincode'] ?? '').toString();
    shipToGstCtrl.text = (data['ShipToGstNo'] ?? '').toString();
    consigneeStateId = _toInt(data['ShipToStateId']);
  }

  Future<void> _openDistanceCheckerPortal() async {
    final uri = Uri.parse('https://ewaybillgst.gov.in/Others/P2PDistance.aspx');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the distance checker page'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Transport ↔ ID auto-fill, mirrors patchTransportDetails() ───────
  void _onTransportIdChanged() {
    final id = transportIdCtrl.text.trim();
    if (id.isEmpty) return;
    final match = transportData.firstWhere(
      (t) => (t['GSTNo'] ?? '').toString() == id,
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      setState(() => transportNameCtrl.text = (match['Name'] ?? '').toString());
    }
  }

  void _onTransportNameChanged(String name) {
    final match = transportData.firstWhere(
      (t) => (t['Name'] ?? '').toString() == name,
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      setState(() => transportIdCtrl.text = (match['GSTNo'] ?? '').toString());
    }
  }

  Future<void> _pickGrDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: grDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => grDate = picked);
  }

  bool _validateRequired() {
    if (subType == null || billType == null || transTypeId == null)
      return false;
    if (_gd.appSoftCode == 'MANDI') {
      if (grNoCtrl.text.isEmpty &&
          transportIdCtrl.text.isEmpty &&
          vehicleNoCtrl.text.isEmpty) {
        return false;
      }
      if (_showDispatchForm &&
          (consignorPinCtrl.text.isEmpty || consignorStateId == null))
        return false;
      if (_showConsigneeForm &&
          (consigneePinCtrl.text.isEmpty ||
              consigneeStateId == null ||
              shipToGstCtrl.text.isEmpty))
        return false;
    }
    return true;
  }

  Map<String, dynamic> _buildPayload() {
    final data = Map<String, dynamic>.from(_itranData ?? {});
    data['EWSubType'] = subType;
    data['SubTypeDesc'] = subTypeDescCtrl.text;
    data['EWBillType'] = billType;
    data['EWTransType'] = transTypeId;
    data['EISupplyType'] = supplyType;

    if (widget.isEWayBill || (_gd.appSoftCode ?? '') != 'CCWIN') {
      if (transTypeId == 2 || transTypeId == 4) {
        data['ShipToStateId'] = consigneeStateId;
        data['ShipToGstNo'] = shipToGstCtrl.text;
      }
      data['EWConsigneeGSTNo'] = buyerGstNo;

      if (transTypeId != 3 && transTypeId != 4) {
        data['DispFromStateId'] = consignorStateId;
      } else {
        data['DispFromStateId'] = _gd.gstStateId ?? 0;
      }

      data['Consignee'] = consigneeCtrl.text;
      data['ConsigneeAdd1'] = consigneeAdd1Ctrl.text;
      data['ConsigneeAdd2'] = consigneeAdd2Ctrl.text;
      data['ConsigneePlace'] = consigneePlaceCtrl.text;
      data['ConsigneePincode'] = consigneePinCtrl.text;
      data['Consignor'] = consignorCtrl.text;
      data['ConsignorAdd1'] = consignorAdd1Ctrl.text;
      data['ConsignorAdd2'] = consignorAdd2Ctrl.text;
      data['ConsignorPlace'] = consignorPlaceCtrl.text;
      data['ConsignorPincode'] = consignorPinCtrl.text;
      data['TPMode'] = transportMode;
      data['Distance'] = double.tryParse(distanceCtrl.text) ?? 0;
      data['ViehicalType'] = vehicleType;
      data['TransportName'] = transportNameCtrl.text;
      data['TransportId'] = transportIdCtrl.text;
      data['ViehicalNo'] = vehicleNoCtrl.text;
      data['EWGRNo'] = grNoCtrl.text;
      data['EWGRDate'] = grDate.toIso8601String();
    }
    return data;
  }

  Future<void> _save() async {
    setState(() => _showValidationErrors = true);

    if (!_validateRequired()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = _buildPayload();
    final id = (data['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) {
      Navigator.pop(context, false);
      return;
    }

    bool reply = true;
    if (widget.isEWayBill && !widget.isUpdateOnly) {
      reply = await _confirm('Confirm', 'Do you Want to Generate E-Way Bill?');
      if (mDistance != (double.tryParse(distanceCtrl.text) ?? 0)) {
        final updateDist = await _confirm(
          'Confirm',
          'Do you Want to Update Distance in Account?',
        );
        if (updateDist) {
          await GeneralService.updateFieldInAnyTable(
            tableId: mAccountId,
            matchByFieldName: 'AccountId',
            tableName: 'AccountMast',
            fieldName: 'Distance',
            fieldType: 'DECIMAL',
            fieldValueDecimal: double.tryParse(distanceCtrl.text) ?? 0,
            forceUpdateForCosoftId: true,
          );
        }
      }
    } else if (widget.isUpdateOnly) {
      reply = false;
    }

    setState(() => _loading = true);
    final result = await GeneralService.updateEInvData(
      generateEwayBill: widget.isEWayBill, // commenting this only for testing purpose
      // generateEwayBill: false, // false explicit only for testing purpose
      onlyUpdateData: !reply,
      data: data,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['httpStatusCode'] == 400) {
      await _confirm(
        'Error!!',
        (result['MyMessage'] ?? 'Failed').toString(),
        singleButton: true,
      );
      if (mounted) Navigator.pop(context, false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEWayBill ? 'E-Way Bill Generated' : 'E-Invoice Generated',
          ),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    bool singleButton = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions:
                singleButton
                    ? [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('OK'),
                      ),
                    ]
                    : [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('No'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Yes'),
                      ),
                    ],
          ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    subTypeDescCtrl.dispose();
    distanceCtrl.dispose();
    transportNameCtrl.dispose();
    transportIdCtrl.dispose();
    vehicleNoCtrl.dispose();
    grNoCtrl.dispose();
    consignorCtrl.dispose();
    consignorAdd1Ctrl.dispose();
    consignorAdd2Ctrl.dispose();
    consignorPlaceCtrl.dispose();
    consignorPinCtrl.dispose();
    consigneeCtrl.dispose();
    consigneeAdd1Ctrl.dispose();
    consigneeAdd2Ctrl.dispose();
    consigneePlaceCtrl.dispose();
    consigneePinCtrl.dispose();
    shipToGstCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1565C0);
    final title =
        widget.isEWayBill
            ? 'E-Way Bill Details'
            : 'EInvoice/E-Way Bill Additional Details';

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFFF4F7FB),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 48,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context, false),
          ),
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildError()
                : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _summaryCard(blue),
                            const SizedBox(height: 8),
                            _detailsCard(blue),
                            const SizedBox(height: 8),
                            _transporterCard(blue),
                            const SizedBox(height: 8),
                            _noteBanner(blue),
                          ],
                        ),
                      ),
                    ),
                    _buttonBar(blue),
                  ],
                ),
        bottomNavigationBar: const BottomContactBar(),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.blue.shade200),
          const SizedBox(height: 14),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _loading = true);
              _init();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Card shell ───────────────────────────────────────────────────────
  Widget _card({required Widget child, String? title, Color? accent}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE6F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (accent ?? const Color(0xFF1565C0)).withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFDCE6F5)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent ?? const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: accent ?? const Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  // ── Party summary card: fixed 2x2 grid ──────────────────────────────
  Widget _summaryCard(Color blue) {
    return _card(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _summaryItem('Party Name', partyName, blue)),
              const SizedBox(width: 14),
              Expanded(child: _summaryItem('Invoice No', invoiceNo, blue)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _summaryItem('Date', invoiceDate, blue)),
              const SizedBox(width: 14),
              Expanded(child: _summaryItem('Net Amount', netAmount, blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color blue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: blue,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── Document / party details card: fixed 2-column rows ──────────────
  Widget _detailsCard(Color blue) {
    return _card(
      child: Column(
        children: [
          _row2(
            _col('Seller State', _greyBox(companyStateName)),
            _col('PinCode', _greyBox(companyPincode)),
          ),
          _gap(),
          _row2(
            _col('GSTIN/UIN', _greyBox(companyGstNo)),
            _col(
              'Document Type *',
              _dropdown<int>(
                value: billType,
                items: billTypeData,
                onChanged: (v) => setState(() => billType = v),
                isRequired: true,
                hasError: _showValidationErrors && billType == null,
              ),
            ),
          ),
          _gap(),
          _row2(
            _col(
              'Sub Type *',
              _dropdown<int>(
                value: subType,
                items: subTypeData,
                onChanged: (v) => setState(() => subType = v),
                isRequired: true,
                hasError: _showValidationErrors && subType == null,
              ),
            ),
            _col('Buyer State', _greyBox(partyStateName)),
          ),
          _gap(),
          _row2(
            _col('PinCode', _greyBox(consigneePincode)),
            _col('GSTIN/UIN', _greyBox(buyerGstNo)),
          ),
          _gap(),
          _row2(
            _col(
              'Transaction Type *',
              _dropdown<int>(
                value: transTypeId,
                items: transTypeData,
                onChanged: (v) => setState(() => transTypeId = v),
                isRequired: true,
                hasError: _showValidationErrors && transTypeId == null,
              ),
            ),
            const SizedBox(),
          ),
          if (subType == 8) ...[
            _gap(),
            _row2(
              _col(
                'Sub Type Description *',
                _textField(
                  controller: subTypeDescCtrl,
                  hint: 'Enter description',
                  isRequired: true,
                  hasError:
                      _showValidationErrors &&
                      subTypeDescCtrl.text.trim().isEmpty,
                ),
              ),
              const SizedBox(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Transporter details card ────────────────────────────────────────
  Widget _transporterCard(Color blue) {
    final isMandi = _gd.appSoftCode == 'MANDI';
    final needsGrOrTransportOrVehicle =
        grNoCtrl.text.trim().isEmpty &&
        transportIdCtrl.text.trim().isEmpty &&
        vehicleNoCtrl.text.trim().isEmpty;
    final showTransportGroupError =
        _showValidationErrors && isMandi && needsGrOrTransportOrVehicle;

    return _card(
      title: 'Transporter Details',
      accent: blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row2(
            _col(
              'Mode',
              _dropdown<int>(
                value: transportMode,
                items: transportModeData,
                onChanged: (v) => setState(() => transportMode = v ?? 1),
              ),
            ),
            _col(
              'Distance (in KM)',
              _textField(
                controller: distanceCtrl,
                hint: '0',
                keyboardType: TextInputType.number,
              ),
            ),
          ),
          _gap(),
          _row2(
            _col(
              'Transporter Name',
              _textField(
                controller: transportNameCtrl,
                hint: 'Search transporter',
                onChanged: (v) {
                  _onTransportNameChanged(v);
                  setState(() {});
                },
              ),
            ),
            _col(
              'Transporter ID',
              _textField(
                controller: transportIdCtrl,
                hint: 'GSTIN of transporter',
                onChanged: (_) {
                  _onTransportIdChanged();
                  setState(() {});
                },
                hasError: showTransportGroupError,
              ),
            ),
          ),
          _gap(),
          _row2(
            _col(
              'Vehicle Type',
              _dropdown<String>(
                value: vehicleType,
                items: vehicleTypeData,
                onChanged: (v) => setState(() => vehicleType = v ?? 'R'),
              ),
            ),
            _col(
              'Vehicle No',
              _textField(
                controller: vehicleNoCtrl,
                hint: 'e.g. RJ14AB1234',
                onChanged: (_) => setState(() {}),
                hasError: showTransportGroupError,
              ),
            ),
          ),
          _gap(),
          _row2(
            _col(
              'Doc/Loading/RR/Airway No.',
              _textField(
                controller: grNoCtrl,
                hint: 'Enter number',
                onChanged: (_) => setState(() {}),
                hasError: showTransportGroupError,
              ),
            ),
            _col('Date', _dateBox()),
          ),
          if (_showDispatchForm) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.blue.shade50),
            const SizedBox(height: 10),
            _sectionSubTitle('Dispatch From (Consignor)', blue),
            const SizedBox(height: 8),
            _row2(
              _col(
                'Consignor Name',
                _textField(controller: consignorCtrl, hint: 'Name'),
              ),
              _col('Address 1', _textField(controller: consignorAdd1Ctrl)),
            ),
            _gap(),
            _row2(
              _col('Address 2', _textField(controller: consignorAdd2Ctrl)),
              _col('Place', _textField(controller: consignorPlaceCtrl)),
            ),
            _gap(),
            _row2(
              _col(
                'Pincode *',
                _textField(
                  controller: consignorPinCtrl,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                  hasError:
                      _showValidationErrors &&
                      consignorPinCtrl.text.trim().isEmpty,
                ),
              ),
              _col(
                'Dispatch State *',
                _dropdown<int>(
                  value: consignorStateId,
                  items:
                      stateData
                          .map(
                            (s) => {
                              'id': (s['id'] as num).toInt(),
                              'name':
                                  (s['StateName'] ?? s['Name'] ?? '')
                                      .toString(),
                            },
                          )
                          .toList(),
                  onChanged: (v) => setState(() => consignorStateId = v),
                  isRequired: true,
                  hasError: _showValidationErrors && consignorStateId == null,
                ),
              ),
            ),
          ],
          if (_showConsigneeForm) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.blue.shade50),
            const SizedBox(height: 10),
            _sectionSubTitle('Ship To (Consignee)', blue),
            const SizedBox(height: 8),
            _row2(
              _col(
                'Consignee Name',
                _textField(controller: consigneeCtrl, hint: 'Name'),
              ),
              _col('Address 1', _textField(controller: consigneeAdd1Ctrl)),
            ),
            _gap(),
            _row2(
              _col('Address 2', _textField(controller: consigneeAdd2Ctrl)),
              _col('Place', _textField(controller: consigneePlaceCtrl)),
            ),
            _gap(),
            _row2(
              _col(
                'Pincode *',
                _textField(
                  controller: consigneePinCtrl,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                  hasError:
                      _showValidationErrors &&
                      consigneePinCtrl.text.trim().isEmpty,
                ),
              ),
              _col(
                'Ship To GSTIN *',
                _textField(
                  controller: shipToGstCtrl,
                  isRequired: true,
                  hasError:
                      _showValidationErrors &&
                      shipToGstCtrl.text.trim().isEmpty,
                ),
              ),
            ),
            _gap(),
            _row2(
              _col(
                'Ship To State *',
                _dropdown<int>(
                  value: consigneeStateId,
                  items:
                      stateData
                          .map(
                            (s) => {
                              'id': (s['id'] as num).toInt(),
                              'name':
                                  (s['StateName'] ?? s['Name'] ?? '')
                                      .toString(),
                            },
                          )
                          .toList(),
                  onChanged: (v) => setState(() => consigneeStateId = v),
                  isRequired: true,
                  hasError: _showValidationErrors && consigneeStateId == null,
                ),
              ),
              const SizedBox(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionSubTitle(String t, Color blue) => Text(
    t,
    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: blue),
  );

  // ── Fixed 2-column row helper ───────────────────────────────────────
  Widget _row2(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _col(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_fieldLabel(label), const SizedBox(height: 5), field],
    );
  }

  Widget _gap() => const SizedBox(height: 10);

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1565C0),
    ),
  );

  Widget _greyBox(String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F4FA),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: const Color(0xFFD7E3F5)),
    ),
    child: Text(
      value.isEmpty ? '-' : value,
      style: const TextStyle(fontSize: 13, color: Color(0xFF3B4656)),
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _dateBox() => InkWell(
    onTap: _pickGrDate,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFB9CDE8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('dd/MM/yyyy').format(grDate),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
          ),
          const Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: Color(0xFF1565C0),
          ),
        ],
      ),
    ),
  );

  Widget _noteBanner(Color blue) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: blue.withOpacity(0.06),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: blue.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: blue),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'NOTE: If Road is the mode of transport, either Transport ID and Date, or Vehicle No, is mandatory.',
            style: TextStyle(
              fontSize: 11.5,
              color: blue.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Bottom action bar ────────────────────────────────────────────────
  Widget _buttonBar(Color blue) {
    final showDistanceButton = _gd.appSoftCode == 'MANDI';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.blue.shade50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  'Save',
                  const Color(0xFF16A34A),
                  Icons.check,
                  _save,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton('Reset', blue, Icons.refresh, () {
                  setState(() {
                    subType = null;
                    billType = null;
                    transTypeId = null;
                    supplyType = null;
                    _showValidationErrors = false;
                  });
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  'Cancel',
                  const Color(0xFFDC2626),
                  Icons.close,
                  () => Navigator.pop(context, false),
                ),
              ),
            ],
          ),
          if (showDistanceButton) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _actionButton(
                'Check Distance With PinCodes',
                const Color(0xFF0D3B66),
                Icons.open_in_new,
                _openDistanceCheckerPortal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 0,
      ),
    );
  }

  // ── Text field with required-error border support ────────────────────
  Widget _textField({
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
    bool isRequired = false,
    bool hasError = false,
  }) {
    final borderColor =
        hasError ? const Color(0xFFDC2626) : const Color(0xFFB9CDE8);
    final borderWidth = hasError ? 1.6 : 1.0;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
        isDense: true,
        filled: true,
        fillColor: hasError ? const Color(0xFFFEF2F2) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: borderColor, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: borderColor, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFDC2626) : const Color(0xFF1565C0),
            width: 1.6,
          ),
        ),
      ),
    );
  }

  // ── Dropdown with required-error border support ───────────────────────
  Widget _dropdown<T>({
    required T? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<T?> onChanged,
    bool isRequired = false,
    bool hasError = false,
  }) {
    final borderColor =
        hasError ? const Color(0xFFDC2626) : const Color(0xFFB9CDE8);
    final borderWidth = hasError ? 1.6 : 1.0;
    return DropdownButtonFormField<T>(
      value: items.any((e) => e['id'] == value) ? value : null,
      isExpanded: true,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: hasError ? const Color(0xFFFEF2F2) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: borderColor, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: borderColor, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFDC2626) : const Color(0xFF1565C0),
            width: 1.6,
          ),
        ),
      ),
      items:
          items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e['id'] as T,
                  child: Text(
                    e['name'].toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
      onChanged: onChanged,
    );
  }
}
