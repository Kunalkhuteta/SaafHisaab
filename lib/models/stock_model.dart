class StockItemModel {
  final String id;
  final String shopId;
  final String userId;
  final String itemName;
  final String category;
  final double currentQuantity;
  final String unit;
  final double buyingPrice;
  final double sellingPrice;
  final double lowStockAlert;
  final String supplierName;
  final String supplierPhone;
  final DateTime createdAt;

  StockItemModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.itemName,
    this.category = 'General',
    required this.currentQuantity,
    this.unit = 'piece',
    this.buyingPrice = 0,
    this.sellingPrice = 0,
    this.lowStockAlert = 5,
    this.supplierName = '',
    this.supplierPhone = '',
    required this.createdAt,
  });

  bool get isLowStock => currentQuantity <= lowStockAlert;

  double get profitPerUnit => sellingPrice - buyingPrice;

  factory StockItemModel.fromJson(Map<String, dynamic> json) {
    return StockItemModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      userId: json['user_id'] ?? '',
      itemName: json['item_name'] ?? '',
      category: json['category'] ?? 'General',
      currentQuantity: (json['current_quantity'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'piece',
      buyingPrice: (json['buying_price'] ?? 0).toDouble(),
      sellingPrice: (json['selling_price'] ?? 0).toDouble(),
      lowStockAlert: (json['low_stock_alert'] ?? 5).toDouble(),
      supplierName: json['supplier_name'] ?? '',
      supplierPhone: json['supplier_phone'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'user_id': userId,
      'item_name': itemName,
      'category': category,
      'current_quantity': currentQuantity,
      'unit': unit,
      'buying_price': buyingPrice,
      'selling_price': sellingPrice,
      'low_stock_alert': lowStockAlert,
      'supplier_name': supplierName,
      'supplier_phone': supplierPhone,
    };
  }
}