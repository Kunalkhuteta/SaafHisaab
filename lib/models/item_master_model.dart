import '../utils/indian_date_time.dart';

class ItemMasterModel {
  final String id;
  final String shopId;
  final String userId;
  final String itemName;
  final String itemCategory;
  final String itemGroup;
  final double currentStock;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ItemMasterModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.itemName,
    this.itemCategory = '',
    this.itemGroup = '',
    required this.currentStock,
    this.imageUrl = '',
    required this.createdAt,
    this.updatedAt,
  });

  factory ItemMasterModel.fromJson(Map<String, dynamic> json) {
    return ItemMasterModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      userId: json['user_id'] ?? '',
      itemName: json['item_name'] ?? '',
      itemCategory: json['item_category'] ?? '',
      itemGroup: json['item_group'] ?? '',
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] ?? '',
      createdAt: IndianDateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? IndianDateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'user_id': userId,
      'item_name': itemName,
      'item_category': itemCategory,
      'item_group': itemGroup,
      'current_stock': currentStock,
      'image_url': imageUrl,
    };
  }

  ItemMasterModel copyWith({
    String? id,
    String? shopId,
    String? userId,
    String? itemName,
    String? itemCategory,
    String? itemGroup,
    double? currentStock,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemMasterModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      itemName: itemName ?? this.itemName,
      itemCategory: itemCategory ?? this.itemCategory,
      itemGroup: itemGroup ?? this.itemGroup,
      currentStock: currentStock ?? this.currentStock,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
