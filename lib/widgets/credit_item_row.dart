import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../globalVar.dart';
import '../models/item_master_model.dart';

class CreditItemDraft {
  String? stockItemId;
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController categoryCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;
  final FocusNode itemFocusNode;
  final FocusNode categoryFocusNode;

  CreditItemDraft({
    this.stockItemId,
    String name = '',
    double quantity = 1,
    String category = '',
    String unit = 'piece',
    double price = 0,
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: quantity.toString()),
        categoryCtrl = TextEditingController(text: category),
        unitCtrl = TextEditingController(text: unit),
        priceCtrl = TextEditingController(text: price == 0 ? '' : '$price'),
        itemFocusNode = FocusNode(),
        categoryFocusNode = FocusNode();

  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get price => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get total => quantity * price;

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    categoryCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
    itemFocusNode.dispose();
    categoryFocusNode.dispose();
  }
}

class CreditItemRow extends StatelessWidget {
  final CreditItemDraft item;
  final List<ItemMasterModel> stockItems;
  final List<String> categories;
  final bool isEn;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const CreditItemRow({
    super.key,
    required this.item,
    required this.stockItems,
    required this.categories,
    required this.isEn,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: _stockAutocomplete(),
          ),
          if (canRemove) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              color: AppColors.error,
              tooltip: AppLang.tr(isEn, 'Remove item', 'Item hatayein'),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _numberField(
              item.qtyCtrl,
              AppLang.tr(isEn, 'Qty', 'मात्रा'),
              onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _numberField(
              item.priceCtrl,
              AppLang.tr(isEn, 'Amount', 'रकम'),
              onChanged,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _categoryAutocomplete()),
          const SizedBox(width: 8),
          Expanded(child: _unitDropdown()),
        ]),
        if (item.total > 0) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Rs ${item.total.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _stockAutocomplete() {
    return RawAutocomplete<ItemMasterModel>(
      textEditingController: item.nameCtrl,
      focusNode: item.itemFocusNode,
      displayStringForOption: (option) => option.itemName,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return stockItems.take(20);
        return stockItems
            .where((stock) => stock.itemName.toLowerCase().contains(q))
            .take(20);
      },
      onSelected: (selected) {
        item.stockItemId = selected.id;
        item.nameCtrl.text = selected.itemName;
        item.categoryCtrl.text = selected.itemCategory;
        onChanged();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (_) {
            item.stockItemId = null;
            onChanged();
          },
          decoration: _decoration(
            AppLang.tr(isEn, 'Item name *', 'आइटम का नाम *'),
            Icons.inventory_2_outlined,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return _optionsBox(
          list
              .map((stock) => ListTile(
                    dense: true,
                    title: Text(stock.itemName),
                    subtitle: Text(
                      [
                        if (stock.itemCategory.isNotEmpty) stock.itemCategory,
                        'Stock ${stock.currentStock.toStringAsFixed(0)}',
                      ].join(' | '),
                    ),
                    onTap: () => onSelected(stock),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _categoryAutocomplete() {
    return RawAutocomplete<String>(
      textEditingController: item.categoryCtrl,
      focusNode: item.categoryFocusNode,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return categories.take(20);
        return categories
            .where((category) => category.toLowerCase().contains(q))
            .take(20);
      },
      onSelected: (selected) {
        item.categoryCtrl.text = selected;
        onChanged();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (_) => onChanged(),
          decoration: _decoration(
            AppLang.tr(isEn, 'Category', 'Category'),
            Icons.category_outlined,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _optionsBox(
          options
              .map((category) => ListTile(
                    dense: true,
                    title: Text(category),
                    onTap: () => onSelected(category),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _unitDropdown() {
    const units = ['piece', 'kg', 'litre', 'meter', 'box', 'dozen'];
    final current = units.contains(item.unitCtrl.text) ? item.unitCtrl.text : null;
    return DropdownButtonFormField<String>(
      value: current,
      isExpanded: true,
      decoration: _decoration(AppLang.tr(isEn, 'Unit', 'Unit'), Icons.straighten),
      items: units
          .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
          .toList(),
      onChanged: (value) {
        item.unitCtrl.text = value ?? '';
        onChanged();
      },
    );
  }

  Widget _numberField(
      TextEditingController controller, String label, VoidCallback onChanged) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: _decoration(label, Icons.currency_rupee_rounded),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderBlue),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _optionsBox(List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            children: children,
          ),
        ),
      ),
    );
  }
}
