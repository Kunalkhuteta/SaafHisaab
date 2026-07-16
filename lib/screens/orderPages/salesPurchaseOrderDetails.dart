class OrdDtlRecord {
  int? id;
  int? oHId;
  String ordSR;
  int itemId;
  int godownId;
  String gdSlipNo;
  int brandId;
  double ordQty;
  int ordBag;
  int soldQty;
  int cancelQty;
  int soldBag;
  int cancelBag;
  double ordRate;
  double brRate;
  double ordSTPRate; // Tax Paid Rate
  String ordRemark;
  String itemDesc;
  double amount;
  int coSoftId;
  bool issue;
  double ordMinRate;
  double weight;
  double pcsRate;
  int noOfPcs;
  dynamic divId;

  OrdDtlRecord({
    this.id,
    this.oHId,
    required this.ordSR,
    required this.itemId,
    this.godownId = 0,
    this.gdSlipNo = '',
    this.brandId = 0,
    required this.ordQty,
    required this.ordBag,
    this.soldQty = 0,
    this.cancelQty = 0,
    this.soldBag = 0,
    this.cancelBag = 0,
    required this.ordRate,
    this.brRate = 0,
    this.ordSTPRate = 0,
    required this.ordRemark,
    this.itemDesc = '',
    required this.amount,
    required this.coSoftId,
    this.issue = false,
    this.ordMinRate = 0,
    this.weight = 0,
    this.pcsRate = 0,
    this.noOfPcs = 0,
    required this.divId,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) "id": id,
        if (oHId != null) "OHId": oHId,
        "OrdSR": ordSR,
        "ItemId": itemId,
        "GodownId": godownId,
        "GdSlipNo": gdSlipNo,
        "BrandId": brandId,
        "OrdQty": ordQty,
        "OrdBag": ordBag,
        "SoldQty": soldQty,
        "CancelQty": cancelQty,
        "SoldBag": soldBag,
        "CancelBag": cancelBag,
        "OrdRate": ordRate,
        "BrRate": brRate,
        "OrdSTPRate": ordSTPRate,
        "OrdRemark": ordRemark,
        "ItemDesc": itemDesc,
        "Amount": amount,
        "CoSoftId": coSoftId,
        "Issue": issue,
        "OrdMinRate": ordMinRate,
        "Weight": weight,
        "PCSRate": pcsRate,
        "NoOfPcs": noOfPcs,
        "DivId": divId,
      };
}
