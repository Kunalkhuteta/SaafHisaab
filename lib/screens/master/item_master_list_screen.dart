import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../models/item_master_model.dart';
import '../../services/supabase_service.dart';
import 'item_master_entry_screen.dart';

class ItemMasterListScreen extends ConsumerWidget {
  const ItemMasterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(appLanguageProvider);
    final itemMasterAsync = ref.watch(itemMasterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLang.tr(isEn, 'Item Master', 'आइटम मास्टर')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: itemMasterAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_rounded,
                      size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text(
                    AppLang.tr(
                        isEn, 'No items found', 'कोई आइटम नहीं मिला'),
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemCard(context, ref, item, isEn);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ItemMasterEntryScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          AppLang.tr(isEn, 'Add Item', 'आइटम जोड़ें'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, WidgetRef ref, ItemMasterModel item, bool isEn) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ItemMasterEntryScreen(itemToEdit: item)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    if (item.itemCategory.isNotEmpty)
                      Text(
                        '${AppLang.tr(isEn, 'Category:', 'श्रेणी:')} ${item.itemCategory}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    if (item.itemGroup.isNotEmpty)
                      Text(
                        '${AppLang.tr(isEn, 'Group:', 'समूह:')} ${item.itemGroup}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppLang.tr(isEn, 'Stock:', 'स्टॉक:')} ${item.currentStock.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textHint),
                onSelected: (val) async {
                  if (val == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(AppLang.tr(isEn, 'Delete Item?', 'आइटम हटाएं?')),
                        content: Text(AppLang.tr(isEn, 'Are you sure?', 'क्या आप वाकई चाहते हैं?')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(AppLang.tr(isEn, 'Cancel', 'रद्द करें'))),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.error),
                            child: Text(AppLang.tr(isEn, 'Delete', 'हटाएं')),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await SupabaseService.deleteMasterItem(item.id);
                      ref.invalidate(itemMasterProvider);
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      AppLang.tr(isEn, 'Delete', 'हटाएं'),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: AppColors.primaryBg,
      child: const Icon(Icons.image_outlined, color: AppColors.primary, size: 28),
    );
  }
}
