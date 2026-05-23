import 'dart:convert';

class UdharCustomerModel {
  final String id;
  final String shopId;
  final String userId;
  final String customerName;
  final String customerPhone;
  final double totalDue;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UdharCustomerModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.customerName,
    this.customerPhone = '',
    this.totalDue = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory UdharCustomerModel.fromJson(Map<String, dynamic> json) {
    return UdharCustomerModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      userId: json['user_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      totalDue: (json['total_due'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
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

  UdharCustomerModel copyWith({
    String? id,
    String? shopId,
    String? userId,
    String? customerName,
    String? customerPhone,
    double? totalDue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UdharCustomerModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      totalDue: totalDue ?? this.totalDue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UdharPaymentMeta {
  static const noteMarker = '__saafhisaab_credit_payment_v1__';

  final String paymentMethod;
  final String receiptImageUrl;
  final double paidAmount;
  final double remainingAmount;
  final String customerName;
  final String customerPhone;
  final String? appliedCreditEntryId;
  final String? billId;

  const UdharPaymentMeta({
    required this.paymentMethod,
    this.receiptImageUrl = '',
    required this.paidAmount,
    required this.remainingAmount,
    this.customerName = '',
    this.customerPhone = '',
    this.appliedCreditEntryId,
    this.billId,
  });

  bool get isPartial => remainingAmount > 0;

  String toEntryNote() {
    return '$noteMarker${jsonEncode({
      'paymentMethod': paymentMethod,
      'receiptImageUrl': receiptImageUrl,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'appliedCreditEntryId': appliedCreditEntryId,
      'billId': billId,
    })}';
  }

  static UdharPaymentMeta? tryParseNote(String note) {
    final markerIndex = note.indexOf(noteMarker);
    if (markerIndex < 0) return null;
    final jsonText = note.substring(markerIndex + noteMarker.length).trim();
    try {
      final payload = jsonDecode(jsonText) as Map<String, dynamic>;
      return UdharPaymentMeta(
        paymentMethod: payload['paymentMethod'] ?? 'cash',
        receiptImageUrl: payload['receiptImageUrl'] ?? '',
        paidAmount: (payload['paidAmount'] as num?)?.toDouble() ?? 0,
        remainingAmount:
            (payload['remainingAmount'] as num?)?.toDouble() ?? 0,
        customerName: payload['customerName'] ?? '',
        customerPhone: payload['customerPhone'] ?? '',
        appliedCreditEntryId: payload['appliedCreditEntryId'] as String?,
        billId: payload['billId'] as String?,
      );
    } catch (_) {
      return null;
    }
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
