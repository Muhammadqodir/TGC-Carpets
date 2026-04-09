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

/// Desktop variant of the "add order" form.
/// All item-list state lives in [controller], owned by [AddOrderPage].
class AddOrderDesktopPage extends StatefulWidget {
  const AddOrderDesktopPage({super.key, required this.controller});

  final OrderFormController controller;

  @override
  State<AddOrderDesktopPage> createState() => _AddOrderDesktopPageState();
}

class _AddOrderDesktopPageState extends State<AddOrderDesktopPage> {
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
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Yangi buyurtma'),
              titleSpacing: 0,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
              ),
              actions: [
                BlocBuilder<OrderFormBloc, OrderFormState>(
                  builder: (context, state) {
                    if (state is OrderFormSubmitting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    return FilledButton(
                      onPressed: _submit,
                      child: const Text('Saqlash'),
                    );
                  },
                ),
                const SizedBox(width: 16),
              ],
            ),
            body: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left panel: header fields ─────────────────────────
                  SizedBox(
                    width: 320,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date
                          _FieldLabel(label: 'Sana'),
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
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Client (required)
                          _FieldLabel(label: 'Mijoz'),
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
                                      onTap: () => setState(
                                          () => _selectedClient = null),
                                      child: const Icon(Icons.close,
                                          size: 18,
                                          color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Notes
                          _FieldLabel(label: 'Izoh (ixtiyoriy)'),
                          TextFormField(
                            controller: ctrl.notesCtrl,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Qo\'shimcha ma\'lumot...',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Divider ───────────────────────────────────────────
                  const VerticalDivider(width: 1),

                  // ── Right panel: items ────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table header
                        Container(
                          color: AppColors.surface,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text('Mahsulot',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ),
                              SizedBox(
                                width: 140,
                                child: Text('Miqdor',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ),
                              SizedBox(width: 40),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            itemCount: ctrl.items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final row = ctrl.items[index];
                              return _DesktopItemRow(
                                key: ValueKey(row.id),
                                row: row,
                                allItems: ctrl.items,
                                index: index,
                                onRemove: () => ctrl.removeItem(index),
                                onProductChanged: ctrl.notifyChanged,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Desktop item row ──────────────────────────────────────────────────────────

class _DesktopItemRow extends StatelessWidget {
  final OrderItemRow row;
  final List<OrderItemRow> allItems;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onProductChanged;

  const _DesktopItemRow({
    super.key,
    required this.row,
    required this.allItems,
    required this.index,
    required this.onRemove,
    required this.onProductChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              // Product picker
              Expanded(
                flex: 4,
                child: _DesktopProductPickerButton(
                  row: row,
                  allItems: allItems,
                  onChanged: onProductChanged,
                ),
              ),
              const SizedBox(width: 12),

              // Quantity
              SizedBox(
                width: 140,
                child: CountInput(
                  controller: row.quantityCtrl,
                  dense: true,
                  validator: (v) {
                    if (row.selectedProduct == null) return null;
                    if (v == null || v.trim().isEmpty) return 'Miqdorni kiriting';
                    final qty = int.tryParse(v);
                    if (qty == null || qty < 1) return 'Kamida 1';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 4),

              // Remove button
              SizedBox(
                width: 36,
                child: row.selectedProduct != null
                    ? IconButton(
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancelCircle,
                          size: 18,
                          strokeWidth: 2.5,
                          color: AppColors.error,
                        ),
                        onPressed: onRemove,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),

          // Size picker row (below, when product has a type)
          if (product != null && product.productTypeId != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _DesktopSizePicker(
                    row: row,
                    allItems: allItems,
                    productTypeId: product.productTypeId!,
                    onChanged: onProductChanged,
                  ),
                ),
                const SizedBox(width: 12 + 140 + 4 + 36),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Desktop product picker button ─────────────────────────────────────────────

class _DesktopProductPickerButton extends StatelessWidget {
  final OrderItemRow row;
  final List<OrderItemRow> allItems;
  final VoidCallback onChanged;

  const _DesktopProductPickerButton({
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
                    content:
                        Text('Bu mahsulot varianti allaqachon qo\'shilgan.'),
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
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      size: 16, color: AppColors.textSecondary),
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
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Desktop size picker ───────────────────────────────────────────────────────

class _DesktopSizePicker extends StatelessWidget {
  final OrderItemRow row;
  final List<OrderItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const _DesktopSizePicker({
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
                  content:
                      Text('Bu mahsulot varianti allaqachon qo\'shilgan.'),
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
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: size == null ? AppColors.divider : AppColors.primary,
            width: size == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: size != null
              ? AppColors.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 14,
              color: size == null ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              size == null ? 'O\'lcham tanlash' : size.dimensions,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: size == null
                        ? AppColors.textSecondary
                        : AppColors.primary,
                    fontWeight: size != null ? FontWeight.w600 : null,
                    fontSize: 13,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: size == null ? AppColors.textSecondary : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
