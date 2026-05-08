class SaleModel {
  final String id;
  final String shopId;
  final String userId;
  final String itemName;
  final double quantity;
  final String unit;
  final double sellingPrice;
  final double totalAmount;
  final String paymentMode;
  final String category;
  final String? billId;
  final DateTime saleDate;
  final String notes;
  final DateTime createdAt;

  SaleModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.itemName,
    this.quantity = 1,
    this.unit = 'piece',
    required this.sellingPrice,
    required this.totalAmount,
    this.paymentMode = 'cash',
    this.category = 'General',
    this.billId,
    required this.saleDate,
    this.notes = '',
    required this.createdAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      userId: json['user_id'] ?? '',
      itemName: json['item_name'] ?? '',
      quantity: (json['quantity'] ?? 1).toDouble(),
      unit: json['unit'] ?? 'piece',
      sellingPrice: (json['selling_price'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      paymentMode: json['payment_mode'] ?? 'cash',
      category: json['category'] ?? 'General',
      billId: json['bill_id'],
      saleDate: DateTime.parse(json['sale_date']),
      notes: json['notes'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'user_id': userId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'selling_price': sellingPrice,
      'total_amount': totalAmount,
      'payment_mode': paymentMode,
      'category': category,
      'bill_id': billId,
      'sale_date': saleDate.toIso8601String().split('T')[0],
      'notes': notes,
    };
  }
}