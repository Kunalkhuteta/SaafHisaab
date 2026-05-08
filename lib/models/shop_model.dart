class ShopModel {
  final String id;
  final String userId;
  final String ownerName;
  final String shopName;
  final String city;
  final String shopType;
  final String gstNumber;
  final String phone;
  final String plan;
  final DateTime createdAt;

  ShopModel({
    required this.id,
    required this.userId,
    required this.ownerName,
    required this.shopName,
    required this.city,
    required this.shopType,
    this.gstNumber = '',
    required this.phone,
    this.plan = 'free',
    required this.createdAt,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      ownerName: json['owner_name'] ?? '',
      shopName: json['shop_name'] ?? '',
      city: json['city'] ?? '',
      shopType: json['shop_type'] ?? '',
      gstNumber: json['gst_number'] ?? '',
      phone: json['phone'] ?? '',
      plan: json['plan'] ?? 'free',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'owner_name': ownerName,
      'shop_name': shopName,
      'city': city,
      'shop_type': shopType,
      'gst_number': gstNumber,
      'phone': phone,
      'plan': plan,
    };
  }
}