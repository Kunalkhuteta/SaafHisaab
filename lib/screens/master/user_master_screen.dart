import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../models/shop_access_model.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';

class UserMasterScreen extends ConsumerWidget {
  const UserMasterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(shopAccessProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('User Master')),
      body: accessAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (access) {
          if (access == null || !access.role.canManageUsers) {
            return const Center(child: Text('Only admins can manage users.'));
          }

          return _UserMasterBody(access: access);
        },
      ),
    );
  }
}

class _UserMasterBody extends ConsumerStatefulWidget {
  final ShopAccessContext access;

  const _UserMasterBody({required this.access});

  @override
  ConsumerState<_UserMasterBody> createState() => _UserMasterBodyState();
}

class _UserMasterBodyState extends ConsumerState<_UserMasterBody> {
  late Future<_UserMasterData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(widget.access.shop.id);
  }

  void _reload() {
    setState(() {
      _future = _load(widget.access.shop.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopId = widget.access.shop.id;
    return FutureBuilder<_UserMasterData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final data = snapshot.data!;
        final activeMembers = data.members.where((m) => m.isActive).toList();

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader(
                title: 'Current members',
                count: activeMembers.length,
              ),
              const SizedBox(height: 8),
              if (activeMembers.isEmpty)
                const _EmptyState(text: 'No staff members added yet.'),
              for (final member in activeMembers)
                _MemberCard(
                  member: member,
                  shopId: shopId,
                  onChanged: _reload,
                ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: 'Pending invites',
                count: data.invites.length,
              ),
              const SizedBox(height: 8),
              if (data.invites.isEmpty)
                const _EmptyState(text: 'No pending invites.'),
              for (final invite in data.invites)
                _InviteCard(
                  invite: invite,
                  shopId: shopId,
                  onChanged: _reload,
                ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add New Member'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showAddMemberSheet(
                    context,
                    access: widget.access,
                    onSaved: _reload,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_UserMasterData> _load(String shopId) async {
    final results = await Future.wait<dynamic>([
      SupabaseService.getShopMembers(shopId),
      SupabaseService.getPendingShopInvites(shopId),
    ]);
    return _UserMasterData(
      members: results[0] as List<ShopMember>,
      invites: results[1] as List<ShopMemberInvite>,
    );
  }
}

class _MemberCard extends StatelessWidget {
  final ShopMember member;
  final String shopId;
  final VoidCallback onChanged;

  const _MemberCard({
    required this.member,
    required this.shopId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
              Expanded(
                child: Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _RoleBadge(role: member.role),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_maskPhone(member.phone)}  -  Added ${_formatDate(member.createdAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Change role'),
                onPressed: () => _changeRole(context),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.block_rounded, size: 18),
                label: const Text('Deactivate'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () => _deactivate(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole(BuildContext context) async {
    ShopRole selected = member.role;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change role'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final role in ShopRole.values)
                RadioListTile<ShopRole>(
                  value: role,
                  groupValue: selected,
                  title: Text(role.label),
                  onChanged: (value) {
                    if (value != null) setState(() => selected = value);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || selected == member.role) return;
    await SupabaseService.updateShopMemberRole(
      shopId: shopId,
      memberId: member.id,
      role: selected,
    );
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role updated')),
      );
    }
  }

  Future<void> _deactivate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate member?'),
        content: Text('${member.name} will lose access to this shop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Deactivate',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await SupabaseService.deactivateShopMember(
      shopId: shopId,
      memberId: member.id,
    );
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member deactivated')),
      );
    }
  }
}

class _InviteCard extends StatelessWidget {
  final ShopMemberInvite invite;
  final String shopId;
  final VoidCallback onChanged;

  const _InviteCard({
    required this.invite,
    required this.shopId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${invite.name}  ${_maskPhone(invite.phone)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Invited ${_formatDate(invite.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _RoleBadge(role: invite.role),
          IconButton(
            tooltip: 'Cancel invite',
            icon: const Icon(Icons.close_rounded, color: AppColors.error),
            onPressed: () async {
              await SupabaseService.cancelShopInvite(
                shopId: shopId,
                inviteId: invite.id,
              );
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final ShopRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      ShopRole.admin => AppColors.primary,
      ShopRole.manager => AppColors.success,
      ShopRole.staff => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}

Future<void> _showAddMemberSheet(
  BuildContext context,
  {
  required ShopAccessContext access,
  required VoidCallback onSaved,
}
) async {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  var role = ShopRole.staff;
  var isSaving = false;
  var saved = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Member',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(labelText: '10-digit phone'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<ShopRole>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final value in ShopRole.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => role = value);
                },
              ),
              if (role.isAdmin) ...[
                const SizedBox(height: 10),
                const Text(
                  'Admin gives full access including user management. Only choose this for a completely trusted person.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name is required')),
                            );
                            return;
                          }
                          setState(() => isSaving = true);
                          try {
                            await SupabaseService.inviteShopMember(
                              shopId: access.shop.id,
                              ownerUserId: AuthService.currentUserId ?? '',
                              ownerPhone: access.shop.phone,
                              name: name,
                              phone: phoneCtrl.text,
                              role: role,
                            );
                            saved = true;
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Member invite saved'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  nameCtrl.dispose();
  phoneCtrl.dispose();
  if (saved) onSaved();
}

String _maskPhone(String phone) {
  final normalized = SupabaseService.normalizePhone(phone);
  if (normalized.length < 4) return phone;
  return '******${normalized.substring(normalized.length - 4)}';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _UserMasterData {
  final List<ShopMember> members;
  final List<ShopMemberInvite> invites;

  const _UserMasterData({
    required this.members,
    required this.invites,
  });
}
