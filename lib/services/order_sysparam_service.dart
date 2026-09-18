import 'dart:async';

class OrderSysParamService {
  static final OrderSysParamService _instance = OrderSysParamService._internal();
  factory OrderSysParamService() => _instance;
  OrderSysParamService._internal();

  bool brokerWiseOrders = false;

  Future<void> getOrderSysParams({String? srFlag}) async {
    brokerWiseOrders = false;
  }
}
