class UdharCustomerModel {
  final String id;
  final String shopId;
  final String userId;
  final String customerName;
  final String customerPhone;
  final double totalDue;
  final DateTime createdAt;

  UdharCustomerModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.customerName,
    this.customerPhone = '',
    this.totalDue = 0,
    required this.createdAt,
  });

  factory UdharCustomerModel.fromJson(Map<String, dynamic> json) {
    return UdharCustomerModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      userId: json['user_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      totalDue: (json['total_due'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'user_id': userId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_due': totalDue,
    };
  }
}

class UdharEntryModel {
  final String id;
  final String shopId;
  final String userId;
  final String customerId;
  final String entryType; // 'credit' = gave udhar, 'debit' = received payment
  final double amount;
  final String note;
  final DateTime entryDate;
  final DateTime createdAt;

  UdharEntryModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.customerId,
    this.entryType = 'credit',
    required this.amount,
    this.note = '',
    required this.entryDate,
    required this.createdAt,
  });

  factory UdharEntryModel.fromJson(Map<String, dynamic> json) {
    return UdharEntryModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      userId: json['user_id'] ?? '',
      customerId: json['customer_id'] ?? '',
      entryType: json['entry_type'] ?? 'credit',
      amount: (json['amount'] ?? 0).toDouble(),
      note: json['note'] ?? '',
      entryDate: DateTime.parse(json['entry_date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'user_id': userId,
      'customer_id': customerId,
      'entry_type': entryType,
      'amount': amount,
      'note': note,
      'entry_date': entryDate.toIso8601String().split('T')[0],
    };
  }
}