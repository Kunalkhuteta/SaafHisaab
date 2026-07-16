import 'package:saafhisaab/screens/orderPages/salesPurchaseOrderClass.dart';
import 'package:saafhisaab/screens/orderPages/salesPurchaseOrderDetails.dart';

class AllOrdHdrDtl {
  final ORDHDRRecord orderHdr;
  final List<OrdDtlRecord> orderDtl;

  AllOrdHdrDtl({required this.orderHdr, required this.orderDtl});

  Map<String, dynamic> toJson() {
    return {
      "OrderHdr": orderHdr.toJson(),
      "OrderDtl": orderDtl.map((e) => e.toJson()).toList(),
    };
  }
}