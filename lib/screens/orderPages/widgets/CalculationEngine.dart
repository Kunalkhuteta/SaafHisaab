// CalculationEngine.dart

class TaxAmtResult {
  final List<Map<String, dynamic>> sidtl;
  final double cgstAmt;
  final double sgstAmt;
  final double igstAmt;
  final double gstCessAmt;
  final double taxOnAmt;
  final double incAmt;
  final double extraAmt;

  TaxAmtResult({
    required this.sidtl,
    required this.cgstAmt,
    required this.sgstAmt,
    required this.igstAmt,
    required this.gstCessAmt,
    required this.taxOnAmt,
    required this.incAmt,
    required this.extraAmt,
  });
}

class CalcFlagAmtResult {
  final double amount;
  CalcFlagAmtResult({required this.amount});
}

class CalcSuccessAmtResult {
  final List<Map<String, dynamic>> sidtl;
  final double incAmt;
  final double successAmt;
  final double pSuccessAmt;
  final double prevAmt;

  CalcSuccessAmtResult({
    required this.sidtl,
    required this.incAmt,
    required this.successAmt,
    required this.pSuccessAmt,
    required this.prevAmt,
  });
}

class CalculationEngine {
  // ── Internal rounding helper ──────────────────────────────────────────────
  static double _round2(double v) =>
      double.parse(v.toStringAsFixed(2));

  static double _applyRounding(double amount, double rndBy, String rndType) {
    if (rndBy <= 0) return _round2(amount);
    switch (rndType) {
      case 'H':
        return (amount / rndBy).ceil() * rndBy;
      case 'L':
        return (amount / rndBy).floor() * rndBy;
      case 'N':
      default:
        return (amount / rndBy).round() * rndBy;
    }
  }

  /// Mirrors global.RoundBy()
  static double roundBy(double amount, double rndBy, String rndType) {
    if (rndBy == 0) return _round2(amount);
    final double factor = amount / rndBy;
    double rounded;
    switch (rndType) {
      case 'H':
        rounded = factor.ceil().toDouble();
        break;
      case 'L':
        rounded = factor.floor().toDouble();
        break;
      default:
        rounded = factor.roundToDouble();
        break;
    }
    return _round2(rounded * rndBy);
  }

  // ── CalcFlagAmt ───────────────────────────────────────────────────────────
  /// Mirrors global.CalcFlagAmt()
  /// Computes a single SIDtl row's Amount from CalcFlag + Rate.
  static CalcFlagAmtResult calcFlagAmt({
    required double mBag,
    required double mQty,
    required double mCalcRate,
    required String f,
    required double mBasicAmt,
    required double mSuccessiveAmt,
    required double pSuccessiveAmt,
    required double mPrevAmt,
    required double mAmount,
    required double mRndBy,
    required String mRndType,
    required double mCalcOnAmt,
    double mBHRAddSelfStockAmt = 0,
    double mITWeight = 0,
    int mNoOfBHR = 1,
  }) {
    double amount = 0;

    switch (f) {
      case 'F': // Fixed Amount
        amount = mCalcRate;
        break;
      case 'B': // % of Basic Amount
        amount = (mBasicAmt * mCalcRate) / 100;
        break;
      case 'G': // % of Gross Amount (successive)
        amount = (mSuccessiveAmt * mCalcRate) / 100;
        break;
      case 'H': // % of Gross Chargeable Amount
        amount = (mSuccessiveAmt * mCalcRate) / 100;
        break;
      case 'R': // % of Prev. GrossAmt
        amount = (pSuccessiveAmt * mCalcRate) / 100;
        break;
      case 'S': // % of Prev. GrossChgAmt
        amount = (pSuccessiveAmt * mCalcRate) / 100;
        break;
      case 'N': // % of Prev. Amount
        amount = (mPrevAmt * mCalcRate) / 100;
        break;
      case 'C': // Per Nag (Bag)
        amount = mBag * mCalcRate;
        break;
      case 'V': // Per Qty
        amount = mQty * mCalcRate;
        break;
      case 'W': // Per Quintal (Weight) — qty/100 * rate
        amount = (mQty / 100) * mCalcRate;
        break;
      case 'A': // % of Chargeable Amt of Account
        amount = (mCalcOnAmt * mCalcRate) / 100;
        break;
      case 'J': // % of Assessable Amt of Chargeable
        amount = (mCalcOnAmt * mCalcRate) / 100;
        break;
      case 'Q': // Packing Basis — per bag
        amount = mBag * mCalcRate;
        break;
      case 'E': // Enterable — user enters Amount directly, keep as-is
        amount = mAmount;
        break;
      default:
        amount = 0;
    }

    amount = _applyRounding(amount, mRndBy, mRndType);
    return CalcFlagAmtResult(amount: amount);
  }

  // ── CalcSuccessAmt ────────────────────────────────────────────────────────
  /// Mirrors global.CalcSuccessAmt()
  ///
  /// Iterates SIDtl rows in order and computes each row's Amount
  /// sequentially, threading mSuccessAmt / pSuccessAmt / mPrevAmt forward.
  ///
  /// Key rules (matching Angular):
  ///   - If EditAmt==true AND updateEditAmt==false → keep existing Amount,
  ///     but still use it for successive-amount threading.
  ///   - Only non-'L' (Self/Chrble=='L') rows contribute to mSuccessAmt.
  ///   - incAmt accumulates rows with Incl=='I' or 'P'.
  static CalcSuccessAmtResult calcSuccessAmt({
    required int mSNo,
    required double mBasicAmt,
    required double mGrossAmt,
    required double cBag,
    required double cQty,
    required List<Map<String, dynamic>> sidtl,
    bool updateEditAmt = false,
  }) {
    // Deep-copy so we never mutate the caller's list
    final List<Map<String, dynamic>> result =
        sidtl.map((e) => Map<String, dynamic>.from(e)).toList();

    double mSuccessAmt = mBasicAmt;
    double pSuccessAmt = mBasicAmt;
    double mPrevAmt = 0;
    double incAmt = mBasicAmt;

    for (int i = 0; i < result.length; i++) {
      final row = result[i];
      final bool editAmt = row['EditAmt'] == true;
      final String calcFlag = (row['CalcFlag'] ?? 'F').toString();
      final double rate = (row['Rate'] as num?)?.toDouble() ?? 0;
      final double rndBy = (row['RndBy'] as num?)?.toDouble() ?? 0.01;
      final String rndType = (row['RndType'] ?? 'N').toString();
      final double calcOnAmt = (row['CalcOnAmt'] as num?)?.toDouble() ?? 0;
      final String chrble = (row['Chrble'] ?? 'B').toString();
      final String incl = (row['Incl'] ?? 'N').toString();

      double amount = (row['Amount'] as num?)?.toDouble() ?? 0;

      // Recompute if not user-edited (or forced via updateEditAmt)
      if (!editAmt || updateEditAmt) {
        final calcResult = calcFlagAmt(
          mBag: cBag,
          mQty: cQty,
          mCalcRate: rate,
          f: calcFlag,
          mBasicAmt: mBasicAmt,
          mSuccessiveAmt: mSuccessAmt,
          pSuccessiveAmt: pSuccessAmt,
          mPrevAmt: mPrevAmt,
          mAmount: amount,
          mRndBy: rndBy,
          mRndType: rndType,
          mCalcOnAmt: calcOnAmt,
        );
        amount = calcResult.amount;
        row['Amount'] = amount;
      }

      // Thread prev-amount forward (always use computed/kept amount)
      mPrevAmt = amount;

      // Only non-Self rows contribute to the successive gross amount
      if (chrble != 'L') {
        pSuccessAmt = mSuccessAmt;
        // Only non-edited rows (or forced) grow mSuccessAmt
        if (!editAmt || updateEditAmt) {
          mSuccessAmt += amount;
        }
      }

      // IncAmt: rows marked Incl='I' or 'P' are included in the invoice base
      if (incl == 'I' || incl == 'P') {
        incAmt += amount;
      }
    }

    return CalcSuccessAmtResult(
      sidtl: result,
      incAmt: _round2(incAmt),
      successAmt: _round2(mSuccessAmt),
      pSuccessAmt: _round2(pSuccessAmt),
      prevAmt: _round2(mPrevAmt),
    );
  }

  // ── CalcSTAmt_Mandi ───────────────────────────────────────────────────────
  /// Mirrors global.CalcSTAmt_Mandi()
  ///
  /// Reads the final SIDtl list and extracts:
  ///   CGSTAmt  — row with AccountId == 11
  ///   SGSTAmt  — row with AccountId == 12
  ///   IGSTAmt  — row with AccountId == 13
  ///   GSTCessAmt — row with AccountId == 14 (adjust if needed)
  ///   TaxOnAmt — basicAmtAfterDisc (amount on which tax is computed)
  ///   IncAmt   — basicAmtAfterDisc + sum of rows where Incl='I' or 'P'
  ///   ExtraAmt — basicAmtAfterDisc + sum of all non-Self (Chrble!='L') rows
  static Map<String, double> calcSTAmtMandi({
    required List<Map<String, dynamic>> sidtl,
    required Map<String, dynamic>? taxItem,
    required List<Map<String, dynamic>> accountData,
    required double basicAmtAfterDisc,
  }) {
    const int cgstAccId = 11;
    const int sgstAccId = 12;
    const int igstAccId = 13;
    const int cessAccId = 14;

    double cgstAmt = 0;
    double sgstAmt = 0;
    double igstAmt = 0;
    double gstCessAmt = 0;
    double incAmt = basicAmtAfterDisc;
    double extraAmt = basicAmtAfterDisc;

    // TaxOnAmt = sum of non-tax overhead rows before the first tax row,
    // where EditAmt==false, plus basicAmt. Computed by getTaxOnAmount().
    final double taxOnAmt = getTaxOnAmount(
      sidtl: sidtl,
      basicAmt: basicAmtAfterDisc,
    );

    for (final row in sidtl) {
      final int accId = (row['AccountId'] as num?)?.toInt() ?? 0;
      final double amt = (row['Amount'] as num?)?.toDouble() ?? 0;
      final String inclFlag = (row['Incl'] ?? 'N').toString();
      final String chrble = (row['Chrble'] ?? 'B').toString();

      // Extract tax amounts by well-known account ids
      switch (accId) {
        case cgstAccId:
          cgstAmt = amt;
          break;
        case sgstAccId:
          sgstAmt = amt;
          break;
        case igstAccId:
          igstAmt = amt;
          break;
        case cessAccId:
          gstCessAmt = amt;
          break;
      }

      // IncAmt: rows with Incl='I' or 'P'
      if (inclFlag == 'I' || inclFlag == 'P') {
        incAmt += amt;
      }

      // ExtraAmt: all rows that are not Self (Chrble != 'L')
      if (chrble != 'L') {
        extraAmt += amt;
      }
    }

    return {
      'CGSTAmt': _round2(cgstAmt),
      'SGSTAmt': _round2(sgstAmt),
      'IGSTAmt': _round2(igstAmt),
      'GSTCessAmt': _round2(gstCessAmt),
      'TaxOnAmt': _round2(taxOnAmt),
      'IncAmt': _round2(incAmt),
      'ExtraAmt': _round2(extraAmt),
    };
  }

  // ── getTaxOnAmount ────────────────────────────────────────────────────────
  /// Mirrors getTaxOnAmount() in the Angular overhead component.
  ///
  /// TaxOnAmt = basicAmt + sum of all non-edited rows that appear
  /// BEFORE the first tax-account row (AccountId 11, 12, or 13).
  static double getTaxOnAmount({
    required List<Map<String, dynamic>> sidtl,
    required double basicAmt,
  }) {
    const taxAccIds = {11, 12, 13};

    int firstTaxIndex = sidtl.indexWhere(
      (e) => taxAccIds.contains((e['AccountId'] as num?)?.toInt() ?? 0),
    );
    if (firstTaxIndex == -1) firstTaxIndex = sidtl.length;

    double taxOnAmt = basicAmt;
    for (int i = 0; i < firstTaxIndex; i++) {
      if (sidtl[i]['EditAmt'] != true) {
        taxOnAmt += (sidtl[i]['Amount'] as num?)?.toDouble() ?? 0;
      }
    }

    return _round2(taxOnAmt);
  }

  // ── stampTaxRates ─────────────────────────────────────────────────────────
  /// Stamps correct CGST/SGST/IGST rates onto SIDtl rows based on
  /// isInterStateParty — does NOT recompute amounts.
  /// Used in CalculationDetailDialog._initialiseTaxTypeRate() to pre-fill
  /// rates before calling _runCalcSuccessAmt().
  static List<Map<String, dynamic>> stampTaxRates({
    required List<Map<String, dynamic>> sidtl,
    required Map<String, dynamic>? taxItem,
    required bool isInterStateParty,
  }) {
    if (taxItem == null) {
      return sidtl.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    final double cgstRate =
        (taxItem['TXCgstRate'] as num?)?.toDouble() ?? 0;
    final double sgstRate =
        (taxItem['TXSgstRate'] as num?)?.toDouble() ?? 0;
    final double igstRate =
        (taxItem['TXIgstRate'] as num?)?.toDouble() ?? 0;

    return sidtl.map((row) {
      final updated = Map<String, dynamic>.from(row);
      final int accId = (updated['AccountId'] as num?)?.toInt() ?? 0;
      if (accId == 11) {
        // CGST — only for intrastate
        updated['Rate'] = isInterStateParty ? 0.0 : cgstRate;
      } else if (accId == 12) {
        // SGST — only for intrastate
        updated['Rate'] = isInterStateParty ? 0.0 : sgstRate;
      } else if (accId == 13) {
        // IGST — only for interstate
        updated['Rate'] = isInterStateParty ? igstRate : 0.0;
      }
      return updated;
    }).toList();
  }

  // ── computeTaxAmounts ─────────────────────────────────────────────────────
  /// Main entry point called from CalculationDetailDialog._onDone().
  ///
  /// Mirrors the full getTaxAmt() pass in Angular:
  ///   Step 1 — Deep-copy SIDtl
  ///   Step 2 — Stamp correct CGST/SGST/IGST rates (zero out amounts on
  ///             non-edited tax rows so they are recomputed cleanly)
  ///   Step 3 — Recompute all row amounts via calcSuccessAmt
  ///   Step 4 — Extract CGST/SGST/IGST/Cess via calcSTAmtMandi
  ///   Step 5 — Guard: IGST and CGST+SGST must never both be non-zero
  static TaxAmtResult computeTaxAmounts({
    required List<Map<String, dynamic>> sidtl,
    required Map<String, dynamic>? taxItem,
    required List<Map<String, dynamic>> accountData,
    required double basicAmtAfterDisc,
    required double cBag,
    required double cQty,
    required bool isInterStateParty,
    bool updateEditAmt = false,
  }) {
    // ── Step 1: Deep-copy ─────────────────────────────────────────────────
    List<Map<String, dynamic>> working =
        sidtl.map((e) => Map<String, dynamic>.from(e)).toList();

    // ── Step 2: Stamp correct tax rates, zero out non-edited tax amounts ──
    if (taxItem != null) {
      final double cgstRate =
          (taxItem['TXCgstRate'] as num?)?.toDouble() ?? 0;
      final double sgstRate =
          (taxItem['TXSgstRate'] as num?)?.toDouble() ?? 0;
      final double igstRate =
          (taxItem['TXIgstRate'] as num?)?.toDouble() ?? 0;

      for (final row in working) {
        final int accId = (row['AccountId'] as num?)?.toInt() ?? 0;
        final bool editAmt = row['EditAmt'] == true;

        if (accId == 11) {
          row['Rate'] = isInterStateParty ? 0.0 : cgstRate;
          if (!editAmt) row['Amount'] = 0.0;
        } else if (accId == 12) {
          row['Rate'] = isInterStateParty ? 0.0 : sgstRate;
          if (!editAmt) row['Amount'] = 0.0;
        } else if (accId == 13) {
          row['Rate'] = isInterStateParty ? igstRate : 0.0;
          if (!editAmt) row['Amount'] = 0.0;
        }
      }
    }

    // ── Step 3: Recompute all row amounts ─────────────────────────────────
    final calcResult = calcSuccessAmt(
      mSNo: 0,
      mBasicAmt: basicAmtAfterDisc,
      mGrossAmt: basicAmtAfterDisc,
      cBag: cBag,
      cQty: cQty,
      sidtl: working,
      updateEditAmt: updateEditAmt,
    );
    working = calcResult.sidtl;

    // ── Step 4: Extract CGST/SGST/IGST via calcSTAmtMandi ────────────────
    final stData = calcSTAmtMandi(
      sidtl: working,
      taxItem: taxItem,
      accountData: accountData,
      basicAmtAfterDisc: basicAmtAfterDisc,
    );

    double cgstAmt    = stData['CGSTAmt']    ?? 0;
    double sgstAmt    = stData['SGSTAmt']    ?? 0;
    double igstAmt    = stData['IGSTAmt']    ?? 0;
    double gstCessAmt = stData['GSTCessAmt'] ?? 0;
    double taxOnAmt   = stData['TaxOnAmt']   ?? 0;
    double incAmt     = stData['IncAmt']     ?? 0;
    double extraAmt   = stData['ExtraAmt']   ?? 0;

    // ── Step 5: Guard — IGST and CGST+SGST must never both be non-zero ───
    final double cgstPlusSgst = cgstAmt + sgstAmt;
    if (igstAmt != 0 && cgstPlusSgst != 0) {
      if (isInterStateParty) {
        cgstAmt = 0;
        sgstAmt = 0;
        // Also zero out in working SIDtl
        for (final row in working) {
          final int accId = (row['AccountId'] as num?)?.toInt() ?? 0;
          if (accId == 11 || accId == 12) row['Amount'] = 0.0;
        }
      } else {
        igstAmt = 0;
        for (final row in working) {
          final int accId = (row['AccountId'] as num?)?.toInt() ?? 0;
          if (accId == 13) row['Amount'] = 0.0;
        }
      }
    }

    return TaxAmtResult(
      sidtl: working,
      cgstAmt: _round2(cgstAmt),
      sgstAmt: _round2(sgstAmt),
      igstAmt: _round2(igstAmt),
      gstCessAmt: _round2(gstCessAmt),
      taxOnAmt: _round2(taxOnAmt),
      incAmt: _round2(incAmt),
      extraAmt: _round2(extraAmt),
    );
  }
  /// Mirrors Angular's CheckTaxCondition(), scoped to ONE item. Returns ''
  /// when the item's GST is fine, otherwise the same wording Angular uses.
  /// Designed to be called either per-item (live warning on the card) or
  /// looped at save-time (first failure blocks the save, same as Angular).
  static String checkItemTaxCondition({
    required String itemName,
    required double txIgstRate,
    required double txCgstRate,
    required double txSgstRate,
    required String txCode,
    required double igstAmt,
    required double cgstAmt,
    required double sgstAmt,
    required double taxOnAmt,
    required bool isInterStateParty,
    double tolerance = 1.0,
  }) {
    final double totalTaxRate = txIgstRate + txCgstRate + txSgstRate;
    final double totalTaxAmount = igstAmt + cgstAmt + sgstAmt;

    if (totalTaxRate > 0 && totalTaxAmount == 0) {
      return "On Item $itemName, Tax Amount Can't Be Zero. While having Tax Type $txCode";
    }
    if (totalTaxRate == 0 && totalTaxAmount > 0) {
      return "On Item $itemName, Tax Will Not Be Applicable. While having Tax Type $txCode";
    }
    if (totalTaxRate > 0) {
      if (igstAmt == 0 && (cgstAmt == 0 || sgstAmt == 0)) {
        return "On Item $itemName, Invalid Tax Calculated. While having Tax Type $txCode";
      }

      // Stand-in for Angular's StockDtl.isWrongTaxCalculated — confirms the
      // amounts actually correspond to this tax type's rates for the
      // party's interstate status, within rounding tolerance. If you
      // already compute a real isWrongTaxCalculated flag elsewhere, pass
      // it into checkAllItemsTaxCondition instead of relying on this.
      final bool wrongTaxCalculated = isInterStateParty
          ? (cgstAmt != 0 ||
              sgstAmt != 0 ||
              (igstAmt - (taxOnAmt * txIgstRate / 100)).abs() > tolerance)
          : (igstAmt != 0 ||
              (cgstAmt - (taxOnAmt * txCgstRate / 100)).abs() > tolerance ||
              (sgstAmt - (taxOnAmt * txSgstRate / 100)).abs() > tolerance);

      if (wrongTaxCalculated) {
        return "On Item $itemName, Invalid Tax Calculated. While having Tax Type $txCode the calculated tax is not according to taxtype in one of the IGST/CGST/SGST Rate";
      }
    }
    return '';
  }
}

// ── Display label lookup tables ───────────────────────────────────────────────

class CalcFlagOption {
  final String id;
  final String name;
  const CalcFlagOption(this.id, this.name);
}

const List<CalcFlagOption> kCalcFlagData = [
  CalcFlagOption('F', 'Fixed Amount'),
  CalcFlagOption('B', '% of Basic Amount'),
  CalcFlagOption('G', '% of Gross Amount'),
  CalcFlagOption('H', '% of Gross ChgAmt'),
  CalcFlagOption('R', '% of Prev. GrossAmt'),
  CalcFlagOption('S', '% of Prev. GrossChgAmt'),
  CalcFlagOption('C', 'Per Nag'),
  CalcFlagOption('V', 'Per Qty'),
  CalcFlagOption('W', 'Per Qntl(Weight)'),
  CalcFlagOption('N', '% of Prev. Amount'),
  CalcFlagOption('A', '% of ChargbleAmt of Account'),
  CalcFlagOption('J', '% OF Assable Amt of Chargeable'),
  CalcFlagOption('Q', 'Packing Basis'),
  CalcFlagOption('E', 'Enterable'),
];

const List<CalcFlagOption> kChrbleAmount = [
  CalcFlagOption('B', 'Buyer'),
  CalcFlagOption('S', 'Seller'),
  CalcFlagOption('L', 'Self'),
];

const List<CalcFlagOption> kInclData = [
  CalcFlagOption('N', 'Do Not Include'),
  CalcFlagOption('I', 'Incl. in Basic'),
  CalcFlagOption('P', 'Incl. & Print'),
];

const List<CalcFlagOption> kDedTDSData = [
  CalcFlagOption('true', 'Yes'),
  CalcFlagOption('false', 'No'),
];

String getCalcUnitName(String id) => kCalcFlagData
    .firstWhere((e) => e.id == id, orElse: () => const CalcFlagOption('', ''))
    .name;

String getChrbleName(String id) => kChrbleAmount
    .firstWhere((e) => e.id == id, orElse: () => const CalcFlagOption('', ''))
    .name;

String getInclName(String id) => kInclData
    .firstWhere((e) => e.id == id, orElse: () => const CalcFlagOption('', ''))
    .name;

String getDedTDSName(dynamic value) {
  final String id =
      (value == true || value == 'true') ? 'true' : 'false';
  return kDedTDSData
      .firstWhere((e) => e.id == id, orElse: () => const CalcFlagOption('', ''))
      .name;
}