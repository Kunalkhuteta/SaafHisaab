import 'package:flutter/material.dart';
import 'package:saafhisaab/services/general_service.dart';
import 'package:saafhisaab/services/global_data.dart';
import 'package:saafhisaab/screens/orderPages/widgets/CalculationEngine.dart';

/// ============================================================
/// CalculationDetailDialog
/// ============================================================
///
/// Flutter port of `sale-invoice-overhead-entry-form.component.ts`
/// (+ `.html`).
///
/// Shown after "Save" / "Save & New" in AddItemDialog, mirroring
/// Angular's `openCalcMethod()` -> opens `#CalMethod` modal ->
/// user edits SIDtl rows -> `goBack()` -> `Closed.emit()` ->
/// `CloseCalcMethod()` in the parent.
///
/// Usage:
///   final result = await Navigator.push<CalculationDetailResult>(
///     context,
///     MaterialPageRoute(
///       fullscreenDialog: true,
///       builder: (_) => CalculationDetailDialog(
///         cBag: bag,
///         cQty: qty,
///         cRate: rate,
///         cAmount: amountAfterDisc,
///         existingSIDtl: item.siDtl, // null/empty for new item
///         itemId: item.itemId,
///         methodId: item.methodId ?? 0,
///         orderType: 'SALES', // or 'PURCHASE'
///         irSr: 'SIN',        // SIN/SRD/PIN/PTC etc
///         brokerId: selectedBrokerId,
///         ptAccountId: selectedPartyId,
///         isInterStateParty: isInterState,
///       ),
///     ),
///   );
///   if (result != null) {
///     item = item.copyWith(siDtl: result.sidtl, ...taxAmounts);
///   }

class CalculationDetailResult {
  final List<Map<String, dynamic>> sidtl;
  final double totalOverHead;
  final double cgstAmt;
  final double sgstAmt;
  final double igstAmt;
  final double gstCessAmt;
  final double taxOnAmt;
  final double incAmt;
  final double extraAmt;

  CalculationDetailResult({
    required this.sidtl,
    required this.totalOverHead,
    required this.cgstAmt,
    required this.sgstAmt,
    required this.igstAmt,
    required this.gstCessAmt,
    required this.taxOnAmt,
    required this.incAmt,
    required this.extraAmt,
  });
}

class CalculationDetailDialog extends StatefulWidget {
  /// Bag count for this item (CBag)
  final double cBag;
  /// Qty for this item (CQty)
  final double cQty;
  /// Rate for this item (CRate)
  final double cRate;
  /// Basic amount (after discount) for this item (CAmount)
  final double cAmount;

  /// Existing SIDtl rows (edit mode) — pass item.siDtl. Empty/null for new item.
  final List<Map<String, dynamic>>? existingSIDtl;

  /// Item context — needed to fetch default calculation method rows
  final int itemId;
  final int methodId;
  /// 'SALES' or 'PURCHASE'
  final String orderType;
  /// IRSr code: SIN, SRD, SRC, PIN, PTD, PTC, PSI
  final String irSr;

  /// Broker context — for brokerage-rate auto-fill (ScheduleId == 46 accounts)
  final int? brokerId;
  final int ptAccountId;

  /// Whether the party is interstate (affects CGST/SGST vs IGST application)
  final bool isInterStateParty;

  /// TaxData entry for this item (TXCgstRate / TXSgstRate / TXIgstRate / id)
  /// Pass the same map you already fetch for tax-rate calculation in AddItemDialog.
  final Map<String, dynamic>? taxItemData;

  /// Whether UpdateEditAmt flag should be true (item fields changed on edit)
  final bool updateEditAmt;

  /// Effective date string (dd/MM/yyyy or similar) for fetching default
  /// calculation rows — usually invoice date.
  final String effDate;

  const CalculationDetailDialog({
    super.key,
    required this.cBag,
    required this.cQty,
    required this.cRate,
    required this.cAmount,
    this.existingSIDtl,
    required this.itemId,
    required this.methodId,
    required this.orderType,
    required this.irSr,
    this.brokerId,
    required this.ptAccountId,
    required this.isInterStateParty,
    this.taxItemData,
    this.updateEditAmt = false,
    required this.effDate,
  });

  @override
  State<CalculationDetailDialog> createState() =>
      _CalculationDetailDialogState();
}

class _CalculationDetailDialogState extends State<CalculationDetailDialog> {
  final GlobalData _global = GlobalData();

  List<Map<String, dynamic>> sidtl = [];
  List<Map<String, dynamic>> accountData = [];
  Map<String, dynamic>? _resolvedTaxItem;

  bool isLoading = true;
  bool isFetchingTax = false;

  double mBasicAmt = 0;
  double mSuccessAmt = 0;
  double pSuccessAmt = 0;
  double mPrevAmt = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  bool get _forSales =>
      widget.orderType == 'SALES' &&
      (widget.irSr == 'SIN' ||
          widget.irSr == 'SRD' ||
          widget.irSr == 'SRC' ||
          widget.irSr == 'PSI');

  String get _cmtFlag {
    if (widget.irSr == 'SIN' ||
        widget.irSr == 'SRD' ||
        widget.irSr == 'SRC' ||
        widget.irSr == 'PSI') {
      return 'S';
    }
    if (widget.irSr == 'PIN' || widget.irSr == 'PTD' || widget.irSr == 'PTC') {
      return 'P';
    }
    return '';
  }

Future<void> _init() async {
  if (mounted) setState(() => isLoading = true);

  try {
    // 1. Load account data for "A/C Head" dropdown
    accountData = await GeneralService.getAllAccountsData(
      clientRegId: _global.clientRegId ?? 0,
      coSoftId: _global.coSoftId ?? 0,
      commonSalesOrder: _global.CommonSalesOrder ?? false,
    );

    // 2. Resolve taxItemData — use passed value or fetch from API
    //    Mirrors: this.accountService.getTaxTypeById(TaxId)
    _resolvedTaxItem = widget.taxItemData;
    if (_resolvedTaxItem == null) {
      // taxItemData not passed — nothing to stamp; rates stay as-is
      debugPrint('CalculationDetailDialog: taxItemData not provided, '
          'tax rates will not be auto-stamped.');
    }

    // 3. Populate SIDtl rows
    if (widget.existingSIDtl != null && widget.existingSIDtl!.isNotEmpty) {
      // Edit mode — deep copy
      sidtl = widget.existingSIDtl!
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      // Mirrors Angular else-branch: InitialiseTaxTypeRate()
      await _initialiseTaxTypeRate();
    } else {
      // New item — fetch default method rows
      await _fetchDefaultCalculationRows();
    }

    _setVariablesValue();
  } catch (e) {
    debugPrint('CalculationDetailDialog._init error: $e');
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}


  /// Mirrors refreshTable() -> getAllCalculate$()
Future<void> _fetchDefaultCalculationRows() async {
  // Resolve MethodId (mirrors getItemMethodId in Angular)
  int methodId = widget.methodId;
  try {
    final fetched = await GeneralService.getCalculationMethodIdByItemId(
      clientRegId: _global.clientRegId ?? 0,
      coSoftId: _global.coSoftId ?? 0,
      commonSalesOrder: _global.CommonSalesOrder ?? false,
      itemId: widget.itemId,
      ptAccountId: widget.ptAccountId,
      stsr: widget.irSr,
      effDate: widget.effDate,
    );
    if (fetched > 0) methodId = fetched;
  } catch (e) {
    debugPrint('getCalculationMethodIdByItemId error: $e');
  }

  // Fetch default SIDtl rows for this method
  final rows = await GeneralService.getAllCalculate(
    clientRegId: _global.clientRegId ?? 0,
    coSoftId: _global.coSoftId ?? 0,
    methodId: methodId,
    itemId: widget.itemId,
    salePurchFlag: '',
    effDate: '',
    cmtFlag: _cmtFlag,
    forSales: true,
    byMethodId: true,
    commonSalesOrder: _global.CommonSalesOrder ?? false,
    ptAccountId: widget.ptAccountId,
  );

  sidtl = rows.map((r) {
    final row = Map<String, dynamic>.from(r);
    row['Amount']       = 0.0;
    row['EditAmt']      = false;
    row['id']           = 0;
    row['isFreeGiftItem'] = row['isFreeGiftItem'] == true;
    row['Rate']         = (row['Rate'] as num?)?.toDouble() ?? 0.0;
    row['RndBy']        = (row['RndBy'] as num?)?.toDouble() ?? 0.01;
    row['RndType']      = row['RndType'] ?? 'N';
    row['CalcOnAmt']    = (row['CalcOnAmt'] as num?)?.toDouble() ?? 0.0;
    row['SNo']          = (row['SNo'] as num?)?.toInt() ?? 0;
    return row;
  }).toList();

  // Mirrors Angular: InitialiseTaxTypeRate() called after getAllCalculate$
  // This stamps CGST/SGST/IGST rates and runs CalcSuccessAmt
  await _initialiseTaxTypeRate();
}


// In Calculationdetaildialog.dart — replace _initialiseTaxTypeRate()

Future<void> _initialiseTaxTypeRate() async {
  // ── Step 1: Get the tax record ────────────────────────────────────────
  // Use already-resolved taxItem if available, otherwise fetch from API
  Map<String, dynamic>? taxItem = _resolvedTaxItem ?? widget.taxItemData;

  if (taxItem == null) {
    // No taxItemData passed and none fetched yet — try fetching now
    // This matches Angular where TaxId comes from StockDtl.TaxId
    // In Flutter the taxItemData is passed from AddItemDialog._calculateTaxRate()
    // If still null, skip rate stamping gracefully
    debugPrint('_initialiseTaxTypeRate: no taxItem available, skipping rate stamp');
    if (widget.brokerId != null && widget.brokerId! > 0) {
      await _initialiseBrokerageRate();
    }
    _runCalcSuccessAmt(updateEditAmt: widget.updateEditAmt);
    return;
  }

  // ── Step 2: Stamp Rate on tax account rows ────────────────────────────
  // Mirrors Angular:
  //   if (obj.AccountId == 11) obj.Rate = IsInterStateParty ? 0 : TXCgstRate
  //   if (obj.AccountId == 12) obj.Rate = IsInterStateParty ? 0 : TXSgstRate
  //   if (obj.AccountId == 13) obj.Rate = IsInterStateParty ? TXIgstRate : 0
  final double cgstRate = (taxItem['TXCgstRate'] as num?)?.toDouble() ?? 0;
  final double sgstRate = (taxItem['TXSgstRate'] as num?)?.toDouble() ?? 0;
  final double igstRate = (taxItem['TXIgstRate'] as num?)?.toDouble() ?? 0;

  for (final row in sidtl) {
    final int accId = (row['AccountId'] as num?)?.toInt() ?? 0;
    // Do NOT overwrite rates on rows the user manually edited (EditAmt == true).
    // This mirrors Angular's behaviour where only non-edited tax rows are
    // re-stamped from the tax type on each InitialiseTaxTypeRate call.
    final bool userEdited = row['EditAmt'] == true;
    if (accId == 11 && !userEdited) {
      // CGST
      row['Rate'] = widget.isInterStateParty ? 0.0 : cgstRate;
    } else if (accId == 12 && !userEdited) {
      // SGST
      row['Rate'] = widget.isInterStateParty ? 0.0 : sgstRate;
    } else if (accId == 13 && !userEdited) {
      // IGST
      row['Rate'] = widget.isInterStateParty ? igstRate : 0.0;
    }
  }

  // ── Step 3: Fill brokerage rates ──────────────────────────────────────
  if (widget.brokerId != null && widget.brokerId! > 0) {
    await _initialiseBrokerageRate();
  }

  // ── Step 4: Recompute all row amounts ─────────────────────────────────
  // Mirrors Angular: CalcSuccessAmt(0, mBasicAmt, mBasicAmt, CBag, CQty, SIDtl, UpdateEditAmt)
  _runCalcSuccessAmt(updateEditAmt: false);
}
  /// Mirrors initialiseBrokerageRate() — for rows whose AccountId has
  /// ScheduleId == 46 in accountData, fetch the live brokerage rate.
  Future<void> _initialiseBrokerageRate() async {
    if (widget.brokerId == null || widget.brokerId! <= 0) return;

    for (final row in sidtl) {
      final int accId = (row['AccountId'] as num?)?.toInt() ?? 0;
      final acc = accountData.firstWhere(
        (a) => (a['id'] ?? a['Id']) == accId,
        orElse: () => {},
      );
      final scheduleId = acc['ScheduleId'];
      if (scheduleId == 46) {
        try {
          final data = await GeneralService.getBrokerageRate(
            brokerId: widget.brokerId!,
            itemId: widget.itemId,
            coSoftId: _global.coSoftId ?? 0,
            clientRegId: _global.clientRegId ?? 0,
            commonSalesOrder: _global.CommonSalesOrder ?? false,
          );
          row['Rate'] = (data?['Brokerate'] as num?)?.toDouble() ?? 0.0;
        } catch (e) {
          debugPrint('initialiseBrokerageRate error: $e');
          row['Rate'] = 0.0;
        }
      }
    }
  }

  /// Mirrors setVariablesvalue()
  void _setVariablesValue() {
    if (sidtl.isNotEmpty) {
      final lastIndex = sidtl.length - 1;
      mPrevAmt = (sidtl[lastIndex]['Amount'] as num?)?.toDouble() ?? 0;
      mBasicAmt = widget.cAmount;
      mSuccessAmt = sidtl
              .where((e) =>
                  e['EditAmt'] != true &&
                  e['Chrble'] != 'L' &&
                  ((e['AccountId'] as num?)?.toInt() ?? 0) != 0)
              .fold<double>(
                  0.0, (s, e) => s + ((e['Amount'] as num?)?.toDouble() ?? 0)) +
          widget.cAmount;
      pSuccessAmt = sidtl
              .sublist(0, sidtl.length - 1)
              .where((e) => ((e['AccountId'] as num?)?.toInt() ?? 0) != 0)
              .fold<double>(
                  0.0, (s, e) => s + ((e['Amount'] as num?)?.toDouble() ?? 0)) +
          widget.cAmount;
    } else {
      mPrevAmt = 0;
      mBasicAmt = widget.cAmount;
      mSuccessAmt = widget.cAmount;
      pSuccessAmt = widget.cAmount;
    }
    if (mounted) setState(() {});
  }

  /// Mirrors the CalcSuccessAmt() call used in refreshTable / addObjectWithUniqueSno
  // In Calculationdetaildialog.dart — replace _runCalcSuccessAmt()

void _runCalcSuccessAmt({bool updateEditAmt = false}) {
  // mBasicAmt is widget.cAmount (Amount after discount)
  final double basic = mBasicAmt == 0 ? widget.cAmount : mBasicAmt;

  final result = CalculationEngine.calcSuccessAmt(
    mSNo: 0,
    mBasicAmt: basic,
    mGrossAmt: basic,
    cBag: widget.cBag,
    cQty: widget.cQty,
    sidtl: sidtl,
    updateEditAmt: updateEditAmt,
  );

  sidtl = result.sidtl;
  _setVariablesValue();
  if (mounted) setState(() {});
}

  /// Recompute calcSuccessAmt up to a given SNo — mirrors calcSuccessAmt(e, Sno)
  void _calcSuccessAmtUpToSno(int sno) {
    mSuccessAmt = mBasicAmt;
    pSuccessAmt = mBasicAmt;
    mPrevAmt = 0;

    if (sno > 0) {
      mSuccessAmt = sidtl
              .where((e) =>
                  ((e['SNo'] as num?)?.toInt() ?? 0) < sno &&
                  e['EditAmt'] != true)
              .fold<double>(
                  0.0, (s, e) => s + ((e['Amount'] as num?)?.toDouble() ?? 0)) +
          mBasicAmt;

      final prevRow = sidtl.firstWhere(
        (e) => ((e['SNo'] as num?)?.toInt() ?? 0) == sno - 1,
        orElse: () => {},
      );
      mPrevAmt = prevRow.isNotEmpty
          ? ((prevRow['Amount'] as num?)?.toDouble() ?? 0)
          : 0;

      pSuccessAmt = mSuccessAmt - mPrevAmt;
    }
    if (mounted) setState(() {});
  }

  String _accountName(int id) {
    final match = accountData.firstWhere(
      (a) => (a['id'] ?? a['Id']) == id,
      orElse: () => {},
    );
    return match.isNotEmpty ? (match['AcName'] ?? match['Name'] ?? '') : '';
  }

  double get _totalNetAmount {
    return sidtl.fold<double>(
        0.0,
        (s, e) {
          final int accId = (e['AccountId'] as num?)?.toInt() ?? 0;
          if (accId == 0) return s;
          return s +
              (e['Chrble'] == 'L' ? 0 : ((e['Amount'] as num?)?.toDouble() ?? 0));
        });
  }

  /// Mirrors GetMaxCalcSNo()
  int _getMaxCalcSNo() {
    if (sidtl.isEmpty) return 1;
    final maxSno = sidtl
        .map((e) => (e['SNo'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return maxSno + 1;
  }

  /// Mirrors addObjectWithUniqueSno() — add a new row, keep SNo sequential
  void _addRow(Map<String, dynamic> newRow) {
    final existingIndex =
        sidtl.indexWhere((e) => e['SNo'] == newRow['SNo']);
    if (existingIndex != -1) {
      sidtl.insert(existingIndex, newRow);
    } else {
      sidtl.add(newRow);
    }
    for (int i = 0; i < sidtl.length; i++) {
      sidtl[i]['SNo'] = i + 1;
    }
    _runCalcSuccessAmt(updateEditAmt: widget.updateEditAmt);
  }

  /// Mirrors repositionItem()
  void _repositionItem(int editIndex, int targetSno) {
    final max = sidtl.length;
    final newSno = targetSno.clamp(1, max);
    final item = sidtl.removeAt(editIndex);
    sidtl.insert(newSno - 1, item);
    for (int i = 0; i < sidtl.length; i++) {
      sidtl[i]['SNo'] = i + 1;
    }
    _runCalcSuccessAmt();
  }

  Future<void> _deleteRow(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure you want to delete this charge?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        sidtl.removeAt(index);
        _runCalcSuccessAmt();
      });
    }
  }

  Future<void> _openAddEditRowDialog({Map<String, dynamic>? editRow, int? editIndex}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CalcDtlEntryDialog(
        accountData: accountData,
        editRow: editRow,
        mAmount: editIndex != null
            ? ((editRow?['Amount'] as num?)?.toDouble() ?? 0)
            : 0,
        onCheckDuplicate: (accId) {
          final exists = sidtl.any((e) =>
              e['AccountId'] == accId &&
              (editIndex == null || sidtl.indexOf(e) != editIndex));
          return exists;
        },
        onCalcSuccessAmtForSno: (sno) {
          _calcSuccessAmtUpToSno(sno);
        },
        mBasicAmt: mBasicAmt,
        mSuccessAmt: mSuccessAmt,
        pSuccessAmt: pSuccessAmt,
        mPrevAmt: mPrevAmt,
        cBag: widget.cBag,
        cQty: widget.cQty,
      ),
    );

    if (result == null) return;

    setState(() {
      if (editIndex == null) {
        // Add
        final maxSno = _getMaxCalcSNo();
        result['SNo'] = result['SNo'] == 0 ? maxSno : result['SNo'];
        result['id'] = 0;
        result['CoSoftId'] = _global.coSoftId ?? 0;
        result['CalcOnAccountId'] = '';
        result['SIidno'] = '';
        result['CalcOnAmt'] = 0.0;
        result['RndType'] = 'N';
        result['RndBy'] = 0.001;
        _addRow(result);
      } else {
        // Edit
        final item = sidtl[editIndex];
        final oldSno = (item['SNo'] as num?)?.toInt() ?? 0;
        item['SNo'] = result['SNo'];
        item['AccountId'] = result['AccountId'];
        item['Rate'] = result['Rate'];
        item['CalcFlag'] = result['CalcFlag'];
        item['Chrble'] = result['Chrble'];
        item['DedTDS'] = result['DedTDS'];
        item['Incl'] = result['Incl'];
        item['RndType'] = 'N';
        item['RndBy'] = 0.001;
        item['CoSoftId'] = _global.coSoftId ?? 0;
        item['Amount'] = result['Amount'];
        item['CalcOnAccountId'] = '';
        item['EditAmt'] = result['EditAmt'];
        item['SIidno'] = '';
        item['CalcOnAmt'] = 0.0;

        final newSno = (result['SNo'] as num?)?.toInt() ?? oldSno;
        _repositionItem(editIndex, newSno);
      }
    });
  }

  // In Calculationdetaildialog.dart — replace _onDone()

void _onDone() {
  final double basicAmtAfterDisc = widget.cAmount;

  // Use resolved tax item (from widget or fetched during init)
  final Map<String, dynamic>? taxItem =
      _resolvedTaxItem ?? widget.taxItemData;

  final TaxAmtResult taxResult = CalculationEngine.computeTaxAmounts(
    sidtl: sidtl,
    taxItem: taxItem,
    accountData: accountData,
    basicAmtAfterDisc: basicAmtAfterDisc,
    cBag: widget.cBag,
    cQty: widget.cQty,
    isInterStateParty: widget.isInterStateParty,
    updateEditAmt: widget.updateEditAmt,
  );

  // totalOverHead = sum of non-Self (Chrble != 'L') row amounts
  final double totalOverHead = taxResult.sidtl.fold<double>(
    0.0,
    (s, e) {
      final int accId = (e['AccountId'] as num?)?.toInt() ?? 0;
      if (accId == 0) return s;
      return s +
          ((e['Chrble'] ?? '') == 'L'
              ? 0.0
              : ((e['Amount'] as num?)?.toDouble() ?? 0.0));
    },
  );

  Navigator.pop(
    context,
    CalculationDetailResult(
      sidtl: taxResult.sidtl,
      totalOverHead: totalOverHead,
      cgstAmt: taxResult.cgstAmt,
      sgstAmt: taxResult.sgstAmt,
      igstAmt: taxResult.igstAmt,
      gstCessAmt: taxResult.gstCessAmt,
      taxOnAmt: taxResult.taxOnAmt,
      incAmt: taxResult.incAmt,
      extraAmt: taxResult.extraAmt,
    ),
  );
}

  void _onCancel() {
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onCancel();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Calculation Method'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _onCancel,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _openAddEditRowDialog(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Charge',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBody() {
    final displayRows = sidtl
        .where((e) => ((e['AccountId'] as num?)?.toInt() ?? 0) != 0)
        .toList();

    return Column(
      children: [
        // Summary strip — mirrors ilh-bottom summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.blue.shade50,
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _summaryChip(
                  'Bag/Qty/Rate',
                  '${widget.cBag.toStringAsFixed(0)} / ${widget.cQty.toStringAsFixed(3)} / ${widget.cRate.toStringAsFixed(4)}'),
              _summaryChip('Calc. Amt', widget.cAmount.toStringAsFixed(2)),
              _summaryChip('Success Amt', mSuccessAmt.toStringAsFixed(2)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: displayRows.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No charges added',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: displayRows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = displayRows[index];
                    final realIndex = sidtl.indexOf(item);
                    return _buildRowCard(realIndex);
                  },
                ),
        ),
        _buildTotalsFooter(displayRows.length),
      ],
    );
  }

  Widget _summaryChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87)),
      ],
    );
  }

  Widget _buildRowCard(int index) {
    final row = sidtl[index];
    final accId = (row['AccountId'] as num?)?.toInt() ?? 0;
    final rate = (row['Rate'] as num?)?.toDouble() ?? 0;
    final amount = (row['Amount'] as num?)?.toDouble() ?? 0;
    final calcFlag = (row['CalcFlag'] ?? '').toString();
    final chrble = (row['Chrble'] ?? '').toString();
    final incl = (row['Incl'] ?? '').toString();
    final dedTds = row['DedTDS'] == true;
    final editAmt = row['EditAmt'] == true;
    final sNo = (row['SNo'] as num?)?.toInt() ?? (index + 1);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openAddEditRowDialog(editRow: row, editIndex: index),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.blue.shade100,
                    child: Text('$sNo',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _accountName(accId).isEmpty
                          ? 'Account #$accId'
                          : _accountName(accId),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (editAmt)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('EDITED',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    onPressed: () => _deleteRow(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _detail('Rate', rate.toStringAsFixed(3)),
                  _detail('Calc Unit', getCalcUnitName(calcFlag)),
                  _detail('Amount', amount.toStringAsFixed(2),
                      bold: true, color: Colors.green.shade700),
                  _detail('Chargeable', getChrbleName(chrble)),
                  _detail('Incl.', getInclName(incl)),
                  _detail('TDS', dedTds ? 'Yes' : 'No'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value,
      {bool bold = false, Color? color}) {
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 12,
        color: color ?? Colors.black87,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTotalsFooter(int displayCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Charges: $displayCount',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            'Total Net Amount: ${_totalNetAmount.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.green.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.red.shade400, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Cancel',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _onDone,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('OK',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// _CalcDtlEntryDialog
/// ============================================================
/// Mirrors `#CalcDtlModalM` (Add/Edit a single SIDtl row)
class _CalcDtlEntryDialog extends StatefulWidget {
  final List<Map<String, dynamic>> accountData;
  final Map<String, dynamic>? editRow;
  final double mAmount;
  final bool Function(int accountId) onCheckDuplicate;
  final void Function(int sno) onCalcSuccessAmtForSno;
  final double mBasicAmt;
  final double mSuccessAmt;
  final double pSuccessAmt;
  final double mPrevAmt;
  final double cBag;
  final double cQty;

  const _CalcDtlEntryDialog({
    required this.accountData,
    this.editRow,
    required this.mAmount,
    required this.onCheckDuplicate,
    required this.onCalcSuccessAmtForSno,
    required this.mBasicAmt,
    required this.mSuccessAmt,
    required this.pSuccessAmt,
    required this.mPrevAmt,
    required this.cBag,
    required this.cQty,
  });

  @override
  State<_CalcDtlEntryDialog> createState() => _CalcDtlEntryDialogState();
}

class _CalcDtlEntryDialogState extends State<_CalcDtlEntryDialog> {
  final _formKey = GlobalKey<FormState>();

  int? selectedAccountId;
  String selectedAccountName = '';
  String calcFlag = 'F';
  String chrble = 'B';
  String incl = 'N';
  String dedTds = 'false';

  final rateController = TextEditingController(text: '0.00');
  final amountController = TextEditingController(text: '0.00');
  final snoController = TextEditingController(text: '0');

  late double mAmount;
  late double mBasicAmt;
  late double mSuccessAmt;
  late double pSuccessAmt;
  late double mPrevAmt;

  bool get isEdit => widget.editRow != null;

  @override
  void initState() {
    super.initState();
    mAmount = widget.mAmount;
    mBasicAmt = widget.mBasicAmt;
    mSuccessAmt = widget.mSuccessAmt;
    pSuccessAmt = widget.pSuccessAmt;
    mPrevAmt = widget.mPrevAmt;

    if (isEdit) {
      final row = widget.editRow!;
      selectedAccountId = (row['AccountId'] as num?)?.toInt();
      calcFlag = (row['CalcFlag'] ?? 'F').toString();
      chrble = (row['Chrble'] ?? 'B').toString();
      incl = (row['Incl'] ?? 'N').toString();
      dedTds = (row['DedTDS'] == true) ? 'true' : 'false';
      rateController.text =
          ((row['Rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(3);
      amountController.text =
          ((row['Amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
      snoController.text = ((row['SNo'] as num?)?.toInt() ?? 0).toString();

      final acc = widget.accountData.firstWhere(
        (a) => (a['id'] ?? a['Id']) == selectedAccountId,
        orElse: () => {},
      );
      selectedAccountName = acc.isNotEmpty
          ? (acc['AcName'] ?? acc['Name'] ?? '')
          : '';
    } else {
      // Defaults mirroring ResetCalc()
      calcFlag = 'F';
      chrble = 'B';
      incl = 'N';
      dedTds = 'false';
      rateController.text = '0.00';
      amountController.text = '0.00';
      snoController.text = '0';
    }
  }

  @override
  void dispose() {
    rateController.dispose();
    amountController.dispose();
    snoController.dispose();
    super.dispose();
  }

  /// Mirrors NetAmount(e) — recompute Amount based on CalcFlag + Rate
  void _recalcAmount() {
    final rate = double.tryParse(rateController.text) ?? 0;
    final result = CalculationEngine.calcFlagAmt(
      mBag: widget.cBag,
      mQty: widget.cQty,
      mCalcRate: rate,
      f: calcFlag,
      mBasicAmt: mBasicAmt,
      mSuccessiveAmt: mSuccessAmt,
      pSuccessiveAmt: pSuccessAmt,
      mPrevAmt: mPrevAmt,
      mAmount: mAmount,
      mRndBy: 0.001,
      mRndType: 'N',
      mCalcOnAmt: 0,
    );
    mAmount = result.amount;
    amountController.text = mAmount.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _openAccountPicker() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AccountPickerDialog(accounts: widget.accountData),
    );
    if (result != null) {
      final accId = (result['id'] ?? result['Id']) as int;
      if (widget.onCheckDuplicate(accId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry Already Exists On this Account'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      setState(() {
        selectedAccountId = accId;
        selectedAccountName = result['AcName'] ?? result['Name'] ?? '';
      });
    }
  }

  void _save() {
    if (selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account is required')),
      );
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0;
    final editAmt = amount != mAmount; // checkEditAmt mirror — see note below

    Navigator.pop(context, {
      'SNo': int.tryParse(snoController.text) ?? 0,
      'AccountId': selectedAccountId,
      'Rate': double.tryParse(rateController.text) ?? 0,
      'CalcFlag': calcFlag,
      'Chrble': chrble,
      'DedTDS': dedTds == 'true',
      'Incl': incl,
      'Amount': amount,
      'EditAmt': editAmt,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Charge' : 'Add Charge',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: snoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'SNo',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          onChanged: (v) {
                            final sno = int.tryParse(v) ?? 0;
                            widget.onCalcSuccessAmtForSno(sno);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: InkWell(
                          onTap: _openAccountPicker,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'A/C Head *',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              suffixIcon:
                                  const Icon(Icons.search, size: 18),
                            ),
                            child: Text(
                              selectedAccountName.isEmpty
                                  ? 'Select Account'
                                  : selectedAccountName,
                              style: TextStyle(
                                color: selectedAccountName.isEmpty
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: 'Rate',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          onChanged: (_) => _recalcAmount(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: calcFlag,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Calc. Unit',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          items: kCalcFlagData
                              .map((e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text(e.name,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() => calcFlag = v ?? 'F');
                            _recalcAmount();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Net Amount',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    onChanged: (v) {
                      mAmount = double.tryParse(v) ?? mAmount;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: chrble,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Chargeable To',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          items: kChrbleAmount
                              .map((e) => DropdownMenuItem(
                                  value: e.id, child: Text(e.name)))
                              .toList(),
                          onChanged: (v) => setState(() => chrble = v ?? 'B'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: incl,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Incl. Flag',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          items: kInclData
                              .map((e) => DropdownMenuItem(
                                  value: e.id, child: Text(e.name)))
                              .toList(),
                          onChanged: (v) => setState(() => incl = v ?? 'N'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: dedTds,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Deduct TDS',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: kDedTDSData
                        .map((e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)))
                        .toList(),
                    onChanged: (v) => setState(() => dedTds = v ?? 'false'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple searchable account picker — mirrors the ng-select for AccountData
class _AccountPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  const _AccountPickerDialog({required this.accounts});

  @override
  State<_AccountPickerDialog> createState() => _AccountPickerDialogState();
}

class _AccountPickerDialogState extends State<_AccountPickerDialog> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.accounts.where((a) {
      final name = (a['AcName'] ?? a['Name'] ?? '').toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search account...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final acc = filtered[index];
                  return ListTile(
                    dense: true,
                    title: Text(acc['AcName'] ?? acc['Name'] ?? ''),
                    onTap: () => Navigator.pop(context, acc),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}