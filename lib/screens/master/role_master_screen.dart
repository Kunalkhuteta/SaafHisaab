import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/shop_access_model.dart';

class RoleMasterScreen extends StatelessWidget {
  const RoleMasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roles = [
      _RoleInfo(
        role: ShopRole.admin,
        color: AppColors.primary,
        allowed: [
          'Full sales, purchases, stock, udhar, reports, and settings access',
          'Can add users, change roles, cancel invites, and deactivate members',
          'Can open User Master and Role Master',
        ],
        blocked: const [],
      ),
      _RoleInfo(
        role: ShopRole.manager,
        color: AppColors.success,
        allowed: [
          'Can add sales and purchases',
          'Can manage stock, udhar, and operational reports',
          'Can view all daily operation tabs except admin settings',
        ],
        blocked: [
          'Cannot access User Master or Role Master',
          'Cannot change shop settings or system parameters',
          'Cannot access owner-only annual finance exports in Phase 1',
        ],
      ),
      _RoleInfo(
        role: ShopRole.staff,
        color: AppColors.warning,
        allowed: [
          'Can use Home and Bills',
          'Can enter sales from the billing screen',
        ],
        blocked: [
          'Cannot open stock, udhar, reports, settings, or user management',
          'Cannot view sensitive credit or business intelligence screens',
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Role Master')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final info in roles) ...[
            _RoleCard(info: info),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderBlue),
            ),
            child: const Text(
              'Custom roles coming soon. Owners will be able to create role names and choose specific permissions.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final _RoleInfo info;

  const _RoleCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: info.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.verified_user_rounded,
                    color: info.color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                info.role.label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in info.allowed)
            _PermissionLine(icon: Icons.check_rounded, text: item),
          for (final item in info.blocked)
            _PermissionLine(
              icon: Icons.close_rounded,
              text: item,
              muted: true,
            ),
        ],
      ),
    );
  }
}

class _PermissionLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool muted;

  const _PermissionLine({
    required this.icon,
    required this.text,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: muted ? AppColors.textHint : AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: muted ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleInfo {
  final ShopRole role;
  final Color color;
  final List<String> allowed;
  final List<String> blocked;

  const _RoleInfo({
    required this.role,
    required this.color,
    required this.allowed,
    required this.blocked,
  });
}
