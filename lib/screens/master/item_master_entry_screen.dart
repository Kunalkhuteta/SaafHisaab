import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../sys_param.dart';
import '../../providers/app_providers.dart';
import '../../models/item_master_model.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import 'package:saafhisaab/utils/indian_date_time.dart';


class ItemMasterEntryScreen extends ConsumerStatefulWidget {
  final ItemMasterModel? itemToEdit;

  const ItemMasterEntryScreen({super.key, this.itemToEdit});

  @override
  ConsumerState<ItemMasterEntryScreen> createState() =>
      _ItemMasterEntryScreenState();
}

class _ItemMasterEntryScreenState extends ConsumerState<ItemMasterEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageExtension;
  String? _existingImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      _nameCtrl.text = widget.itemToEdit!.itemName;
      _categoryCtrl.text = widget.itemToEdit!.itemCategory;
      _groupCtrl.text = widget.itemToEdit!.itemGroup;
      _stockCtrl.text = widget.itemToEdit!.currentStock.toStringAsFixed(0);
      _existingImageUrl = widget.itemToEdit!.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _groupCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      String ext = path.extension(pickedFile.path).replaceAll('.', '');
      if (ext.isEmpty && pickedFile.mimeType != null) {
        ext = pickedFile.mimeType!.split('/').last;
      }
      setState(() {
        _imageBytes = bytes;
        _imageExtension = ext.isNotEmpty ? ext : 'jpg';
      });
    }
  }

  Future<Uint8List?> _compressImage(Uint8List list) async {
    if (kIsWeb) {
      // flutter_image_compress sometimes has issues on web, returning original bytes if it fails
      try {
        final result = await FlutterImageCompress.compressWithList(
          list,
          minWidth: 800,
          minHeight: 800,
          quality: 70,
        );
        return result;
      } catch (e) {
        debugPrint('Web compress failed, using original bytes: $e');
        return list;
      }
    } else {
      final result = await FlutterImageCompress.compressWithList(
        list,
        minWidth: 800,
        minHeight: 800,
        quality: 70,
      );
      return result;
    }
  }

  Future<void> _saveItem(bool isEn) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    try {
      final userId = AuthService.currentUserId;
      final shop = await ref.read(shopProvider.future);
      if (userId == null || shop == null) throw Exception('Not logged in');

      String imageUrl = _existingImageUrl ?? '';

      // Upload and compress image if new one is selected
      if (_imageBytes != null) {
        final compressedBytes = await _compressImage(_imageBytes!);
        if (compressedBytes != null) {
          imageUrl = await SupabaseService.uploadItemImage(
            shop.id,
            _nameCtrl.text.trim(),
            compressedBytes,
            _imageExtension ?? 'jpg',
          );
        }
      }

      final stockVal = double.tryParse(_stockCtrl.text) ?? 0.0;

      final newItem = ItemMasterModel(
        id: widget.itemToEdit?.id ?? '',
        shopId: shop.id,
        userId: userId,
        itemName: _nameCtrl.text.trim(),
        itemCategory: _categoryCtrl.text.trim(),
        itemGroup: _groupCtrl.text.trim(),
        currentStock: stockVal,
        imageUrl: imageUrl,
        createdAt: widget.itemToEdit?.createdAt ?? IndianDateTime.now(),
      );

      if (widget.itemToEdit == null) {
        await SupabaseService.saveMasterItem(newItem);
      } else {
        await SupabaseService.updateMasterItem(newItem);
      }

      ref.invalidate(itemMasterProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLang.tr(isEn, 'Item saved!', 'आइटम सहेजा गया!')),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final sysParams = ref.watch(sysParamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.itemToEdit != null
            ? AppLang.tr(isEn, 'Edit Item', 'आइटम एडिट करें')
            : AppLang.tr(isEn, 'New Item Entry', 'नया आइटम')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image upload area
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderBlue, width: 2),
                          ),
                          child: _imageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                                )
                              : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(_existingImageUrl!, fit: BoxFit.cover),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_a_photo_rounded,
                                            color: AppColors.primary, size: 32),
                                        const SizedBox(height: 8),
                                        Text(
                                          AppLang.tr(isEn, 'Upload', 'अपलोड'),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildTextField(
                      controller: _nameCtrl,
                      label: AppLang.tr(isEn, 'Item Name *', 'आइटम का नाम *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    if (sysParams.showItemCategory) ...[
                      _buildTextField(
                        controller: _categoryCtrl,
                        label: AppLang.tr(isEn, 'Item Category', 'आइटम श्रेणी'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    if (sysParams.showItemGroup) ...[
                      _buildTextField(
                        controller: _groupCtrl,
                        label: AppLang.tr(isEn, 'Item Group', 'आइटम समूह'),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildTextField(
                      controller: _stockCtrl,
                      label: AppLang.tr(isEn, 'Current Stock *', 'वर्तमान स्टॉक *'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _saveItem(isEn),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLang.tr(isEn, 'Save Item', 'आइटम सहेजें'),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
