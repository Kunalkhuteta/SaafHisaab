import 'dart:async';

class SysparamCommon {
  final bool useSalesPerson;
  final bool useSalesRepresentative;
  final bool useSingleUnitOrder;
  final bool useMultiBrandSystem;
  final bool itGodownSystem;
  final bool siRateUnit;
  final bool siMinRate;
  final bool siPcsSystem;
  final bool siLocalTransport;
  final String defaultLableBrand;
  final bool mtItemWiseSeperateMethod;

  SysparamCommon({
    this.useSalesPerson = true,
    this.useSalesRepresentative = true,
    this.useSingleUnitOrder = false,
    this.useMultiBrandSystem = true,
    this.itGodownSystem = true,
    this.siRateUnit = true,
    this.siMinRate = true,
    this.siPcsSystem = true,
    this.siLocalTransport = true,
    this.defaultLableBrand = 'Brand',
    this.mtItemWiseSeperateMethod = true,
  });
}

class Sysparams {
  final bool siReadBroker;
  final SysparamCommon sysparamCommon;

  Sysparams({
    this.siReadBroker = true,
    SysparamCommon? sysparamCommon,
  }) : sysparamCommon = sysparamCommon ?? SysparamCommon();
}

class SysparamCachedData {
  final Sysparams sysparam;
  SysparamCachedData({required this.sysparam});
}

class SysparamService {
  static final SysparamService _instance = SysparamService._internal();
  factory SysparamService() => _instance;
  SysparamService._internal();

  SysparamCachedData? cachedData = SysparamCachedData(sysparam: Sysparams());

  Future<SysparamCachedData> getSysParams({dynamic globalData, int? clientRegId, int? coSoftId}) async {
    final data = SysparamCachedData(sysparam: Sysparams());
    cachedData = data;
    return data;
  }
}
