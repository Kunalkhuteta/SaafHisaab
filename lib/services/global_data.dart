class SysParamAccountData {
  final bool useMultiAddressFeature;
  SysParamAccountData({this.useMultiAddressFeature = false});
}

class GlobalData {
  static final GlobalData _instance = GlobalData._internal();

  factory GlobalData() {
    return _instance;
  }

  GlobalData._internal();

  String? shopId;
  String? userId;
  int? coSoftId = 1;
  int? CofinYear = 2026;
  int? divId = 1;
  int? StateId = 1; // default company/shop state ID
  int? clientRegId = 1;
  int? mobileAppUserId = 1;
  String? companyStateCode = '07'; // Standard state code (Delhi)
  bool? CommonSalesOrder = false;

  SysParamAccountData? sysParamAccountData = SysParamAccountData();
}
