import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../clients/domain/entities/client_entity.dart';
import '../../../../clients/presentation/widgets/client_picker_bottom_sheet.dart';
import '../../../../products/presentation/widgets/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widgets/size_input_sheet.dart';
import '../../../domain/entities/order_entity.dart';
import '../../bloc/order_form_bloc.dart';
import '../../bloc/order_form_event.dart';
import '../../bloc/order_form_state.dart';
import '../../widgets/order_form_controller.dart';
import '../../widgets/order_item_row.dart';

/// Mobile variant of the "add/edit order" form.
/// All item-list state lives in [controller], owned by [AddOrderPage]/[EditOrderPage].
/// When [initialOrder] is provided the form operates in edit mode.
class AddOrderMobilePage extends StatefulWidget {
  const AddOrderMobilePage({
    super.key,
    required this.controller,
    this.initialOrder,
  });

  final OrderFormController controller;

  /// When non-null the form is in edit mode and pre-fills from this order.
  final OrderEntity? initialOrder;

  @override
  State<AddOrderMobilePage> createState() => _AddOrderMobilePageState();
}

class _AddOrderMobilePageState extends State<AddOrderMobilePage> {
  final _formKey = GlobalKey<FormState>();

  /// Newly picked client. In edit mode the original client is used as fallback.
  ClientEntity? _newClient;
  late DateTime _orderDate;

  bool get _isEditMode => widget.initialOrder != null;
  int? get _effectiveClientId =>
      _newClient?.id ?? widget.initialOrder?.clientId;
  String get _clientDisplay =>
      _newClient?.shopName ??
      widget.initialOrder?.clientShopName ??
      'Mijoz tanlash...';
  bool get _hasClient => _effectiveClientId != null;

  @override
  void initState() {
    super.initState();
    _orderDate = widget.initialOrder?.orderDate ?? DateTime.now();
    if (widget.initialOrder != null) {
      widget.controller.notesCtrl.text = widget.initialOrder!.notes ?? '';
    }
  }

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
    if (client != null && mounted) setState(() => _newClient = client);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasClient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mijozni tanlash shart.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final ctrl = widget.controller;
    final dateStr =
        '${_orderDate.year}-${_orderDate.month.toString().padLeft(2, '0')}-${_orderDate.day.toString().padLeft(2, '0')}';
    final notes =
        ctrl.notesCtrl.text.trim().isEmpty ? null : ctrl.notesCtrl.text.trim();

    final filledItems = ctrl.filledItems;
    if (filledItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamida bitta mahsulot bo\'lishi shart.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Only rows where the user has just picked a new entity need a size check.
    final hasUnpickedSize = filledItems.any(
      (r) => r.selectedProduct?.productTypeId != null && r.effectiveLength == null,
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
              'product_color_id': r.selectedColor?.id ?? r.prefilledColorId!,
              if (r.effectiveLength != null) 'length': r.effectiveLength,
              if (r.effectiveWidth != null) 'width': r.effectiveWidth,
              'quantity': int.tryParse(r.quantityCtrl.text.trim()) ?? 1,
            })
        .toList();

    if (_isEditMode) {
      context.read<OrderFormBloc>().add(OrderFormUpdateSubmitted(
            orderId: widget.initialOrder!.id,
            orderDate: dateStr,
            items: items,
            clientId: _effectiveClientId!,
            notes: notes,
          ));
    } else {
      context.read<OrderFormBloc>().add(OrderFormSubmitted(
            orderDate: dateStr,
            items: items,
            clientId: _effectiveClientId!,
            notes: notes,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderFormBloc, OrderFormState>(
      listener: (context, state) {
        if (state is OrderFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  _isEditMode ? 'Buyurtma yangilandi.' : 'Buyurtma saqlandi.'),
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
              title: Text(_isEditMode
                  ? '#${widget.initialOrder!.id} Tahrirlash'
                  : 'Yangi buyurtma'),
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
                                color: !_hasClient
                                    ? AppColors.divider
                                    : AppColors.primary,
                                width: !_hasClient ? 1.0 : 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _hasClient
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : AppColors.surface,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.store_outlined,
                                  size: 18,
                                  color: !_hasClient
                                      ? AppColors.textSecondary
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _clientDisplay,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: !_hasClient
                                              ? AppColors.textSecondary
                                              : null,
                                        ),
                                  ),
                                ),
                                if (_newClient != null)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _newClient = null),
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
                        _SectionHeader(
                          title: _isEditMode ? 'Mahsulotlar' : 'Mahsulotlar',
                        ),
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
                            canRemove: row.isFilled,
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
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: (product != null && product.productTypeId != null)
                      ? _SizePicker(
                          row: row,
                          allItems: allItems,
                          productTypeId: product.productTypeId!,
                          onChanged: onProductChanged,
                        )
                      : (product == null && row.prefilledProductTypeId != null)
                          ?
                          // Existing item from server — allow size change via picker.
                          _SizePicker(
                              row: row,
                              allItems: allItems,
                              productTypeId: row.prefilledProductTypeId!,
                              onChanged: onProductChanged,
                            )
                          : SizedBox.shrink(),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: CountInput(
                    controller: row.quantityCtrl,
                    validator: (v) {
                      if (row.selectedProduct == null) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Miqdorni kiriting';
                      }
                      final qty = int.tryParse(v);
                      if (qty == null || qty < 1) return 'Kamida 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
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
    final isPrefilled = product == null && row.prefilledColorId != null;
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
          row.selectedLength = null;
          row.selectedWidth = null;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: (!isPrefilled && product == null)
                ? AppColors.divider
                : AppColors.primary,
            width: (!isPrefilled && product == null) ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: (product != null || isPrefilled)
              ? AppColors.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: (!isPrefilled && product == null)
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
                  // Color thumbnail: entity image first, prefill URL as fallback
                  AppThumbnail(
                    imageUrl: row.selectedColor?.imageUrl ??
                        row.prefilledColorImageUrl,
                    size: 28,
                    borderRadius: 4,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product?.name ?? row.prefilledProductName ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Builder(builder: (context) {
                          final qualityName =
                              product?.productQuality?.qualityName ??
                                  row.prefilledQualityName;
                          final parts = [
                            if (product?.productType?.type != null)
                              product!.productType!.type.toUpperCase(),
                            if (qualityName != null) qualityName.toUpperCase(),
                            if ((row.selectedColor?.colorName ??
                                    row.prefilledColorName) !=
                                null)
                              row.selectedColor?.colorName.toUpperCase() ??
                                  row.prefilledColorName!.toUpperCase(),
                          ];
                          if (parts.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                parts.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          );
                        }),
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
    final displayDimensions = row.sizeDimensions;
    final hasSize = displayDimensions != null;
    return InkWell(
      onTap: () async {
        final picked = await SizeInputSheet.show(
          context,
          initialLength: row.effectiveLength,
          initialWidth: row.effectiveWidth,
        );
        if (picked != null) {
          final isDuplicate = allItems.any(
            (r) =>
                r.id != row.id &&
                r.selectedColor?.id == row.selectedColor?.id &&
                r.effectiveLength == picked.length &&
                r.effectiveWidth == picked.width,
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
          row.selectedLength = picked.length;
          row.selectedWidth = picked.width;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: !hasSize ? AppColors.divider : AppColors.primary,
            width: !hasSize ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: hasSize ? AppColors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 16,
              color: !hasSize ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayDimensions ?? 'O\'lcham tanlash',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: !hasSize
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: hasSize ? FontWeight.w600 : null,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: !hasSize ? AppColors.textSecondary : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
