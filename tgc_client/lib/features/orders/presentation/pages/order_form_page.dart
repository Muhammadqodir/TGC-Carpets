import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/ui/widgets/desktop_status_bar.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../core/ui/widgets/count_input.dart';
import '../../../clients/domain/entities/client_entity.dart';
import '../../../clients/presentation/widgets/client_picker_bottom_sheet.dart';
import '../../../products/presentation/widgets/product_picker_bottom_sheet.dart';
import '../../../products/presentation/widgets/product_size_picker_sheet.dart';
import '../../domain/entities/order_entity.dart';
import '../bloc/order_form_bloc.dart';
import '../bloc/order_form_event.dart';
import '../bloc/order_form_state.dart';
import '../widgets/edit_order_form_controller.dart';
import '../widgets/order_form_controller.dart';
import '../widgets/order_item_row.dart';

/// Unified adaptive entrypoint for both the "add order" and "edit order" flows.
///
/// Pass [order] to enter edit mode (pre-fills form, submits an update).
/// Omit [order] (or pass null) to enter add mode (empty form, creates new).
class OrderFormPage extends StatefulWidget {
  const OrderFormPage({super.key, this.order});

  /// When non-null the form operates in edit mode.
  final OrderEntity? order;

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  late final OrderFormController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.order != null
        ? EditOrderFormController(initialItems: widget.order!.items)
        : OrderFormController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrderFormBloc>(),
      child: _OrderFormBody(
        controller: _ctrl,
        initialOrder: widget.order,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form body
// ─────────────────────────────────────────────────────────────────────────────

class _OrderFormBody extends StatefulWidget {
  const _OrderFormBody({
    required this.controller,
    this.initialOrder,
  });

  final OrderFormController controller;
  final OrderEntity? initialOrder;

  @override
  State<_OrderFormBody> createState() => _OrderFormBodyState();
}

class _OrderFormBodyState extends State<_OrderFormBody> {
  final _formKey = GlobalKey<FormState>();

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
          content: Text("Kamida bitta mahsulot bo'lishi shart."),
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
          content: Text("Barcha qatorlardagi mahsulot o'lchamini tanlang."),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final items = filledItems
        .map((r) => {
              'product_color_id': r.selectedColor?.id ?? r.prefilledColorId!,
              if (r.selectedSize != null ||
                  (r.selectedProduct == null && r.prefilledSizeId != null))
                'product_size_id': r.selectedSize?.id ?? r.prefilledSizeId,
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

  String get _formattedDate =>
      '${_orderDate.day.toString().padLeft(2, '0')}.${_orderDate.month.toString().padLeft(2, '0')}.${_orderDate.year}';

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
            backgroundColor: AppColors.background,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top info bar: date + client ────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border:
                          Border(bottom: BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(
                      children: [
                        // Date picker
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.divider),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  _formattedDate,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Client picker (expands to fill remaining space)
                        Expanded(
                          child: InkWell(
                            onTap: _pickClient,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 40,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.store_outlined,
                                    size: 16,
                                    color: !_hasClient
                                        ? AppColors.textSecondary
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
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
                        ),
                      ],
                    ),
                  ),
                  // ── Items section label ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Mahsulotlar',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                          child: TextButton.icon(
                            onPressed: () async {},
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Exceldan import'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Table header ───────────────────────────────────────────
                  const _FormTableHeader(),
                  const Divider(height: 1, color: AppColors.divider),
                  // ── Table rows ─────────────────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: ctrl.items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final row = ctrl.items[index];
                        return _FormItemRow(
                          key: ValueKey(row.id),
                          row: row,
                          allItems: ctrl.items,
                          index: index,
                          onRemove: () => ctrl.removeItem(index),
                          onChanged: ctrl.notifyChanged,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  // ── Notes at bottom ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: TextFormField(
                      controller: ctrl.notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Izoh (ixtiyoriy)",
                        hintText: "Qo'shimcha ma'lumot...",
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  // ── Totals summary ─────────────────────────────────────────
                  Builder(builder: (context) {
                    final filled = ctrl.filledItems;
                    final totalQty = filled.fold(
                      0,
                      (sum, r) =>
                          sum + (int.tryParse(r.quantityCtrl.text) ?? 1),
                    );
                    final totalSqm = filled.fold(0.0, (sum, r) {
                      final qty = int.tryParse(r.quantityCtrl.text) ?? 1;
                      if (r.selectedSize != null) {
                        return sum +
                            r.selectedSize!.length *
                                r.selectedSize!.width *
                                qty /
                                10000.0;
                      }
                      if (r.prefilledSizeLength != null &&
                          r.prefilledSizeWidth != null) {
                        return sum +
                            r.prefilledSizeLength! *
                                r.prefilledSizeWidth! *
                                qty /
                                10000.0;
                      }
                      return sum;
                    });
                    return DesktopStatusBar(
                      child: Row(
                        children: [
                          _TotalChip(
                            label: 'Jami dona',
                            value: '$totalQty',
                          ),
                          const SizedBox(width: 16),
                          _TotalChip(
                            label: 'Jami m²',
                            value: '${totalSqm.toStringAsFixed(2)} m²',
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form table header
// ─────────────────────────────────────────────────────────────────────────────

class _FormTableHeader extends StatelessWidget {
  const _FormTableHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      return Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (isDesktop) _HeaderCell(label: '#', fixedWidth: 40),
            _HeaderCell(label: 'Mahsulot', flex: 3),
            if (isDesktop) ...[
              _HeaderCell(label: 'Sifat', flex: 2),
              _HeaderCell(label: 'Tur', flex: 2),
              _HeaderCell(label: 'Rang', flex: 2),
            ],
            _HeaderCell(label: "O'lcham", flex: 2),
            _HeaderCell(
              label: 'Miqdor',
              fixedWidth: isDesktop ? 150 : 120,
            ),
            SizedBox(width: isDesktop ? 40 : 20),
          ],
        ),
      );
    });
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int? flex;
  final double? fixedWidth;

  const _HeaderCell({required this.label, this.flex, this.fixedWidth});

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
    );
    if (fixedWidth != null) {
      return SizedBox(width: fixedWidth, child: child);
    }
    return Expanded(flex: flex ?? 1, child: child);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form item table row
// ─────────────────────────────────────────────────────────────────────────────

class _FormItemRow extends StatelessWidget {
  final OrderItemRow row;
  final List<OrderItemRow> allItems;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _FormItemRow({
    super.key,
    required this.row,
    required this.allItems,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    final isEven = index.isEven;

    return LayoutBuilder(builder: (context, constraints) {
      bool isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      return Container(
        color: isEven ? null : AppColors.surface.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isDesktop)
              // # index
              SizedBox(
                width: 40,
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            // Product picker
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ProductPickerCell(
                  row: row,
                  allItems: allItems,
                  onChanged: onChanged,
                ),
              ),
            ),
            if (isDesktop) ...[
              // Quality column
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: () {
                    final qualityName =
                        row.selectedProduct?.productQuality?.qualityName ??
                            row.prefilledQualityName;
                    return Text(
                      qualityName ?? '—',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: qualityName == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  }(),
                ),
              ),
              // Type column
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: () {
                    final typeName = row.selectedProduct?.productType?.type ??
                        row.prefilledProductTypeName;
                    return Text(
                      typeName ?? '—',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: typeName == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }(),
                ),
              ),
              // Color column
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: row.selectedColor != null
                      ? Row(
                          children: [
                            AppThumbnail(
                              imageUrl: row.selectedColor!.imageUrl,
                              size: 24,
                              borderRadius: 4,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row.selectedColor!.colorName,
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : row.prefilledColorName != null
                          ? Row(
                              children: [
                                AppThumbnail(
                                  imageUrl: row.prefilledColorImageUrl,
                                  size: 24,
                                  borderRadius: 4,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    row.prefilledColorName!,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                ),
              ),
            ],
            // Size column
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: product != null && product.productTypeId != null
                    ? _SizePickerCell(
                        row: row,
                        allItems: allItems,
                        productTypeId: product.productTypeId!,
                        onChanged: onChanged,
                      )
                    : row.prefilledProductTypeId != null
                        ? _SizePickerCell(
                            row: row,
                            allItems: allItems,
                            productTypeId: row.prefilledProductTypeId!,
                            onChanged: onChanged,
                          )
                        : row.prefilledSizeDimensions != null
                            ? Text(
                                row.prefilledSizeDimensions!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              )
                            : Text(
                                '—',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
              ),
            ),
            // Quantity
            SizedBox(
              width: isDesktop ? 150 : 120,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CountInput(
                  controller: row.quantityCtrl,
                  dense: true,
                  validator: (v) {
                    if (!row.isFilled) return null;
                    if (v == null || v.trim().isEmpty) return 'Kiriting';
                    if ((int.tryParse(v) ?? 0) < 1) return '≥ 1';
                    return null;
                  },
                ),
              ),
            ),
            // Remove action
            SizedBox(
              width: isDesktop ? 40 : 20,
              child: row.isFilled
                  ? IconButton(
                      onPressed: onRemove,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCancelCircle,
                        size: 18,
                        strokeWidth: 2.5,
                        color: AppColors.error,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product picker cell
// ─────────────────────────────────────────────────────────────────────────────

class _ProductPickerCell extends StatelessWidget {
  final OrderItemRow row;
  final List<OrderItemRow> allItems;
  final VoidCallback onChanged;

  const _ProductPickerCell({
    required this.row,
    required this.allItems,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    final isPrefilled = product == null && row.prefilledColorId != null;
    final displayName = product?.name ?? row.prefilledProductName;
    final displayColor = row.selectedColor?.colorName ?? row.prefilledColorName;
    return InkWell(
      onTap: () async {
        final result = await ProductPickerBottomSheet.show(context);
        if (result != null) {
          if (result.product.productTypeId == null) {
            final incomingColorId = result.color?.id;
            final isDuplicate = allItems.any((r) {
              if (r.id == row.id) return false;
              final rColorId = r.selectedColor?.id ?? r.prefilledColorId;
              return rColorId != null && rColorId == incomingColorId;
            });
            if (isDuplicate) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text("Bu mahsulot varianti allaqachon qo'shilgan."),
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: (product == null && !isPrefilled)
                ? AppColors.divider
                : AppColors.primary,
            width: (product == null && !isPrefilled) ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
          color: (product != null || isPrefilled)
              ? AppColors.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            // Icon(
            //   displayName == null
            //       ? Icons.search_rounded
            //       : Icons.inventory_2_outlined,
            //   size: 14,
            //   color: displayName == null
            //       ? AppColors.textSecondary
            //       : AppColors.primary,
            // ),
            AppThumbnail(
              imageUrl:
                  row.selectedColor?.imageUrl ?? row.prefilledColorImageUrl,
              size: 26,
              borderRadius: 4,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? 'Mahsulot tanlash',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 0.8,
                          color: displayName == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (displayColor != null)
                    Text(
                      displayColor.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (displayName != null)
              const HugeIcon(
                icon: HugeIcons.strokeRoundedReplace,
                size: 14,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Size picker cell
// ─────────────────────────────────────────────────────────────────────────────

class _SizePickerCell extends StatelessWidget {
  final OrderItemRow row;
  final List<OrderItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const _SizePickerCell({
    required this.row,
    required this.allItems,
    required this.productTypeId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = row.selectedSize;
    final displayDimensions = size?.dimensions ?? row.prefilledSizeDimensions;
    return InkWell(
      onTap: () async {
        final picked = await ProductSizePickerSheet.show(
          context,
          productTypeId: productTypeId,
        );
        if (picked != null) {
          final effectiveColorId =
              row.selectedColor?.id ?? row.prefilledColorId;
          final isDuplicate = allItems.any((r) {
            if (r.id == row.id) return false;
            final rColorId = r.selectedColor?.id ?? r.prefilledColorId;
            final rSizeId = r.selectedSize?.id ?? r.prefilledSizeId;
            return rColorId == effectiveColorId && rSizeId == picked.id;
          });
          if (isDuplicate) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Bu mahsulot varianti allaqachon qo'shilgan."),
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: displayDimensions == null
                ? AppColors.divider
                : AppColors.primary,
            width: displayDimensions == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
          color: displayDimensions != null
              ? AppColors.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            // Icon(
            //   Icons.straighten_rounded,
            //   size: 14,
            //   color: displayDimensions == null
            //       ? AppColors.textSecondary
            //       : AppColors.primary,
            // ),
            // const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayDimensions ?? "O'lcham",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: displayDimensions == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight:
                          displayDimensions != null ? FontWeight.w600 : null,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: displayDimensions == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Total chip
// ─────────────────────────────────────────────────────────────────────────────

class _TotalChip extends StatelessWidget {
  final String label;
  final String value;

  const _TotalChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
