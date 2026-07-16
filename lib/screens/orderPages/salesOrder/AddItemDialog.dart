import 'package:flutter/material.dart';
import 'package:saafhisaab/services/general_service.dart';
import 'package:saafhisaab/services/system_params_service.dart';
import 'package:saafhisaab/services/app_cache.dart';
import 'package:saafhisaab/widgets/app_loader.dart';
import 'package:saafhisaab/services/global_data.dart';
import 'package:saafhisaab/screens/orderPages/salesOrder/createSalesOrderModel.dart';
import 'package:saafhisaab/screens/orderPages/salesOrder/Calculationdetaildialog.dart';
// import 'package:saafhisaab/screens/orderPages/widgets/GodownSearchScreen.dart';
import 'package:saafhisaab/screens/orderPages/widgets/ItemSearchDialog.dart';

enum AddItemAction { save, saveAndNew }

class AddItemResult {
  final OrderItem item;
  final AddItemAction action;
  AddItemResult(this.item, this.action);
}

// ─────────────────────────────────────────────────────────────────────────────
// Stock2 row model — mirrors Angular Stock2Dtl interface
// ─────────────────────────────────────────────────────────────────────────────
class Stock2Row {
  double stBag;
  double wtPerBag;
  double stQty;

  Stock2Row({
    required this.stBag,
    required this.wtPerBag,
    required this.stQty,
  });
}

class AddItemDialog extends StatefulWidget {
  final String partyName;
  final int partyId;
  final OrderItem? editItem;
  final String orderType;

  final bool canAdd;
  final bool canEdit;

  /// Pass broker id so CalculationDetailDialog can pre-fill brokerage rate
  final int? brokerId;

  /// Whether the party is interstate — affects CGST/SGST vs IGST
  final bool isInterStateParty;

  /// Invoice / order effective date (dd/MM/yyyy) for calc-method fetch
  final String effDate;

  /// Mirrors Angular SIHdrSysparamData[0].DefaultGodownId — auto-selected
  /// for the first item row (when no previous item exists).
  final int? defaultGodownId;

  /// Mirrors Angular sticky-godown logic: last item's GodownId is carried
  /// forward as the default for the next row.
  final int? previousGodownId;

  /// Mirrors Angular MT_ItemWiseSeperateMethod sysparam — affects method lookup.
  final bool mtItemWiseSeparateMethod;  

  const AddItemDialog({
    super.key,
    required this.partyName,
    required this.partyId,
    required this.orderType,
    this.editItem,
    this.canAdd = true,
    this.canEdit = false,
    this.brokerId,
    this.isInterStateParty = false,
    this.effDate = '',
    this.defaultGodownId,
    this.previousGodownId,
    this.mtItemWiseSeparateMethod = false,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final GlobalData _global = GlobalData();
  final _sysParamService = SysparamService();

  bool get _readOnly => !widget.canEdit;

  // Data lists
  List<Map<String, dynamic>> itemGroups = [];
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> brands = [];

  // Selected values
  int? selectedItemGroupId;
  String? selectedItemGroupName;
  int? selectedItemId;
  String? selectedItemName;
  Map<String, dynamic>? selectedItemData;
  int? selectedBrandId;
  String? selectedBrandName;

  // Controllers
  final bagController = TextEditingController();
  final qtyController = TextEditingController();
  final rateController = TextEditingController();
  final tpRateController = TextEditingController();
  final brokerageController = TextEditingController();
  final remarkController = TextEditingController();
  final itemDescController = TextEditingController();
  final weightController = TextEditingController();
  final amountController = TextEditingController();
  final minRateController = TextEditingController();
  final discPriceController = TextEditingController();
  final noOfPcsController = TextEditingController();
  final pcsRateController = TextEditingController();
  final lotNoController = TextEditingController();
  final bardanaWeightController = TextEditingController();

  // Item metadata
  String calUnit = 'Bag';
  String valUnit = 'Qty';
  String rateUnit = 'Unit';
  double cWeight = 0;
  double cvFactor = 0;
  double rWeight = 0;
  double minRate = 0;
  double discPrice = 0;
  double baseRate = 1;
  // ── Angular BardanaStdWeight — subtracted from gross to get net qty ─────
  double bardanaStdWeight = 0;

  double taxRate = 0;
  bool _isFetchingTax = false;

  // Tax item data — needed for CalculationDetailDialog
  Map<String, dynamic>? _taxItemData;
  int _methodId = 0;
  int _taxId = 0;

  // Existing SIDtl from edit mode (pre-populate overhead dialog)
  List<Map<String, dynamic>> _existingSiDtl = [];

  // ── SIN-only fields (Method, HSN, Godown) ─────────────────────────────
  List<Map<String, dynamic>> _methodList = [];
  int? _selectedMethodId;
  String? _selectedMethodName;

  String _hsnCode = '';

  List<Map<String, dynamic>> _godownList = [];
  int? _selectedGodownId;
  String? _selectedGodownName;

  bool get _isSalesInvoice => widget.orderType == 'SIN';
  bool get _isSalesOrder => widget.orderType == 'SALES';
  String get _invoiceIrSr => (_isSalesInvoice || _isSalesOrder) ? 'SIN' : 'PIN';
  int get _effectiveMethodId =>
      (_isSalesInvoice ? _selectedMethodId : null) ?? _methodId;

  // Flags
  bool readSaleTaxPaidRate = false;
  bool siDescToPrint = false;
  bool isCalcUnitNone = false;
  bool useSingleUnitOrder = false;
  bool readGrossWeightInSale = false; 
  bool readGrossWeightInPurchase = false;

  // ── Stock2 (bag-wise weight) state ─────────────────────────────────────
  // Mirrors Angular: St2ModalVisible, StockDtl2Data, TotalST2Bag, TotalST2Qty
  bool _st2ModalVisible = false;        // ReadBagwiseWeightInSales/Purchase
  List<Stock2Row> _stock2Rows = [];     // StockDtl2Data
  double _totalSt2Bag = 0;             // TotalST2Bag
  double _totalSt2Qty = 0;             // TotalST2Qty
  bool _bagQtyLockedByStock2 = false;  // whether bag/qty inputs are disabled

  bool isLoading = true;
  String? errorMessage;
  bool _isCalculating = false;

  final FocusNode _itemFocusNode = FocusNode();

  bool get _isPurchaseType =>
    widget.orderType == 'PIN' || widget.orderType.toUpperCase().contains('PURCH');

  /// Mirrors Angular: (ReadGrossWeightInSale && IRSr is SIN/SRC/SRD) ||
  ///                   (ReadGrossWeightInPurchase && IRSr is PIN/PTD/PTC)
  bool get _showGrossWeightRow =>
      (readGrossWeightInSale && !_isPurchaseType) ||
      (readGrossWeightInPurchase && _isPurchaseType);

  @override
  void initState() {
    super.initState();

    final sysParams = _sysParamService.cachedData?.sysparam;
    if (sysParams != null) {
      useSingleUnitOrder = sysParams.sysparamCommon.useSingleUnitOrder;
    }

    if (widget.editItem != null) _prefillEditData();

    bagController.addListener(_calculateWeight);
    qtyController.addListener(_onQtyChanged);
    rateController.addListener(_calculateAmount);
    tpRateController.addListener(_onTpRateChanged);
    bardanaWeightController.addListener(_onBardanaWeightChanged);
    weightController.addListener(_onGrossWeightChanged);
    

    _loadInitialData();

    _itemFocusNode.addListener(() => setState(() {}));

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _itemFocusNode.requestFocus();
    });
  }

  void _prefillEditData() {
    final item = widget.editItem!;

    selectedItemId = item.itemId;
    selectedItemName = item.itemName;
    selectedItemGroupId = item.itemGroupId;
    selectedItemGroupName = item.itemGroupName;
    selectedBrandId = item.brandId != 0 ? item.brandId : null;
    selectedBrandName = item.brandName.isNotEmpty ? item.brandName : null;

    calUnit = item.calUnit;
    valUnit = item.valUnit;
    rateUnit = item.rateUnit;

    bagController.text = item.bag.toString();
    qtyController.text = item.qty.toString();
    rateController.text = item.rate.toString();
    tpRateController.text = item.tpRate.toString();
    brokerageController.text = item.brokerageRate.toString();
    weightController.text = item.weight.toString();
    bardanaWeightController.text = item.bardanaWeight.toString();   // ← needs OrderItem.bardanaWeight
    amountController.text = item.amount.toString();
    minRateController.text = item.minRate.toString();
    discPriceController.text = item.discPrice.toString();
    noOfPcsController.text = item.noOfPcs.toString();
    pcsRateController.text = item.pcsRate.toString();
    remarkController.text = item.remark;
    itemDescController.text = item.itemDesc;
    lotNoController.text = item.gdSlipNo;

    // Carry existing SIDtl so the overhead dialog starts pre-populated
    _existingSiDtl =
        item.siDtl.map((e) => Map<String, dynamic>.from(e)).toList();

    // Prefill Stock2 rows from existing item (edit mode)
    if (item.stock2Rows.isNotEmpty) {
      _stock2Rows = item.stock2Rows
          .map((r) => Stock2Row(
                stBag: (r['STBag'] as num?)?.toDouble() ?? 0,
                wtPerBag: (r['WtPerBag'] as num?)?.toDouble() ?? 0,
                stQty: (r['STQty'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
      _recalcStock2Totals();
      // If stock2 rows exist, bag/qty are locked — mirrors Angular
      _bagQtyLockedByStock2 = true;
    }

    if (selectedItemId != null) _loadBrands();

    // Prefill SIN-only fields from existing item
    if (_isSalesInvoice) {
      _selectedMethodId = widget.editItem!.methodId != 0
          ? widget.editItem!.methodId
          : null;

      _selectedGodownId =
          widget.editItem!.godownId != 0 ? widget.editItem!.godownId : null;
      _selectedGodownName = widget.editItem!.godownName.isNotEmpty
          ? widget.editItem!.godownName
          : null;

      _hsnCode = widget.editItem!.taxCode.isNotEmpty
          ? widget.editItem!.taxCode
          : '';
    }
  }

  @override
  void dispose() {
    bagController.removeListener(_calculateWeight);
    qtyController.removeListener(_onQtyChanged);
    rateController.removeListener(_calculateAmount);
    tpRateController.removeListener(_onTpRateChanged);
    bardanaWeightController.removeListener(_onBardanaWeightChanged);
    weightController.removeListener(_onGrossWeightChanged);

    bagController.dispose();
    qtyController.dispose();
    rateController.dispose();
    tpRateController.dispose();
    brokerageController.dispose();
    remarkController.dispose();
    itemDescController.dispose();
    weightController.dispose();
    amountController.dispose();
    minRateController.dispose();
    discPriceController.dispose();
    noOfPcsController.dispose();
    pcsRateController.dispose();
    lotNoController.dispose();
    _itemFocusNode.dispose();
    bardanaWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final futures = <Future>[_loadItemGroups(), _loadItems()];
      if (_isSalesInvoice) {
        futures.add(_loadMethodList());
        futures.add(_loadGodownList());
      }
      await Future.wait(futures);

      if (!mounted) return;

      if (widget.editItem != null && selectedItemId != null) {
        await _loadItemMetadataForEdit();
      }

      setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  Future<void> _loadItemMetadataForEdit() async {
    try {
      final item = AllItemData.firstWhere(
        (i) => (i['id'] ?? i['ItemId']) == selectedItemId,
        orElse: () => {},
      );

      if (item.isNotEmpty) {
        cWeight = (item['CWeight'] ?? 0).toDouble();
        cvFactor = (item['CVFactor'] ?? 0).toDouble();
        rWeight = (item['RWeight'] ?? 0).toDouble();
        minRate = (item['SalesOrderMinRate'] ?? 0).toDouble();
        baseRate = (item['BaseRate'] ?? 1).toDouble();
        bardanaStdWeight = (item['BardanaStdWeight'] ?? 0).toDouble();
        readSaleTaxPaidRate = item['ReadSalesTaxPaidRate'] ?? false;
        siDescToPrint = item['SIDescToPrint'] ?? false;
        isCalcUnitNone = calUnit == 'NONE';
        _methodId = (item['MethodId'] ?? item['CalcMethodId'] ?? 0) as int;
        readGrossWeightInSale = item['ReadGrossWeightInSale'] ?? false;
        readGrossWeightInPurchase = item['ReadGrossWeightInPurchase'] ?? false;
        selectedItemData = item;

        // Resolve St2ModalVisible flag for edit mode
        final bool readBagwise = _isSalesInvoice
            ? (item['ReadBagwiseWeightInSales'] ?? false)
            : (item['ReadBagwiseWeightInPurchase'] ?? false);
        _st2ModalVisible = readBagwise;

        if (_isSalesInvoice) {
          final hsn = (item['SalesTax'] ?? item['HSNcode'] ?? '').toString();
          if (hsn.isNotEmpty) _hsnCode = hsn;
        }
        await _calculateTaxRate(item);
      }
    } catch (e) {
      debugPrint('Error loading item metadata: $e');
    }
  }

  Future<void> _loadItemGroups() async {
    try {
      if (AppCache.userItemGroups != null &&
          AppCache.userItemGroups!.isNotEmpty) {
        itemGroups = AppCache.userItemGroups!;
        return;
      }
      final data = await GeneralService.getItemGroups(
        clientRegId: _global.clientRegId ?? 0,
        coSoftId: _global.coSoftId ?? 0,
        coFinyear: _global.CofinYear ?? 0,
        userId: _global.mobileAppUserId ?? 0,
        commonSalesOrder: _global.CommonSalesOrder ?? false,
      );
      if (data.isNotEmpty) {
        AppCache.userItemGroups = data;
        itemGroups = data;
      }
    } catch (_) {
      itemGroups = [];
    }
  }

  List<Map<String, dynamic>> AllItemData = [];

  Future<void> _loadItems() async {
    try {
      if (AppCache.hasItems(widget.orderType)) {
        final data = AppCache.getItems(widget.orderType);
        if (!mounted) return;
        setState(() {
          items = data;
          AllItemData = data;
        });
        return;
      }

      final data = await GeneralService.getAllItems(
        clientRegId: _global.clientRegId ?? 0,
        coSoftId: _global.coSoftId ?? 0,
        coFinyear: _global.CofinYear ?? 0,
        userId: _global.mobileAppUserId ?? 0,
        divId: _global.divId ?? 0,
        ptAccountId:
            (widget.orderType == 'SALES' || widget.orderType == 'SIN')
                ? widget.partyId
                : 0,
        itemGroupId: selectedItemGroupId ?? 0,
        userWise: true,
        forSalesOrder: true,
        commonSalesOrder: _global.CommonSalesOrder ?? false,
        SPflag:
            (widget.orderType == 'SALES' || widget.orderType == 'SIN')
                ? 'SALE'
                : 'PURCHASE',
      );

      AppCache.setItems(widget.orderType, data);
      if (!mounted) return;
      setState(() {
        items = data;
        AllItemData = data;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        items = [];
        AllItemData = [];
      });
    }
  }

  Future<void> _openItemGroupSearch() async {
    if (_readOnly || widget.editItem != null) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemGroupSearchScreen(groups: itemGroups),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        selectedItemGroupId = result['id'];
        selectedItemGroupName = result['name'];
        selectedItemId = null;
        selectedItemName = null;
        selectedItemData = null;
        isLoading = true;
      });
      await _loadItems();
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _openItemSearch() async {
    if (_readOnly || widget.editItem != null) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items available')));
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ItemSearchScreen(items: items)),
    );

    if (result != null && mounted) _onItemSelected(result);
  }

  Future<void> _loadMethodList() async {
    try {
      final data = await GeneralService.getAllMastById_AcMast('METHOD');
      if (mounted) {
        setState(() => _methodList = data);

        if (_selectedMethodId != null && _selectedMethodName == null) {
          final match = _methodList.firstWhere(
            (m) => (m['id'] as num?)?.toInt() == _selectedMethodId,
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            setState(() {
              _selectedMethodName =
                  (match['Name'] ?? match['AcName'] ?? '').toString();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('_loadMethodList error: $e');
    }
  }

  Future<void> _loadGodownList() async {
    try {
      final data = await GeneralService.getAllGodowns(
        StrCond: '',
        AcGroupId: 66,
        FormFlag: 'SIN',
      );
      if (mounted) {
        setState(() => _godownList = data);

        if (widget.editItem != null) {
          if (_selectedGodownId != null && _selectedGodownName == null) {
            final match = _godownList.firstWhere(
              (g) => (g['id'] as num?)?.toInt() == _selectedGodownId,
              orElse: () => {},
            );
            if (match.isNotEmpty) {
              setState(() {
                _selectedGodownName =
                    (match['AcName'] ?? match['Name'] ?? '').toString();
              });
            }
          }
        } else {
          final int? resolvedId =
              widget.previousGodownId != null && widget.previousGodownId != 0
                  ? widget.previousGodownId
                  : widget.defaultGodownId;

          if (resolvedId != null && resolvedId != 0) {
            final match = _godownList.firstWhere(
              (g) => (g['id'] as num?)?.toInt() == resolvedId,
              orElse: () => {},
            );
            if (match.isNotEmpty) {
              setState(() {
                _selectedGodownId = resolvedId;
                _selectedGodownName =
                    (match['AcName'] ?? match['Name'] ?? '').toString();
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('_loadGodownList error: $e');
    }
  }

  Future<void> _loadBrands() async {
    if (selectedItemId == null) return;
    final data = await GeneralService.getItemWiseBrands(
      clientRegId: _global.clientRegId ?? 0,
      coSoftId: _global.coSoftId ?? 0,
      itemId: selectedItemId!,
      commonSalesOrder: _global.CommonSalesOrder ?? false,
    );
    if (mounted) setState(() => brands = data);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Item selection — mirrors Angular getCalValUnit() + St2ModalVisible check
  // ─────────────────────────────────────────────────────────────────────────
  void _onItemSelected(Map<String, dynamic> item) {
    taxRate = 0;
    _taxItemData = null;
    _taxId = 0;
    _methodId = (item['MethodId'] ?? item['CalcMethodId'] ?? 0) as int;
    _existingSiDtl = [];

    // ── Reset Stock2 state for fresh item selection ────────────────────
    _stock2Rows = [];
    _totalSt2Bag = 0;
    _totalSt2Qty = 0;
    _bagQtyLockedByStock2 = false;

    // Determine if this item uses bag-wise weight modal
    // Mirrors Angular: item.ReadBagwiseWeightInSales / ReadBagwiseWeightInPurchase
    final bool readBagwise = _isSalesInvoice
        ? (item['ReadBagwiseWeightInSales'] ?? false)
        : (item['ReadBagwiseWeightInPurchase'] ?? false);

    setState(() {
      bagController.clear();
      qtyController.clear();
      rateController.text = '0';
      tpRateController.text = '0';
      weightController.clear();
      bardanaWeightController.clear();
      amountController.clear();
      minRateController.clear();
      discPriceController.clear();
      noOfPcsController.clear();
      pcsRateController.clear();
      remarkController.clear();
      itemDescController.clear();
      lotNoController.clear();

      selectedBrandId = null;
      selectedBrandName = null;

      selectedItemId = item['id'] ?? item['ItemId'];
      selectedItemName = item['Name'];
      selectedItemData = item;

      calUnit = item['CalUnit'] ?? 'Bag';
      valUnit = item['ValUnit'] ?? 'Qty';
      rateUnit = item['SOrdUnitName'] ?? item['RUnitName'] ?? 'Unit';
      cWeight = (item['CWeight'] ?? 0).toDouble();
      cvFactor = (item['CVFactor'] ?? 0).toDouble();
      rWeight = (item['RWeight'] ?? 0).toDouble();
      minRate = (item['SalesOrderMinRate'] ?? 0).toDouble();
      baseRate = (item['BaseRate'] ?? 1).toDouble();
      bardanaStdWeight = (item['BardanaStdWeight'] ?? 0).toDouble();
      readSaleTaxPaidRate = item['ReadSalesTaxPaidRate'] ?? false;
      siDescToPrint = item['SIDescToPrint'] ?? false;
      isCalcUnitNone = calUnit == 'NONE';
      readGrossWeightInSale = item['ReadGrossWeightInSale'] ?? false;
      readGrossWeightInPurchase = item['ReadGrossWeightInPurchase'] ?? false;
      _st2ModalVisible = readBagwise;

      brokerageController.text = (item['BrokrageRate'] ?? 0).toString();
      minRateController.text = minRate.toString();

      if (_isSalesInvoice) {
        _hsnCode = (item['SalesTax'] ?? item['HSNcode'] ?? '').toString();
        _selectedMethodId = null;
        _selectedMethodName = null;
      }

      if (readSaleTaxPaidRate) {
        tpRateController.text = (item['SalesOrderRate'] ?? 0).toString();
      }

      if (isCalcUnitNone) bagController.clear();
      _loadBrands();
    });

    _calculateTaxRate(item).then((_) {
      if (!mounted) return;
      if (readSaleTaxPaidRate) {
        _onTpRateChanged();
      }
      // ── Open Stock2 modal after tax fetch, mirrors Angular OpenStock2DtlModal()
      // called from getCalValUnit when e != '' (new item, not edit prefill)
      if (readBagwise && mounted) {
        _openStock2DtlModal();
      }
    });

    if (_isSalesInvoice) {
      _fetchDefaultMethodId(item['id'] ?? item['ItemId']);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stock2 helpers — mirrors Angular Stock2DtlModal logic
  // ─────────────────────────────────────────────────────────────────────────

  /// Recalculates TotalST2Bag and TotalST2Qty from _stock2Rows.
  /// Mirrors Angular getSt2DtlTotal()
  void _recalcStock2Totals() {
    _totalSt2Bag = _stock2Rows.fold(0.0, (sum, r) => sum + r.stBag);
    _totalSt2Qty = _stock2Rows.fold(0.0, (sum, r) => sum + r.stQty);
  }

  /// Opens the bag-wise weight bottom sheet.
  /// Mirrors Angular OpenStock2DtlModal() + CloseStock2DtlModal() combined.
  Future<void> _openStock2DtlModal() async {
    // Pass a copy so the sheet can mutate internally without affecting state
    final result = await showModalBottomSheet<List<Stock2Row>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Stock2DtlSheet(
        calUnit: calUnit,
        valUnit: valUnit,
        cWeight: cWeight,
        initialRows: List.from(_stock2Rows),
      ),
    );

    if (!mounted) return;

    // null means user dismissed without saving — keep existing rows
    if (result == null) return;

    setState(() {
      _stock2Rows = result;
      _recalcStock2Totals();

      if (_stock2Rows.isNotEmpty) {
        // ── Mirror Angular CloseStock2DtlModal() ───────────────────────
        // ItBag = TotalST2Bag
        _bagQtyLockedByStock2 = true;
        bagController.text = _totalSt2Bag.toStringAsFixed(3);
        // GrossWeight = TotalST2Qty
        final double grossWeight = _totalSt2Qty;
        weightController.text = grossWeight.toStringAsFixed(3);
        // CalcWeightByGross: NetQty = GrossWeight - BardanaWeight
        _applyGrossToNetQty(grossWeight);
        // Disable bag & qty — mirrors DetailForm.get('ItBag').disable() etc.
        _bagQtyLockedByStock2 = true;
      } else {
        // No rows — re-enable inputs
        _bagQtyLockedByStock2 = false;
      }
    });

    // Recalc amount after qty is updated
    _calculateAmount();
  }

  /// Mirrors Angular CalcWeightByGross():
  ///   BardanaWeight = bag × BardanaStdWeight   (or form value if stdWeight==0)
  ///   NetQty = GrossWeight - BardanaWeight
  void _applyGrossToNetQty(double grossWeight) {
    final double bag = double.tryParse(bagController.text) ?? 0;
    double bardanaWeight;
    if (bardanaStdWeight == 0) {
      bardanaWeight = double.tryParse(bardanaWeightController.text) ?? 0;   // keep typed value
    } else {
      bardanaWeight = bag * bardanaStdWeight;                              // recompute from std weight
      bardanaWeightController.text = bardanaWeight.toStringAsFixed(3);      // write it back
    }
    final double netQty = grossWeight - bardanaWeight;
    qtyController.text = netQty.toStringAsFixed(3);
  }
  /// Mirrors Angular GrossWeight field's own (keyup)="CalcWeightByGross($event);CalcItemDetailAmount($event)"
  void _onGrossWeightChanged() {
    if (_isCalculating || _bagQtyLockedByStock2) return;
    _isCalculating = true;
    try {
      final grossWeight = double.tryParse(weightController.text) ?? 0;
      _applyGrossToNetQty(grossWeight);
    } finally {
      _isCalculating = false;
    }
    _calculateAmount();
  }

  /// Mirrors Angular BardanaWeight field's own keyup handler.
  /// Only meaningful when BardanaStdWeight == 0 (otherwise the field is
  /// auto-derived and read-only, same as Angular's implicit behavior).
  void _onBardanaWeightChanged() {
    if (_isCalculating) return;
    _isCalculating = true;
    try {
      final grossWeight = double.tryParse(weightController.text) ?? 0;
      _applyGrossToNetQty(grossWeight);
    } finally {
      _isCalculating = false;
    }
    _calculateAmount();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Calculations
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchDefaultMethodId(int itemId) async {
    try {
      final int lookupItemId =
          widget.mtItemWiseSeparateMethod ? itemId : 0;

      final int methodId = await GeneralService.getCalculationMethodIdByItemId(
        clientRegId: _global.clientRegId ?? 0,
        coSoftId: _global.coSoftId ?? 0,
        commonSalesOrder: _global.CommonSalesOrder ?? false,
        ptAccountId: widget.partyId,
        stsr: 'SIN',
        itemId: lookupItemId,
        effDate: widget.effDate,
      );

      if (methodId > 0 && mounted) {
        final match = _methodList.firstWhere(
          (m) => (m['id'] as num?)?.toInt() == methodId,
          orElse: () => {},
        );
        setState(() {
          _selectedMethodId = methodId;
          _selectedMethodName = match.isNotEmpty
              ? (match['Name'] ?? match['AcName'] ?? '').toString()
              : null;
          _methodId = methodId;
        });
      }
    } catch (e) {
      debugPrint('_fetchDefaultMethodId error: $e');
    }
  }

  Future<void> _calculateTaxRate(Map<String, dynamic> item) async {
    if (_isFetchingTax) return;
    _isFetchingTax = true;
    try {
      final int taxId =
          (widget.orderType == 'SALES' || widget.orderType == 'SIN')
              ? (int.tryParse((item['STaxId'] ?? item['ITaxId'] ?? 0).toString()) ?? 0)
              : (int.tryParse((item['PTaxId'] ?? item['ITaxId'] ?? 0).toString()) ?? 0);

      _taxId = taxId;

      if (taxId == 0) {
        taxRate = 0;
        _taxItemData = null;
        return;
      }

      final taxData = await GeneralService.getTaxTypeById(
        taxId: taxId,
        clientRegId: _global.clientRegId ?? 0,
      );

      if (taxData != null) {
        final double cgst = (taxData['TXCgstRate'] as num?)?.toDouble() ?? 0;
        final double sgst = (taxData['TXSgstRate'] as num?)?.toDouble() ?? 0;
        final double igst = (taxData['TXIgstRate'] as num?)?.toDouble() ?? 0;
        taxRate = widget.isInterStateParty ? igst : (cgst + sgst);
        _taxItemData = taxData;
      } else {
        taxRate = 0;
        _taxItemData = null;
      }
    } catch (e) {
      debugPrint('_calculateTaxRate error: $e');
      taxRate = 0;
      _taxItemData = null;
    } finally {
      _isFetchingTax = false;
    }
  }

  void _calculateWeight() {
    if (_isCalculating || _bagQtyLockedByStock2) return;
    _isCalculating = true;
    try {
      final bag = double.tryParse(bagController.text) ?? 0;

      // Mirrors Angular CalcItemDetailQty(): Qty = Bag × CWeight, and this
      // becomes the new baseline GrossWeight before Bardana is subtracted.
      double grossWeight;
      if (!useSingleUnitOrder && bag > 0 && cWeight > 0) {
        grossWeight = bag * cWeight;
      } else {
        grossWeight = double.tryParse(weightController.text) ??
            (double.tryParse(qtyController.text) ?? 0);
      }
      weightController.removeListener(_onGrossWeightChanged);
      weightController.text = grossWeight.toStringAsFixed(3);
      weightController.addListener(_onGrossWeightChanged);

      // Mirrors Angular CalcWeightByGross() called right after.
      _applyGrossToNetQty(grossWeight);
    } finally {
      _isCalculating = false;
    }
    _calculateAmount();
  }

  void _onQtyChanged() {
    if (_isCalculating || _bagQtyLockedByStock2) return;
    _isCalculating = true;
    try {
      // Only mirror Qty into the generic Weight field when the Gross/Bardana
      // Weight feature is off — matches Angular, where ItQty's own keyup
      // never touches GrossWeight when ReadGrossWeightInSale/Purchase is set.
      if (!_showGrossWeightRow) {
        final qty = double.tryParse(qtyController.text) ?? 0;
        weightController.text = qty.toStringAsFixed(3);
      }
    } finally {
      _isCalculating = false;
    }
    _calculateAmount();
  }


  void _onTpRateChanged() {
    if (_isCalculating) return;
    if (!readSaleTaxPaidRate) return;
    _isCalculating = true;
    try {
      final tpRate = double.tryParse(tpRateController.text) ?? 0;
      if (tpRate > 0) {
        final rate = (tpRate / (100 + taxRate)) * 100;
        rateController.removeListener(_calculateAmount);
        rateController.text = rate.toStringAsFixed(4);
        rateController.addListener(_calculateAmount);
      }
    } finally {
      _isCalculating = false;
    }
    _calculateAmount();
  }

  void _calculateAmount() {
    if (_isCalculating) return;
    _isCalculating = true;
    try {
      final bag = double.tryParse(bagController.text) ?? 0;
      final qty = double.tryParse(qtyController.text) ?? 0;
      final rate = double.tryParse(rateController.text) ?? 0;
      final tpRate = double.tryParse(tpRateController.text) ?? 0;

      if (_global.clientRegId == 672 || _global.clientRegId == 68497) {
        if (!readSaleTaxPaidRate) {
          final pcsRate =
              (rate * ((rateUnit == calUnit) ? 1 : rWeight)) / baseRate;
          final noOfPcs =
              (double.tryParse(weightController.text) ?? 0) /
              (rWeight == 0 ? 1 : rWeight);
          final amount = noOfPcs.floor() * pcsRate;
          pcsRateController.text = pcsRate.toStringAsFixed(4);
          noOfPcsController.text = noOfPcs.floor().toString();
          amountController.text = amount.toStringAsFixed(2);
        } else {
          final rateWithoutTax = (tpRate / (100 + taxRate)) * 100;
          rateController.removeListener(_calculateAmount);
          rateController.text = rateWithoutTax.toStringAsFixed(4);
          rateController.addListener(_calculateAmount);
          final pcsRate =
              (tpRate * ((rateUnit == calUnit) ? 1 : rWeight)) / baseRate;
          final noOfPcs =
              (double.tryParse(weightController.text) ?? 0) /
              (rWeight == 0 ? 1 : rWeight);
          final amount = noOfPcs.floor() * pcsRate;
          pcsRateController.text = pcsRate.toStringAsFixed(4);
          noOfPcsController.text = noOfPcs.floor().toString();
          amountController.text = amount.toStringAsFixed(2);
        }
      } else {
        if (readSaleTaxPaidRate) {
          final rateWithoutTax = (tpRate / (100 + taxRate)) * 100;
          rateController.removeListener(_calculateAmount);
          rateController.text = rateWithoutTax.toStringAsFixed(4);
          rateController.addListener(_calculateAmount);
        }
        final effectiveRate = double.tryParse(rateController.text) ?? rate;
        final amount = _calcAmountForRate(
          bag.toInt(),
          qty,
          effectiveRate,
          selectedItemData?['CUnitId'] ?? 0,
          selectedItemData?['VUnitId'] ?? 0,
          selectedItemData?['RUnitId'] ?? 0,
          rWeight,
        );
        amountController.text = amount.toStringAsFixed(2);
      }
    } finally {
      _isCalculating = false;
    }
  }

  double _calcAmountForRate(
    int bag,
    double qty,
    double rate,
    int cUnitId,
    int vUnitId,
    int rUnitId,
    double rWeight,
  ) {
    double amount = 0;
    if (cUnitId == rUnitId) {
      amount = bag * rate;
    } else if (vUnitId == rUnitId) {
      amount = qty * rate;
    } else {
      if (rWeight == 0) rWeight = 1;
      amount = (qty * rate) / rWeight;
    }
    return double.parse(amount.toStringAsFixed(2));
  }

  bool _validate() {
    if (selectedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PLEASE SELECT AN ITEM')));
      return false;
    }
    return true;
  }

  Future<void> _save(AddItemAction action) async {
    if (!_validate()) return;

    if (weightController.text.isEmpty) {
      final bag = double.tryParse(bagController.text) ?? 0;
      final qty = double.tryParse(qtyController.text) ?? 0;
      final weight = bag > 0 ? (bag * cWeight) : qty;
      weightController.text = weight.toStringAsFixed(3);
    }

    final cBag = (double.tryParse(bagController.text) ?? 0);
    final cQty = double.tryParse(qtyController.text) ?? 0;
    final cRate = double.tryParse(rateController.text) ?? 0;
    final cAmount = double.tryParse(amountController.text) ?? 0;

    CalculationDetailResult? calcResult;

    if (!_readOnly && !_isSalesOrder) {
      final double discAmt = double.tryParse(discPriceController.text) ?? 0;
      final double amountAfterDisc = cAmount - discAmt;

      calcResult = await Navigator.push<CalculationDetailResult>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CalculationDetailDialog(
            cBag: cBag,
            cQty: cQty,
            cRate: cRate,
            cAmount: amountAfterDisc,
            existingSIDtl:
                _existingSiDtl.isNotEmpty ? _existingSiDtl : null,
            itemId: selectedItemId!,
            methodId: _effectiveMethodId,
            orderType: widget.orderType,
            irSr: _invoiceIrSr,
            brokerId: widget.brokerId,
            ptAccountId: widget.partyId,
            isInterStateParty: widget.isInterStateParty,
            taxItemData: _taxItemData,
            updateEditAmt: widget.editItem != null,
            effDate: widget.effDate,
          ),
        ),
      );
    }

    // Serialize Stock2 rows for model storage
    final List<Map<String, dynamic>> stock2Serialized = _stock2Rows
        .map((r) => {
              'STBag': r.stBag,
              'WtPerBag': r.wtPerBag,
              'STQty': r.stQty,
            })
        .toList();

    final item = OrderItem(
      itemId: selectedItemId!,
      itemName: selectedItemName ?? 'Unknown',
      bag: (double.tryParse(bagController.text) ?? 0).toInt(),
      qty: cQty,
      rate: cRate,
      tpRate: double.tryParse(tpRateController.text) ?? 0,
      amount: cAmount,
      weight: double.tryParse(weightController.text) ?? 0,
      bardanaWeight: double.tryParse(bardanaWeightController.text) ?? 0,
      brandId: selectedBrandId ?? 0,
      brandName: selectedBrandName ?? '',
      godownId: (_isSalesInvoice ? _selectedGodownId : null) ?? 0,
      godownName: (_isSalesInvoice ? _selectedGodownName : null) ?? '',
      gdSlipNo: lotNoController.text,
      brokerageRate: 0,
      minRate: double.tryParse(minRateController.text) ?? 0,
      discPrice: double.tryParse(discPriceController.text) ?? 0,
      noOfPcs: int.tryParse(noOfPcsController.text) ?? 0,
      pcsRate: double.tryParse(pcsRateController.text) ?? 0,
      remark: remarkController.text,
      itemDesc: itemDescController.text,
      calUnit: calUnit,
      valUnit: valUnit,
      rateUnit: rateUnit,
      itemGroupId: selectedItemGroupId ?? 0,
      itemGroupName: selectedItemGroupName ?? '',
      siDtl: _enrichSiDtl(
        calcResult?.sidtl ?? _existingSiDtl,
        irSr: _invoiceIrSr,
        coSoftId: _global.coSoftId ?? 0,
      ),
      totalOverHead: calcResult?.totalOverHead ?? _existingTotalOverhead,
      cgstAmt: calcResult?.cgstAmt ?? _existingCgst,
      sgstAmt: calcResult?.sgstAmt ?? _existingSgst,
      igstAmt: calcResult?.igstAmt ?? _existingIgst,
      gstCessAmt: calcResult?.gstCessAmt ?? _existingGstCess,
      taxOnAmt: calcResult?.taxOnAmt ?? _existingTaxOnAmt,
      incAmt: calcResult?.incAmt ?? _existingIncAmt,
      extraAmt: calcResult?.extraAmt ?? _existingExtraAmt,
      taxId: _taxId,
      taxCode: (_taxItemData?['TXCode'] ?? '').toString(),
      taxCgstRate: (_taxItemData?['TXCgstRate'] as num?)?.toDouble() ?? 0,
      taxSgstRate: (_taxItemData?['TXSgstRate'] as num?)?.toDouble() ?? 0,
      taxIgstRate: (_taxItemData?['TXIgstRate'] as num?)?.toDouble() ?? 0,
      methodId: _effectiveMethodId,
      // ── Stock2 persisted on OrderItem ──────────────────────────────────
      stock2Rows: stock2Serialized,
    );

    if (mounted) {
      Navigator.pop(context, AddItemResult(item, action));
    }
  }

  List<Map<String, dynamic>> _enrichSiDtl(
    List<Map<String, dynamic>> rows, {
    required String irSr,
    required int coSoftId,
  }) {
    return rows.map((row) {
      final r = Map<String, dynamic>.from(row);
      if ((r['SISr'] ?? '').toString().isEmpty) r['SISr'] = irSr;
      final existingSeq =
          r['SIISeqNo'] ?? r['SIIdNo'] ?? r['SIidno'] ?? 0;
      final seqInt = existingSeq is num
          ? existingSeq.toInt()
          : int.tryParse(existingSeq.toString()) ?? 0;
      if (seqInt == 0) {
        r['SIISeqNo'] = 0;
        r['SIIdNo'] = '';
        r['SIidno'] = '';
      }
      if ((r['CoSoftId'] ?? 0) == 0 && coSoftId > 0) {
        r['CoSoftId'] = coSoftId;
      }
      return r;
    }).toList();
  }

  double get _existingTotalOverhead => widget.editItem?.totalOverHead ?? 0;
  double get _existingCgst => widget.editItem?.cgstAmt ?? 0;
  double get _existingSgst => widget.editItem?.sgstAmt ?? 0;
  double get _existingIgst => widget.editItem?.igstAmt ?? 0;
  double get _existingGstCess => widget.editItem?.gstCessAmt ?? 0;
  double get _existingTaxOnAmt => widget.editItem?.taxOnAmt ?? 0;
  double get _existingIncAmt => widget.editItem?.incAmt ?? 0;
  double get _existingExtraAmt => widget.editItem?.extraAmt ?? 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sysParams = _sysParamService.cachedData?.sysparam;

    String title = widget.editItem != null ? 'Edit Item' : 'Add Item';
    if (_readOnly) title = 'View Item';

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          elevation: 0,
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: _readOnly
              ? [
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
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
        body: isLoading
            ? const Center(child: AppLoader())
            : errorMessage != null
                ? _buildErrorState()
                : _buildForm(sysParams),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(sysParams) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_readOnly)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View only – changes cannot be saved.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),

          // Party header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.partyName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Item Group
          if (itemGroups.isNotEmpty && !_isSalesInvoice) ...[
            _buildFieldLabel('Item Group (Optional)'),
            InkWell(
              onTap: (_readOnly || widget.editItem != null)
                  ? null
                  : _openItemGroupSearch,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: (_readOnly || widget.editItem != null)
                      ? Colors.grey.shade100
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.category,
                        color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedItemGroupName ?? 'Filter by group',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedItemGroupName != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    if (!_readOnly && widget.editItem == null)
                      const Icon(Icons.search,
                          color: Colors.blue, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Item
          _buildFieldLabel('Item *', required: true),
          Focus(
            focusNode: _itemFocusNode,
            child: GestureDetector(
              onTap: () {
                _itemFocusNode.requestFocus();
                _openItemSearch();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _itemFocusNode.hasFocus
                        ? Colors.blue.shade700
                        : Colors.grey.shade300,
                    width: _itemFocusNode.hasFocus ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: (_readOnly || widget.editItem != null)
                      ? Colors.grey.shade100
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2,
                        color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedItemName ?? 'Select Item',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedItemName != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    if (!_readOnly && widget.editItem == null)
                      const Icon(Icons.search,
                          size: 20, color: Colors.blue),
                  ],
                ),
              ),
            ),
          ),

          // ── Stock2 summary chip — shown when bag-wise rows exist ─────
          if (_st2ModalVisible) ...[
            const SizedBox(height: 12),
            _buildStock2SummaryRow(),
          ],

          // Item desc / brand
          if (siDescToPrint ||
              (widget.editItem != null &&
                  itemDescController.text.isNotEmpty) ||
              sysParams?.sysparamCommon.useMultiBrandSystem == true) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (siDescToPrint ||
                    (widget.editItem != null &&
                        itemDescController.text.isNotEmpty))
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: itemDescController,
                      label: 'Item Description',
                      icon: Icons.description,
                      readOnly: _readOnly,
                    ),
                  ),
                if ((siDescToPrint ||
                        (widget.editItem != null &&
                            itemDescController.text.isNotEmpty)) &&
                    sysParams?.sysparamCommon.useMultiBrandSystem == true)
                  const SizedBox(width: 12),
                if (sysParams?.sysparamCommon.useMultiBrandSystem == true)
                  Expanded(
                    flex: 1,
                    child: _buildBrandDropdown(),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Bag / Qty row
          Row(
            children: [
              if (!isCalcUnitNone)
                Expanded(
                  child: _buildTextField(
                    controller: bagController,
                    label: calUnit,
                    icon: Icons.shopping_bag,
                    keyboardType: TextInputType.number,
                    // Disabled when Stock2 modal has data
                    readOnly: _readOnly || _bagQtyLockedByStock2,
                  ),
                ),
              if (!isCalcUnitNone) const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: qtyController,
                  label: '$valUnit *',
                  icon: Icons.numbers,
                  keyboardType: TextInputType.number,
                  readOnly: _readOnly || _bagQtyLockedByStock2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

         // ── Gross Weight / Bardana Weight row ──────────────────────────────
          if (_showGrossWeightRow) ...[
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: weightController,
                    label: 'Gross Weight',
                    icon: Icons.scale,
                    keyboardType: TextInputType.number,
                    readOnly: _readOnly || _bagQtyLockedByStock2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: bardanaWeightController,
                    label: 'Bardana Weight',
                    icon: Icons.balance,
                    keyboardType: TextInputType.number,
                    readOnly: _readOnly,
                  ),
                ),
              ],
            ),
          ] else if (useSingleUnitOrder) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: weightController,
              label: 'Weight ($valUnit)',
              icon: Icons.scale,
              keyboardType: TextInputType.number,
              readOnly: _readOnly,
            ),
          ],

          const SizedBox(height: 16),

          // ── TP Rate / Rate row — together, mirrors Angular's single row ────
          Row(
            children: [
              if (readSaleTaxPaidRate)
                Expanded(
                  child: _buildTextField(
                    controller: tpRateController,
                    label: 'TP Rate *',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    readOnly: _readOnly,
                  ),
                ),
              if (readSaleTaxPaidRate) const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: rateController,
                  label: 'Rate ($rateUnit) *',
                  icon: Icons.currency_rupee,
                  keyboardType: TextInputType.number,
                  readOnly: _readOnly || readSaleTaxPaidRate,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_global.clientRegId == 672 ||
              _global.clientRegId == 68497) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: minRateController,
                    label: 'Min Rate',
                    icon: Icons.arrow_downward,
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: discPriceController,
                    label: 'Disc Price',
                    icon: Icons.discount,
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: noOfPcsController,
                    label: 'No. of Pcs',
                    icon: Icons.tag,
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: pcsRateController,
                    label: 'Rate @ Pcs',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          _buildTextField(
            controller: amountController,
            label: 'Amount',
            icon: Icons.calculate,
            keyboardType: TextInputType.number,
            readOnly: true,
          ),

          const SizedBox(height: 16),

          // SIN-only fields
          if (_isSalesInvoice) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildMethodDropdown()),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: TextEditingController(text: _hsnCode),
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600),
                    decoration: InputDecoration(
                      labelText: 'HSN Code',
                      prefixIcon: Icon(Icons.qr_code,
                          size: 20, color: Colors.grey.shade600),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGodownPicker(),
            const SizedBox(height: 16),
          ],

          if (!_isSalesInvoice)
            _buildTextField(
              controller: remarkController,
              label: 'Remark',
              icon: Icons.note,
              maxLines: 2,
              readOnly: _readOnly,
            ),

          if (widget.editItem != null &&
              widget.editItem!.totalOverHead != 0)
            _buildExistingOverheadChip(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stock2 summary row with Edit button
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStock2SummaryRow() {
    final bool hasRows = _stock2Rows.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasRows ? Colors.blue.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasRows ? Colors.blue.shade300 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.view_list_rounded,
            size: 18,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: hasRows
                ? Text(
                    'Bag-wise: ${_totalSt2Bag.toStringAsFixed(3)} $calUnit'
                    ' | ${_totalSt2Qty.toStringAsFixed(3)} $valUnit'
                    ' (${_stock2Rows.length} rows)',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500),
                  )
                : Text(
                    'Bag-wise weight required — tap to enter',
                    style: TextStyle(
                        fontSize: 13, color: Colors.blue.shade700),
                  ),
          ),
          if (!_readOnly)
            TextButton.icon(
              onPressed: _openStock2DtlModal,
              icon: Icon(
                hasRows ? Icons.edit : Icons.add,
                size: 16,
                color: Colors.blue.shade700,
              ),
              label: Text(
                hasRows ? 'Edit' : 'Add',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade700,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExistingOverheadChip() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.request_quote,
              size: 16, color: Colors.indigo.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Overhead: ₹${widget.editItem!.totalOverHead.toStringAsFixed(2)}'
              '  (CGST ₹${widget.editItem!.cgstAmt.toStringAsFixed(2)}'
              ' | SGST ₹${widget.editItem!.sgstAmt.toStringAsFixed(2)}'
              ' | IGST ₹${widget.editItem!.igstAmt.toStringAsFixed(2)})',
              style: TextStyle(fontSize: 12, color: Colors.indigo.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        required ? '$label *' : label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      style: TextStyle(
        fontSize: 14,
        color: readOnly ? Colors.grey.shade600 : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildBrandDropdown() {
    return FormField<int>(
      initialValue: selectedBrandId,
      validator: (_) => null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            value: brands.any((b) => b['id'] == selectedBrandId)
                ? selectedBrandId
                : null,
            isExpanded: true,
            onChanged: _readOnly
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      selectedBrandId = v;
                      selectedBrandName = brands
                          .firstWhere((b) => b['id'] == v)['Name'];
                    });
                    state.didChange(v);
                  },
            decoration: InputDecoration(
              labelText:
                  '${_sysParamService.cachedData?.sysparam.sysparamCommon.defaultLableBrand ?? 'Brand'} *',
              prefixIcon: Icon(Icons.local_offer,
                  size: 20, color: Colors.grey.shade600),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: state.hasError
                          ? Colors.red
                          : Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: Colors.blue.shade700, width: 2)),
              filled: _readOnly,
              fillColor: _readOnly ? Colors.grey.shade100 : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
            hint: Text('Select Brand',
                style: TextStyle(color: Colors.grey.shade500)),
            items: brands
                .map((b) => DropdownMenuItem<int>(
                      value: b['id'],
                      child: Text(b['Name'] ?? ''),
                    ))
                .toList(),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(state.errorText!,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildMethodDropdown() {
    return FormField<int>(
      initialValue: _selectedMethodId,
      validator: (_) => null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            value: _methodList.any(
                    (m) =>
                        (m['id'] as num?)?.toInt() == _selectedMethodId)
                ? _selectedMethodId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Method *',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: state.hasError
                          ? Colors.red
                          : Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: Colors.blue.shade700, width: 2)),
              filled: _readOnly,
              fillColor: _readOnly ? Colors.grey.shade100 : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              prefixIcon: Icon(Icons.calculate_outlined,
                  size: 20, color: Colors.grey.shade600),
            ),
            hint: Text('Select Method',
                style: TextStyle(color: Colors.grey.shade500)),
            items: _methodList
                .map((m) => DropdownMenuItem<int>(
                      value: (m['id'] as num?)?.toInt() ?? 0,
                      child: Text(
                        m['Name'] ?? m['AcName'] ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: _readOnly
                ? null
                : (v) {
                    setState(() {
                      _selectedMethodId = v;
                      _selectedMethodName = _methodList
                          .firstWhere(
                              (m) => (m['id'] as num?)?.toInt() == v,
                              orElse: () => {})['Name']
                          ?.toString();
                    });
                    state.didChange(v);
                  },
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(state.errorText!,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildGodownPicker() {
    return FormField<int>(
      initialValue: _selectedGodownId,
      validator: (_) => null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _readOnly || _godownList.isEmpty
                ? null
                : () async {
                    final result =
                        await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) =>
                          _GodownSearchDialog(godowns: _godownList),
                    );
                    if (result != null && mounted) {
                      setState(() {
                        _selectedGodownId =
                            (result['id'] as num?)?.toInt() ?? 0;
                        _selectedGodownName =
                            (result['AcName'] ?? result['Name'] ?? '')
                                .toString();
                      });
                      state.didChange(_selectedGodownId);
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: state.hasError
                        ? Colors.red
                        : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: _readOnly ? Colors.grey.shade100 : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.warehouse_outlined,
                      size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedGodownName ?? 'Select Godown *',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedGodownName != null
                            ? Colors.black87
                            : state.hasError
                                ? Colors.red
                                : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  if (!_readOnly)
                    Icon(Icons.search,
                        size: 20, color: Colors.blue.shade700),
                ],
              ),
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(state.errorText!,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool showSave = widget.canEdit;
    final bool showSaveAndNew =
        widget.canEdit && widget.editItem == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.red.shade400, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
            ),
            if (showSaveAndNew) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _save(AddItemAction.saveAndNew),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                        color: Colors.blue.shade700, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Save & New',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
            ],
            if (showSave) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _save(AddItemAction.save),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Stock2DtlSheet — mirrors Angular Stock2DtlModal
//
// Angular behaviour replicated:
//   • Default STBag = 1, WtPrBag = cWeight (PatchSt2DefaultItemValue)
//   • STQty = STBag × WtPrBag         (SetStock2ItemValue)
//   • WtPrBag = STQty / STBag         (getEqualValue — on STQty change)
//   • Footer totals (getSt2DtlTotal)
//   • Add / Edit / Delete rows
//   • OK button returns all rows to parent
// ─────────────────────────────────────────────────────────────────────────────
class _Stock2DtlSheet extends StatefulWidget {
  final String calUnit;
  final String valUnit;
  final double cWeight;
  final List<Stock2Row> initialRows;

  const _Stock2DtlSheet({
    required this.calUnit,
    required this.valUnit,
    required this.cWeight,
    required this.initialRows,
  });

  @override
  State<_Stock2DtlSheet> createState() => _Stock2DtlSheetState();
}

class _Stock2DtlSheetState extends State<_Stock2DtlSheet> {
  final _bagCtrl = TextEditingController();
  final _wtCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  late List<Stock2Row> _rows;
  double _totalBag = 0;
  double _totalQty = 0;
  int? _editingIndex; // null = Add mode
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _rows = List.from(widget.initialRows);
    _recalcTotals();
    _resetForm();           // pre-fill default bag=1, wt=cWeight
    _bagCtrl.addListener(_onBagChanged);
    _wtCtrl.addListener(_onWtChanged);
    _qtyCtrl.addListener(_onQtyChanged);
  }

  @override
  void dispose() {
    _bagCtrl.removeListener(_onBagChanged);
    _wtCtrl.removeListener(_onWtChanged);
    _qtyCtrl.removeListener(_onQtyChanged);
    _bagCtrl.dispose();
    _wtCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _recalcTotals() {
    _totalBag = _rows.fold(0.0, (s, r) => s + r.stBag);
    _totalQty = _rows.fold(0.0, (s, r) => s + r.stQty);
  }

  /// Mirrors Angular PatchSt2DefaultItemValue — called on reset / row add
  void _resetForm() {
    _editingIndex = null;
    _isSyncing = true;
    _bagCtrl.text = '1';
    final double wt = widget.cWeight > 0 ? widget.cWeight : 1;
    _wtCtrl.text = wt.toStringAsFixed(3);
    _qtyCtrl.text = (1 * wt).toStringAsFixed(3);
    _isSyncing = false;
  }

  // Mirrors Angular SetStock2ItemValue (bag/wt → qty)
  void _onBagChanged() {
    if (_isSyncing) return;
    _isSyncing = true;
    final bag = double.tryParse(_bagCtrl.text) ?? 0;
    final wt = double.tryParse(_wtCtrl.text) ?? 0;
    _qtyCtrl.text = (bag * wt).toStringAsFixed(3);
    _isSyncing = false;
  }

  void _onWtChanged() {
    if (_isSyncing) return;
    _isSyncing = true;
    final bag = double.tryParse(_bagCtrl.text) ?? 0;
    final wt = double.tryParse(_wtCtrl.text) ?? 0;
    _qtyCtrl.text = (bag * wt).toStringAsFixed(3);
    _isSyncing = false;
  }

  // Mirrors Angular getEqualValue (qty changed → back-calc wt)
  void _onQtyChanged() {
    if (_isSyncing) return;
    _isSyncing = true;
    final bag = double.tryParse(_bagCtrl.text) ?? 0;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    if (bag > 0) {
      _wtCtrl.text = (qty / bag).toStringAsFixed(3);
    }
    _isSyncing = false;
  }

  void _saveRow() {
    final bag = double.tryParse(_bagCtrl.text) ?? 0;
    final wt = double.tryParse(_wtCtrl.text) ?? 0;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;

    if (qty == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Qty cannot be zero')));
      return;
    }

    setState(() {
      if (_editingIndex == null) {
        _rows.add(Stock2Row(stBag: bag, wtPerBag: wt, stQty: qty));
      } else {
        _rows[_editingIndex!] =
            Stock2Row(stBag: bag, wtPerBag: wt, stQty: qty);
      }
      _recalcTotals();
      _resetForm();
    });
  }

  void _editRow(int i) {
    final r = _rows[i];
    setState(() => _editingIndex = i);
    _isSyncing = true;
    _bagCtrl.text = r.stBag.toStringAsFixed(3);
    _wtCtrl.text = r.wtPerBag.toStringAsFixed(3);
    _qtyCtrl.text = r.stQty.toStringAsFixed(3);
    _isSyncing = false;
  }

  void _deleteRow(int i) {
    setState(() {
      _rows.removeAt(i);
      _recalcTotals();
      _resetForm();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Drag handle + header ──────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.view_list_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Bag Wise Weight',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Entry form ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          ctrl: _bagCtrl,
                          label: widget.calUnit,
                          icon: Icons.shopping_bag_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          ctrl: _wtCtrl,
                          label: '${widget.valUnit}/${widget.calUnit}',
                          icon: Icons.balance,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          ctrl: _qtyCtrl,
                          label: widget.valUnit,
                          icon: Icons.numbers,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Save row button
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: _saveRow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Icon(
                            _editingIndex == null
                                ? Icons.add
                                : Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_editingIndex != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Editing row ${_editingIndex! + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _resetForm,
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 16),

            // ── Table header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _th('SNo', flex: 1),
                  _th(widget.calUnit, flex: 2),
                  _th(
                      '${widget.valUnit}/${widget.calUnit}',
                      flex: 2),
                  _th(widget.valUnit, flex: 2),
                  _th('Action', flex: 2),
                ],
              ),
            ),
            const Divider(height: 4),

            // ── Rows ──────────────────────────────────────────────────
            Expanded(
              child: _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 48,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('No rows added yet',
                              style: TextStyle(
                                  color: Colors.grey.shade400)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        final isEditing = _editingIndex == i;
                        return Container(
                          color: isEditing
                              ? Colors.blue.shade50
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 6),
                          child: Row(
                            children: [
                              _td('${i + 1}', flex: 1,
                                  bold: isEditing),
                              _td(
                                  r.stBag.toStringAsFixed(3),
                                  flex: 2),
                              _td(
                                  r.wtPerBag.toStringAsFixed(3),
                                  flex: 2),
                              _td(
                                  r.stQty.toStringAsFixed(3),
                                  flex: 2),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit,
                                          size: 18,
                                          color: Colors.blue
                                              .shade600),
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints(),
                                      onPressed: () => _editRow(i),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.delete,
                                          size: 18,
                                          color: Colors.red
                                              .shade400),
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints(),
                                      onPressed: () =>
                                          _deleteRow(i),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // ── Footer totals ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                    top: BorderSide(color: Colors.blue.shade200)),
              ),
              child: Row(
                children: [
                  _td('Total: ${_rows.length}', flex: 1,
                      bold: true),
                  _td(_totalBag.toStringAsFixed(3),
                      flex: 2, bold: true),
                  _td('', flex: 2),
                  _td(_totalQty.toStringAsFixed(3),
                      flex: 2, bold: true),
                  const Expanded(flex: 2, child: SizedBox()),
                ],
              ),
            ),

            // ── OK button ─────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _rows),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, size: 16, color: Colors.blue.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        isDense: true,
      ),
    );
  }

  Widget _th(String t, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _td(String t, {int flex = 1, bool bold = false}) => Expanded(
        flex: flex,
        child: Text(
          t,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            color: bold ? Colors.black87 : Colors.grey.shade700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Godown Search Dialog (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────
class _GodownSearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> godowns;
  const _GodownSearchDialog({required this.godowns});

  @override
  State<_GodownSearchDialog> createState() => _GodownSearchDialogState();
}

class _GodownSearchDialogState extends State<_GodownSearchDialog> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.godowns;
    _ctrl.addListener(() {
      final q = _ctrl.text.toLowerCase();
      setState(() {
        _filtered = widget.godowns.where((g) {
          final name =
              ((g['AcName'] ?? g['Name'] ?? '') as String).toLowerCase();
          return name.contains(q);
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search godown...',
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
                final g = _filtered[i];
                return ListTile(
                  title:
                      Text((g['AcName'] ?? g['Name'] ?? '').toString()),
                  onTap: () => Navigator.pop(context, g),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}