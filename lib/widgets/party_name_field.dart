import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../globalVar.dart';
import '../models/udhar_model.dart';
import '../services/supabase_service.dart';

class PartyNameField extends StatefulWidget {
  final String shopId;
  final TextEditingController controller;
  final TextEditingController? phoneController;
  final bool isEn;
  final String label;
  final String hint;
  final bool required;
  final ValueChanged<UdharCustomerModel?>? onCustomerSelected;

  const PartyNameField({
    super.key,
    required this.shopId,
    required this.controller,
    required this.isEn,
    required this.label,
    required this.hint,
    this.phoneController,
    this.required = false,
    this.onCustomerSelected,
  });

  @override
  State<PartyNameField> createState() => _PartyNameFieldState();
}

class _PartyNameFieldState extends State<PartyNameField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<UdharCustomerModel>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (customer) => customer.customerName,
      optionsBuilder: (value) async {
        return SupabaseService.searchUdharCustomers(widget.shopId, value.text);
      },
      onSelected: (customer) {
        widget.controller.text = customer.customerName;
        widget.phoneController?.text = customer.customerPhone;
        widget.onCustomerSelected?.call(customer);
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          onChanged: (_) => widget.onCustomerSelected?.call(null),
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final customer = list[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryBg,
                      child: Text(
                        customer.customerName.isEmpty
                            ? '?'
                            : customer.customerName[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      customer.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (customer.customerPhone.isNotEmpty)
                          customer.customerPhone,
                        '${AppLang.tr(widget.isEn, 'Pending', 'बाकी')}: Rs ${customer.totalDue.toStringAsFixed(0)}',
                      ].join(' | '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () => onSelected(customer),
                  );
                },
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemCount: list.length,
              ),
            ),
          ),
        );
      },
    );
  }
}
