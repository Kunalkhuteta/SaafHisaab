import 'shop_model.dart';
import '../utils/indian_date_time.dart';

enum ShopRole {
  admin,
  manager,
  staff,
}

extension ShopRoleX on ShopRole {
  String get value => switch (this) {
        ShopRole.admin => 'admin',
        ShopRole.manager => 'manager',
        ShopRole.staff => 'staff',
      };

  String get label => switch (this) {
        ShopRole.admin => 'Admin',
        ShopRole.manager => 'Manager',
        ShopRole.staff => 'Staff',
      };

  bool get isAdmin => this == ShopRole.admin;
  bool get isManager => this == ShopRole.manager;
  bool get isStaff => this == ShopRole.staff;

  bool get canManageUsers => isAdmin;
  bool get canOpenSettings => isAdmin;
  bool get canViewStock => isAdmin || isManager;
  bool get canViewUdhar => isAdmin || isManager;
  bool get canViewReports => isAdmin || isManager;
  bool get canViewPurchases => isAdmin || isManager;
  bool get canViewMaster => isAdmin || isManager;

  static ShopRole parse(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'manager' => ShopRole.manager,
      'staff' => ShopRole.staff,
      _ => ShopRole.admin,
    };
  }
}

class ShopAccessContext {
  final ShopModel shop;
  final ShopRole role;
  final bool isOwner;
  final bool isDeactivated;
  final String? membershipId;
  final String? welcomeMessage;
  final String? memberName;

  const ShopAccessContext({
    required this.shop,
    required this.role,
    required this.isOwner,
    this.isDeactivated = false,
    this.membershipId,
    this.welcomeMessage,
    this.memberName,
  });
}

class ShopMember {
  final String id;
  final String shopId;
  final String userId;
  final String name;
  final String phone;
  final ShopRole role;
  final bool isActive;
  final String addedBy;
  final DateTime createdAt;

  const ShopMember({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.addedBy,
    required this.createdAt,
  });

  factory ShopMember.fromJson(Map<String, dynamic> json) {
    return ShopMember(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: ShopRoleX.parse(json['role'] as String?),
      isActive: json['is_active'] ?? true,
      addedBy: json['added_by'] ?? '',
      createdAt: IndianIndianDateTime.tryParse(json['created_at'] ?? '') ?? IndianIndianDateTime.now(),
    );
  }
}

class ShopMemberInvite {
  final String id;
  final String shopId;
  final String name;
  final String phone;
  final ShopRole role;
  final String invitedBy;
  final bool isAccepted;
  final DateTime createdAt;

  const ShopMemberInvite({
    required this.id,
    required this.shopId,
    required this.name,
    required this.phone,
    required this.role,
    required this.invitedBy,
    required this.isAccepted,
    required this.createdAt,
  });

  factory ShopMemberInvite.fromJson(Map<String, dynamic> json) {
    return ShopMemberInvite(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: ShopRoleX.parse(json['role'] as String?),
      invitedBy: json['invited_by'] ?? '',
      isAccepted: json['is_accepted'] ?? false,
      createdAt: IndianIndianDateTime.tryParse(json['created_at'] ?? '') ?? IndianIndianDateTime.now(),
    );
  }
}
