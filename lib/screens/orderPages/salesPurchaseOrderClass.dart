class ORDHDRRecord {
  int? id;
  String ordSR;
  int ordSeqNo;
  DateTime ordDate;
  int ptAccountId;
  int dlAccountId;
  int spId;
  int salesRepresentative;
  int transportId;
  String refNo;
  DateTime refDate;
  String delvMode;
  String pymtMode;
  String remark;
  DateTime delvDateFrom;
  DateTime delvDateTo;
  int coSoftId;
  int coFinyear;
  int userId;
  int divId;

  ORDHDRRecord({
    this.id,
    required this.ordSR,
    required this.ordSeqNo,
    required this.ordDate,
    required this.ptAccountId,
    required this.dlAccountId,
    required this.spId,
    this.salesRepresentative = 0,
    required this.transportId,
    required this.refNo,
    required this.refDate,
    required this.delvMode,
    required this.pymtMode,
    required this.remark,
    required this.delvDateFrom,
    required this.delvDateTo,
    required this.coSoftId,
    required this.coFinyear,
    required this.userId,
    required this.divId,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) "id": id,
        "OrdSR": ordSR,
        "OrdSeqNo": ordSeqNo,
        "OrdDate": ordDate.toIso8601String(),
        "PtAccountId": ptAccountId,
        "DLAccountId": dlAccountId,
        "SPId": spId,
        "SalesRepresentative": salesRepresentative,
        "TransportId": transportId,
        "RefNo": refNo,
        "RefDate": refDate.toIso8601String(),
        "DelvMode": delvMode,
        "PymtMode": pymtMode,
        "Remark": remark,
        "DelvDateFrom": delvDateFrom.toIso8601String(),
        "DelvDateTo": delvDateTo.toIso8601String(),
        "CoSoftId": coSoftId,
        "CoFinyear": coFinyear,
        "UserId": userId,
        "DivId": divId,
      };
}
