class BillModel {
  final String id;
  final String shopId;
  final String userId;
  final String imageUrl;
  final String rawText;
  final double amount;
  final DateTime billDate;
  final String vendorName;
  final String category;
  final String billType;
  final bool isGstBill;
  final double gstAmount;
  final String notes;
  final DateTime createdAt;

  BillModel({
    required this.id,
    required this.shopId,
    required this.userId,
    this.imageUrl = '',
    this.rawText = '',
    required this.amount,
    required this.billDate,
    this.vendorName = '',
    this.category = 'General',
    this.billType = 'purchase',
    this.isGstBill = false,
    this.gstAmount = 0,
    this.notes = '',
    required this.createdAt,
  });

  factory BillModel.fromJson(Map<String, dynamic> json) {
    return BillModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      userId: json['user_id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      rawText: json['raw_text'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      billDate: DateTime.parse(json['bill_date']),
      vendorName: json['vendor_name'] ?? '',
      category: json['category'] ?? 'General',
      billType: json['bill_type'] ?? 'purchase',
      isGstBill: json['is_gst_bill'] ?? false,
      gstAmount: (json['gst_amount'] ?? 0).toDouble(),
      notes: json['notes'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'user_id': userId,
      'image_url': imageUrl,
      'raw_text': rawText,
      'amount': amount,
      'bill_date': billDate.toIso8601String().split('T')[0],
      'vendor_name': vendorName,
      'category': category,
      'bill_type': billType,
      'is_gst_bill': isGstBill,
      'gst_amount': gstAmount,
      'notes': notes,
    };
  }
}