// createSalesOrderModel.dart
//
// Changes vs previous version:
//   • Added `stock2Rows` field to OrderItem — stores serialised Stock2Dtl rows
//     (List<Map<String,dynamic>> with keys STBag, WtPerBag, STQty).
//     Mirrors Angular StockRecordFromAngular.Stock2 / Stock2Dtl[].
//   • Added `stock2Rows` to constructor, copyWith, toJson, fromJson, toStockDtl.

// ─────────────────────────────────────────────────────────────────────────────
// OrderItem
// ─────────────────────────────────────────────────────────────────────────────
class OrderItem {
  final int itemId;
  final String itemName;
  final int bag;
  final double qty;
  final double rate;
  final double tpRate;
  final double amount;
  final double weight;
  final double bardanaWeight;
  final int brandId;
  final String brandName;
  final int godownId;
  final String godownName;
  final String gdSlipNo;
  final double brokerageRate;
  final double minRate;
  final double discPrice;
  final int noOfPcs;
  final double pcsRate;
  final String remark;
  final String itemDesc;
  final String calUnit;
  final String valUnit;
  final String rateUnit;
  final int itemGroupId;
  final String itemGroupName;

  // Overhead / tax amounts — populated by CalculationDetailDialog
  final List<Map<String, dynamic>> siDtl;
  final double totalOverHead;
  final double cgstAmt;
  final double sgstAmt;
  final double igstAmt;
  final double gstCessAmt;
  final double taxOnAmt;
  final double incAmt;
  final double extraAmt;

  // Tax metadata
  final int taxId;
  final String taxCode;
  final double taxCgstRate;
  final double taxSgstRate;
  final double taxIgstRate;

  // Method
  final int methodId;

  // ── Stock2 (bag-wise weight rows) ─────────────────────────────────────────
  // Each map: { 'STBag': double, 'WtPerBag': double, 'STQty': double }
  // Mirrors Angular StockRecordFromAngular.Stock2 / Stock2Dtl[]
  final List<Map<String, dynamic>> stock2Rows;

  // ── Computed getters ──────────────────────────────────────────────────────

  /// Item amount + all overhead/extra charges.
  /// Mirrors Angular: TotalStAmount + TotalSTExtraAmt
  /// = StockDtl.Amount + StockDtl.ExtraAmt (which includes overhead line items)
  double get netAmountWithOverhead => amount + extraAmt;

  /// Total GST amount (CGST + SGST + IGST).
  /// Mirrors Angular: TotalSTTaxAmt = SGSTAmt + CGSTAmt + IGSTAmt
  double get totalGstAmt => cgstAmt + sgstAmt + igstAmt;

  /// Net invoice amount for this line: base + overhead + GST.
  /// Mirrors Angular: InvAmount line contribution
  double get lineInvAmt => netAmountWithOverhead + totalGstAmt + gstCessAmt;

  const OrderItem({
    required this.itemId,
    required this.itemName,
    required this.bag,
    required this.qty,
    required this.rate,
    this.tpRate = 0,
    required this.amount,
    this.weight = 0,
    this.bardanaWeight = 0,
    this.brandId = 0,
    this.brandName = '',
    this.godownId = 0,
    this.godownName = '',
    this.gdSlipNo = '',
    this.brokerageRate = 0,
    this.minRate = 0,
    this.discPrice = 0,
    this.noOfPcs = 0,
    this.pcsRate = 0,
    this.remark = '',
    this.itemDesc = '',
    this.calUnit = 'Bag',
    this.valUnit = 'Qty',
    this.rateUnit = 'Unit',
    this.itemGroupId = 0,
    this.itemGroupName = '',
    this.siDtl = const [],
    this.totalOverHead = 0,
    this.cgstAmt = 0,
    this.sgstAmt = 0,
    this.igstAmt = 0,
    this.gstCessAmt = 0,
    this.taxOnAmt = 0,
    this.incAmt = 0,
    this.extraAmt = 0,
    this.taxId = 0,
    this.taxCode = '',
    this.taxCgstRate = 0,
    this.taxSgstRate = 0,
    this.taxIgstRate = 0,
    this.methodId = 0,
    // ── NEW ──────────────────────────────────────────────────────────────────
    this.stock2Rows = const [],
  });

  // ── copyWith ──────────────────────────────────────────────────────────────
  OrderItem copyWith({
    int? itemId,
    String? itemName,
    int? bag,
    double? qty,
    double? rate,
    double? tpRate,
    double? amount,
    double? weight,
    double? bardanaWeight,
    int? brandId,
    String? brandName,
    int? godownId,
    String? godownName,
    String? gdSlipNo,
    double? brokerageRate,
    double? minRate,
    double? discPrice,
    int? noOfPcs,
    double? pcsRate,
    String? remark,
    String? itemDesc,
    String? calUnit,
    String? valUnit,
    String? rateUnit,
    int? itemGroupId,
    String? itemGroupName,
    List<Map<String, dynamic>>? siDtl,
    double? totalOverHead,
    double? cgstAmt,
    double? sgstAmt,
    double? igstAmt,
    double? gstCessAmt,
    double? taxOnAmt,
    double? incAmt,
    double? extraAmt,
    int? taxId,
    String? taxCode,
    double? taxCgstRate,
    double? taxSgstRate,
    double? taxIgstRate,
    int? methodId,
    List<Map<String, dynamic>>? stock2Rows,
  }) {
    return OrderItem(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      bag: bag ?? this.bag,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      tpRate: tpRate ?? this.tpRate,
      amount: amount ?? this.amount,
      weight: weight ?? this.weight,
      bardanaWeight: bardanaWeight ?? this.bardanaWeight,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      godownId: godownId ?? this.godownId,
      godownName: godownName ?? this.godownName,
      gdSlipNo: gdSlipNo ?? this.gdSlipNo,
      brokerageRate: brokerageRate ?? this.brokerageRate,
      minRate: minRate ?? this.minRate,
      discPrice: discPrice ?? this.discPrice,
      noOfPcs: noOfPcs ?? this.noOfPcs,
      pcsRate: pcsRate ?? this.pcsRate,
      remark: remark ?? this.remark,
      itemDesc: itemDesc ?? this.itemDesc,
      calUnit: calUnit ?? this.calUnit,
      valUnit: valUnit ?? this.valUnit,
      rateUnit: rateUnit ?? this.rateUnit,
      itemGroupId: itemGroupId ?? this.itemGroupId,
      itemGroupName: itemGroupName ?? this.itemGroupName,
      siDtl: siDtl ?? this.siDtl,
      totalOverHead: totalOverHead ?? this.totalOverHead,
      cgstAmt: cgstAmt ?? this.cgstAmt,
      sgstAmt: sgstAmt ?? this.sgstAmt,
      igstAmt: igstAmt ?? this.igstAmt,
      gstCessAmt: gstCessAmt ?? this.gstCessAmt,
      taxOnAmt: taxOnAmt ?? this.taxOnAmt,
      incAmt: incAmt ?? this.incAmt,
      extraAmt: extraAmt ?? this.extraAmt,
      taxId: taxId ?? this.taxId,
      taxCode: taxCode ?? this.taxCode,
      taxCgstRate: taxCgstRate ?? this.taxCgstRate,
      taxSgstRate: taxSgstRate ?? this.taxSgstRate,
      taxIgstRate: taxIgstRate ?? this.taxIgstRate,
      methodId: methodId ?? this.methodId,
      stock2Rows: stock2Rows ?? this.stock2Rows,
    );
  }

  // ── toJson ────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'bag': bag,
      'qty': qty,
      'rate': rate,
      'tpRate': tpRate,
      'amount': amount,
      'weight': weight,
      'bardanaWeight': bardanaWeight,
      'brandId': brandId,
      'brandName': brandName,
      'godownId': godownId,
      'godownName': godownName,
      'gdSlipNo': gdSlipNo,
      'brokerageRate': brokerageRate,
      'minRate': minRate,
      'discPrice': discPrice,
      'noOfPcs': noOfPcs,
      'pcsRate': pcsRate,
      'remark': remark,
      'itemDesc': itemDesc,
      'calUnit': calUnit,
      'valUnit': valUnit,
      'rateUnit': rateUnit,
      'itemGroupId': itemGroupId,
      'itemGroupName': itemGroupName,
      'siDtl': siDtl,
      'totalOverHead': totalOverHead,
      'cgstAmt': cgstAmt,
      'sgstAmt': sgstAmt,
      'igstAmt': igstAmt,
      'gstCessAmt': gstCessAmt,
      'taxOnAmt': taxOnAmt,
      'incAmt': incAmt,
      'extraAmt': extraAmt,
      'taxId': taxId,
      'taxCode': taxCode,
      'taxCgstRate': taxCgstRate,
      'taxSgstRate': taxSgstRate,
      'taxIgstRate': taxIgstRate,
      'methodId': methodId,
      // ── NEW ────────────────────────────────────────────────────────────────
      'stock2Rows': stock2Rows,
    };
  }

  // ── fromJson ──────────────────────────────────────────────────────────────
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final stockDtlRaw = json['StockDtl'];
    final stockDtl = stockDtlRaw is Map
        ? Map<String, dynamic>.from(stockDtlRaw)
        : <String, dynamic>{};

    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key) && json[key] != null) return json[key];
        if (stockDtl.containsKey(key) && stockDtl[key] != null) {
          return stockDtl[key];
        }
      }
      return null;
    }

    int toInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    List<Map<String, dynamic>> castListOfMaps(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    return OrderItem(
      itemId: toInt(pick(['itemId', 'ItemId'])),
      itemName: (pick(['itemName', 'ItemName', 'Name']) ?? '').toString(),
      bag: toInt(pick(['bag', 'STBag', 'OrdBag'])),
      qty: toDouble(pick(['qty', 'STQty', 'OrdQty'])),
      rate: toDouble(pick(['rate', 'Rate', 'OrdRate'])),
      tpRate: toDouble(pick(['tpRate', 'STPRate', 'OrdSTPRate'])),
      amount: toDouble(pick(['amount', 'Amount'])),
      weight: toDouble(pick(['weight', 'Weight', 'GrossWeight'])),
      bardanaWeight: toDouble(pick(['bardanaWeight', 'BardanaWeight'])),
      brandId: toInt(pick(['brandId', 'BrandId'])),
      brandName: (pick(['brandName', 'BrandName']) ?? '').toString(),
      godownId: toInt(pick(['godownId', 'GodownId'])),
      godownName: (pick(['godownName', 'GodownName']) ?? '').toString(),
      gdSlipNo: (pick(['gdSlipNo', 'GdSlipNo']) ?? '').toString(),
      brokerageRate: toDouble(pick(['brokerageRate', 'BrRate'])),
      minRate: toDouble(pick(['minRate', 'OrdMinRate'])),
      discPrice: toDouble(pick(['discPrice', 'DiscPr', 'NetDisc'])),
      noOfPcs: toInt(pick(['noOfPcs', 'NoOfPcs'])),
      pcsRate: toDouble(pick(['pcsRate', 'PCSRate'])),
      remark: (pick(['remark', 'OrdRemark', 'Remark']) ?? '').toString(),
      itemDesc: (pick(['itemDesc', 'ItemDesc']) ?? '').toString(),
      calUnit: (pick(['calUnit', 'CalUnit']) ?? 'Bag').toString(),
      valUnit: (pick(['valUnit', 'ValUnit']) ?? 'Qty').toString(),
      rateUnit: (pick(['rateUnit', 'SOrdUnitName', 'RateUnit']) ?? 'Unit')
          .toString(),
      itemGroupId: toInt(pick(['itemGroupId', 'ItemGroupId', 'GroupId'])),
      itemGroupName:
          (pick(['itemGroupName', 'ItemGroupName', 'GroupName']) ?? '')
              .toString(),
      siDtl: castListOfMaps(json['siDtl'] ?? json['SIDtl']),
      totalOverHead: toDouble(pick(['totalOverHead', 'TotalOverHead'])),
      cgstAmt: toDouble(pick(['cgstAmt', 'CGSTAmt'])),
      sgstAmt: toDouble(pick(['sgstAmt', 'SGSTAmt'])),
      igstAmt: toDouble(pick(['igstAmt', 'IGSTAmt'])),
      gstCessAmt: toDouble(pick(['gstCessAmt', 'GSTCessAmt'])),
      taxOnAmt: toDouble(pick(['taxOnAmt', 'TaxOnAmt'])),
      incAmt: toDouble(pick(['incAmt', 'STIncAmt', 'IncAmt'])),
      extraAmt: toDouble(pick(['extraAmt', 'ExtraAmt'])),
      taxId: toInt(pick(['taxId', 'TaxId'])),
      taxCode: (pick(['taxCode', 'TaxCode', 'TXCode', 'HSNcode', 'HSNCode']) ??
              '')
          .toString(),
      taxCgstRate: toDouble(pick(['taxCgstRate', 'TXCgstRate'])),
      taxSgstRate: toDouble(pick(['taxSgstRate', 'TXSgstRate'])),
      taxIgstRate: toDouble(pick(['taxIgstRate', 'TXIgstRate'])),
      methodId: toInt(pick(['methodId', 'MethodId'])),
      stock2Rows: castListOfMaps(json['stock2Rows'] ?? json['Stock2']),
    );
  }
  // ── toStockDtl ────────────────────────────────────────────────────────────
  // Serialises this OrderItem into the StockDtl map that the Angular API
  // (AddEditData) expects inside InvoiceAllData.StockDtlList[].
  //
  // Stock2 rows are passed as-is; they map to StockRecordFromAngular.Stock2[]
  // which the backend expects alongside each StockDtl row.
  Map<String, dynamic> toStockDtl({
    required int irIdNo,        // InvTranidno (0 for new)
    required int seqNo,         // STISeqNo (1-based position in list)
    required String irSr,       // e.g. 'SIN'
    required int coSoftId,
    required int coFinYear,
    required int divId,
  }) {
    return {
      // ── StockDtl core ──────────────────────────────────────────────────
      'id': 0,
      'STIRIdNo': irIdNo,
      'STISeqNo': seqNo,
      'STSr': irSr,
      'ItemId': itemId,
      'STBag': bag,
      'STQty': qty,
      'STPRate': tpRate,
      'Rate': rate,
      'MethodId': methodId,
      'TaxId': taxId,
      'Amount': amount,
      'GodownId': godownId != 0 ? godownId : -2,
      'BrandId': brandId != 0 ? brandId : -8,
      'GdSlipNo': gdSlipNo.isNotEmpty ? gdSlipNo : '.',
      'ItemDesc': itemDesc,
      'BardanaWeight': bardanaWeight,
      'GrossWeight': weight,
      'DivId': divId,
      'ExtraAmt': extraAmt,
      'STIncAmt': incAmt,
      'OrdDtlId': 0,
      'STAccountId': -1,
      'StkFlag': 'S',
      'DiscPr': discPrice,
      'NetDisc': discPrice,
      'DiscType': '',
      'DiscAmt': 0,
      'CoSoftId': coSoftId,
      'CoFinyear': coFinYear,
      'TaxOnAmt': taxOnAmt,
      'SGSTAmt': sgstAmt,
      'CGSTAmt': cgstAmt,
      'IGSTAmt': igstAmt,
      'GSTCessAmt': gstCessAmt,
      'RSTBag': 0,
      'RSTQty': 0,
      'PlotId': 0,
      'BatchNo': '.',
      // ── SIDtl (overhead rows) ───────────────────────────────────────────
      'SIDtl': siDtl,
      // ── Stock2 (bag-wise weight rows) ───────────────────────────────────
      // Mirrors Angular StockRecordFromAngular.Stock2[]
      'Stock2': stock2Rows.map((r) => {
            'id': 0,
            'SNo': 0,
            'STSr': irSr,
            'STIRIdNo': irIdNo,
            'STISeqNo': seqNo,
            'STBag': (r['STBag'] as num?)?.toDouble() ?? 0,
            'WtPerBag': (r['WtPerBag'] as num?)?.toDouble() ?? 0,
            'STQty': (r['STQty'] as num?)?.toDouble() ?? 0,
            'CoSoftId': coSoftId,
            'CoFinyear': coFinYear,
            'Recstatus': 0,
          }).toList(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SalesOrder (header model — unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class SalesOrder {
  final int id;
  final int partyId;
  final String partyName;
  final String orderDate;
  final String orderSr;
  final int bookId;
  final String payMode;
  final int brokerId;
  final String brokerName;
  final int transportId;
  final String transportName;
  final int stationId;
  final String stationName;
  final String remark;
  final List<OrderItem> items;
  final double totalAmount;
  final double totalBag;
  final double totalQty;

  const SalesOrder({
    this.id = 0,
    required this.partyId,
    required this.partyName,
    required this.orderDate,
    required this.orderSr,
    this.bookId = 0,
    this.payMode = 'R',
    this.brokerId = 0,
    this.brokerName = '',
    this.transportId = 0,
    this.transportName = '',
    this.stationId = 0,
    this.stationName = '',
    this.remark = '',
    this.items = const [],
    this.totalAmount = 0,
    this.totalBag = 0,
    this.totalQty = 0,
  });

  SalesOrder copyWith({
    int? id,
    int? partyId,
    String? partyName,
    String? orderDate,
    String? orderSr,
    int? bookId,
    String? payMode,
    int? brokerId,
    String? brokerName,
    int? transportId,
    String? transportName,
    int? stationId,
    String? stationName,
    String? remark,
    List<OrderItem>? items,
    double? totalAmount,
    double? totalBag,
    double? totalQty,
  }) {
    return SalesOrder(
      id: id ?? this.id,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      orderDate: orderDate ?? this.orderDate,
      orderSr: orderSr ?? this.orderSr,
      bookId: bookId ?? this.bookId,
      payMode: payMode ?? this.payMode,
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      transportId: transportId ?? this.transportId,
      transportName: transportName ?? this.transportName,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      remark: remark ?? this.remark,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      totalBag: totalBag ?? this.totalBag,
      totalQty: totalQty ?? this.totalQty,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'partyId': partyId,
        'partyName': partyName,
        'orderDate': orderDate,
        'orderSr': orderSr,
        'bookId': bookId,
        'payMode': payMode,
        'brokerId': brokerId,
        'brokerName': brokerName,
        'transportId': transportId,
        'transportName': transportName,
        'stationId': stationId,
        'stationName': stationName,
        'remark': remark,
        'items': items.map((e) => e.toJson()).toList(),
        'totalAmount': totalAmount,
        'totalBag': totalBag,
        'totalQty': totalQty,
      };

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<OrderItem> parsedItems = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : [];

    return SalesOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      partyId: (json['partyId'] as num?)?.toInt() ?? 0,
      partyName: json['partyName']?.toString() ?? '',
      orderDate: json['orderDate']?.toString() ?? '',
      orderSr: json['orderSr']?.toString() ?? '',
      bookId: (json['bookId'] as num?)?.toInt() ?? 0,
      payMode: json['payMode']?.toString() ?? 'R',
      brokerId: (json['brokerId'] as num?)?.toInt() ?? 0,
      brokerName: json['brokerName']?.toString() ?? '',
      transportId: (json['transportId'] as num?)?.toInt() ?? 0,
      transportName: json['transportName']?.toString() ?? '',
      stationId: (json['stationId'] as num?)?.toInt() ?? 0,
      stationName: json['stationName']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
      items: parsedItems,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      totalBag: (json['totalBag'] as num?)?.toDouble() ?? 0,
      totalQty: (json['totalQty'] as num?)?.toDouble() ?? 0,
    );
  }
}