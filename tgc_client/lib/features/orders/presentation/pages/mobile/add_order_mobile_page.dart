import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../clients/domain/entities/client_entity.dart';
import '../../../../clients/presentation/widget/client_picker_bottom_sheet.dart';
import '../../../../products/presentation/widget/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widget/product_size_picker_sheet.dart';
import '../../bloc/order_form_bloc.dart';
import '../../bloc/order_form_event.dart';
import '../../bloc/order_form_state.dart';
import '../../widget/order_form_controller.dart';
import '../../widget/order_item_row.dart';

/// Mobile variant of the "add order" form.
/// All item-list state lives in [controller], owned by [AddOrderPage].
class AddOrderMobilePage extends StatefulWidget {
  const AddOrderMobilePage({super.key, required this.controller});

  final OrderFormController controller;

  @override
  State<AddOrderMobilePage> createState() => _AddOrderMobilePageState();
}

class _AddOrderMobilePageState extends State<AddOrderMobilePage> {
  final _formKey = GlobalKey<FormState>();

  ClientEntity? _selectedClient;
  DateTime _orderDate = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _orderDate = picked);
  }

  Future<void> _pickClient() async {
    final client = await ClientPickerBottomSheet.show(context);
    if (client != null && mounted) setState(() => _selectedClient = client);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mijozni tanlash shart.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final ctrl = widget.controller;
    final filledItems = ctrl.filledItems;

    if (filledItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamida bitta mahsulot qo\'shing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final hasUnpickedSize = filledItems.any(
      (r) => r.selectedProduct?.productTypeId != null && r.selectedSize == null,
    );
    if (hasUnpickedSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcha qatorlardagi mahsulot o\'lchamini tanlang.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final items = filledItems
        .map((r) => {
              'product_color_id': r.selectedColor!.id,
              if (r.selectedSize != null) 'product_size_id': r.selectedSize!.id,
              'quantity': int.tryParse(r.quantityCtrl.text.trim()) ?? 1,
            })
        .toList();

    final dateStr =
        '${_orderDate.year}-${_orderDate.month.toString().padLeft(2, '0')}-${_orderDate.day.toString().padLeft(2, '0')}';

    context.read<OrderFormBloc>().add(OrderFormSubmitted(
          orderDate: dateStr,
          items: items,
          clientId: _selectedClient!.id,
          notes: ctrl.notesCtrl.text.trim().isEmpty
              ? null
              : ctrl.notesCtrl.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderFormBloc, OrderFormState>(
      listener: (context, state) {
        if (state is OrderFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Buyurtma saqlandi.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
        } else if (state is OrderFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Yangi buyurtma'),
              titleSpacing: 0,
              leading: IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  strokeWidth: 2,
                ),
                onPressed: () => context.pop(),
              ),
            ),
            body: Stack(
              children: [
                SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const _SectionHeader(title: 'Buyurtma ma\'lumotlari'),
                        const SizedBox(height: 12),

                        // Date
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.divider),
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.surface,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Text(
                                  '${_orderDate.day.toString().padLeft(2, '0')}.${_orderDate.month.toString().padLeft(2, '0')}.${_orderDate.year}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Client (required)
                        InkWell(
                          onTap: _pickClient,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedClient == null
                                    ? AppColors.divider
                                    : AppColors.primary,
                                width: _selectedClient == null ? 1.0 : 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _selectedClient != null
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : AppColors.surface,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.store_outlined,
                                  size: 18,
                                  color: _selectedClient == null
                                      ? AppColors.textSecondary
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedClient?.shopName ??
                                        'Mijoz tanlash...',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: _selectedClient == null
                                              ? AppColors.textSecondary
                                              : null,
                                        ),
                                  ),
                                ),
                                if (_selectedClient != null)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedClient = null),
                                    child: const Icon(Icons.close,
                                        size: 18,
                                        color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Notes
                        TextFormField(
                          controller: ctrl.notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Izoh (ixtiyoriy)',
                            hintText: 'Qo\'shimcha ma\'lumot...',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Items
                        const _SectionHeader(title: 'Mahsulotlar'),
                        const SizedBox(height: 8),

                        ...ctrl.items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          return _MobileItemFormRow(
                            key: ValueKey(row.id),
                            row: row,
                            allItems: ctrl.items,
                            index: index,
                            onRemove: () => ctrl.removeItem(index),
                            canRemove: row.selectedProduct != null,
                            onProductChanged: ctrl.notifyChanged,
                          );
                        }),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // Submit button
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    top: false,
                    child: BlocBuilder<OrderFormBloc, OrderFormState>(
                      builder: (context, state) {
                        if (state is OrderFormSubmitting) {
                          return FilledButton(
                            onPressed: null,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50)),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50)),
                          child: const Text('Saqlash'),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
    );
  }
}

// ── Mobile item form row ──────────────────────────────────────────────────────

class _MobileItemFormRow extends StatelessWidget {
  final OrderItemRow row;
  final List<OrderItemRow> allItems;
  final int index;
  final VoidCallback onRemove;
  final bool canRemove;
  final VoidCallback onProductChanged;

  const _MobileItemFormRow({
    super.key,
    required this.row,
    required this.allItems,
    required this.index,
    required this.onRemove,
    required this.canRemove,
    required this.onProductChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${index + 1}-mahsulot',
                    style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                if (canRemove) ...[
                  InkWell(
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancelCircle,
                        size: 18,
                        strokeWidth: 2.5,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _ProductPickerButton(
                    row: row,
                    allItems: allItems,
                    onChanged: onProductChanged,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: CountInput(
                    controller: row.quantityCtrl,
                    validator: (v) {
                      if (row.selectedProduct == null) return null;
                      if (v == null || v.trim().isEmpty) return 'Miqdorni kiriting';
                      final qty = int.tryParse(v);
                      if (qty == null || qty < 1) return 'Kamida 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            if (product != null && product.productTypeId != null) ...[
              const SizedBox(height: 8),
              _SizePicker(
                row: row,
                allItems: allItems,
                productTypeId: product.productTypeId!,
                onChanged: onProductChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Product picker button ─────────────────────────────────────────────────────

class _ProductPickerButton extends StatelessWidget {
  final OrderItemRow row;
  final List<OrderItemRow> allItems;
  final VoidCallback onChanged;

  const _ProductPickerButton({
    required this.row,
    required this.allItems,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    return InkWell(
      onTap: () async {
        final result = await ProductPickerBottomSheet.show(context);
        if (result != null) {
          if (result.product.productTypeId == null) {
            final isDuplicate = allItems.any(
              (r) =>
                  r.id != row.id &&
                  r.selectedProduct?.id == result.product.id &&
                  r.selectedColor?.id == result.color?.id,
            );
            if (isDuplicate) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bu mahsulot varianti allaqachon qo\'shilgan.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
              return;
            }
          }
          row.selectedProduct = result.product;
          row.selectedColor = result.color;
          row.selectedSize = null;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: product == null ? AppColors.divider : AppColors.primary,
            width: product == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: product != null
              ? AppColors.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: product == null
            ? Row(
                children: [
                  const Icon(Icons.search_rounded,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Mahsulot tanlash',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (product.productType?.type != null)
                              product.productType!.type,
                            if (row.selectedColor != null)
                              row.selectedColor!.colorName,
                          ].join(' · '),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedReplace,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Size picker ───────────────────────────────────────────────────────────────

class _SizePicker extends StatelessWidget {
  final OrderItemRow row;
  final List<OrderItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const _SizePicker({
    required this.row,
    required this.allItems,
    required this.productTypeId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = row.selectedSize;
    return InkWell(
      onTap: () async {
        final picked = await ProductSizePickerSheet.show(
          context,
          productTypeId: productTypeId,
        );
        if (picked != null) {
          final isDuplicate = allItems.any(
            (r) =>
                r.id != row.id &&
                r.selectedProduct?.id == row.selectedProduct?.id &&
                r.selectedColor?.id == row.selectedColor?.id &&
                r.selectedSize?.id == picked.id,
          );
          if (isDuplicate) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu mahsulot varianti allaqachon qo\'shilgan.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }
          row.selectedSize = picked;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: size == null ? AppColors.divider : AppColors.primary,
            width: size == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: size != null ? AppColors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 16,
              color: size == null ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                size == null ? 'O\'lcham tanlash' : size.dimensions,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: size == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: size != null ? FontWeight.w600 : null,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: size == null ? AppColors.textSecondary : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
