import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../../core/ui/widgets/desktop_status_bar.dart';
import '../../../../products/presentation/widgets/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widgets/product_size_picker_sheet.dart';
import '../args/warehouse_document_preview_args.dart';
import '../../widgets/production_batch_picker_bottom_sheet.dart';
import '../../widgets/warehouse_document_form_controller.dart';
import '../../widgets/warehouse_item_row.dart';

/// Desktop variant of the "add warehouse document" form.
/// Displays items as an editable table that mirrors the production batch form
/// structure. Supports both manual entry and import from production batches.
/// All form state lives in [controller], owned by the parent page.
class AddWarehouseDocumentDesktopPage extends StatefulWidget {
  const AddWarehouseDocumentDesktopPage({
    super.key,
    required this.controller,
  });

  final WarehouseDocumentFormController controller;

  @override
  State<AddWarehouseDocumentDesktopPage> createState() =>
      _AddWarehouseDocumentDesktopPageState();
}

class _AddWarehouseDocumentDesktopPageState
    extends State<AddWarehouseDocumentDesktopPage> {
  final _formKey = GlobalKey<FormState>();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

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

    // Only manually-added rows without a batch source need color/size validation.
    final manualRows = filledItems.where((r) => r.sourceBatchId == null);

    final hasUnpickedColor =
        manualRows.any((r) => r.selectedColor == null);
    if (hasUnpickedColor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcha qatorlardagi mahsulot rangini tanlang.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final hasUnpickedSize = manualRows.any(
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

    final previewItems = filledItems.map((row) {
      final productId = row.selectedProduct?.id ?? row.prefilledProductId;
      final productName =
          row.selectedProduct?.name ?? row.prefilledProductName ?? '';
      final quality = row.selectedProduct?.productQuality?.qualityName ??
          row.prefilledQualityName;
      final type =
          row.selectedProduct?.productType?.type ?? row.prefilledTypeName;
      final colorName =
          row.selectedColor?.colorName ?? row.prefilledColorName;
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      final sizeId = row.selectedSize?.id ?? row.prefilledSizeId;
      final sizeLabel =
          row.selectedSize?.dimensions ?? row.prefilledSizeDimensions;
      final sizeLength = row.selectedSize?.length ?? row.prefilledSizeLength;
      final sizeWidth = row.selectedSize?.width ?? row.prefilledSizeWidth;

      return WarehouseItemPreviewRow(
        productId: productId!,
        productName: productName,
        quality: quality,
        type: type,
        color: colorName,
        productColorId: colorId,
        productSizeId: sizeId,
        sizeLabel: sizeLabel,
        sizeLength: sizeLength,
        sizeWidth: sizeWidth,
        quantity: int.tryParse(row.quantityCtrl.text.trim()) ?? 1,
        itemNotes: row.notesCtrl.text.trim().isEmpty
            ? null
            : row.notesCtrl.text.trim(),
        sourceClientShopName: row.sourceClientShopName,
        sourceClientRegion: row.sourceClientRegion,
        isOrderItem: row.sourceType == 'order_item',
      );
    }).toList();

    final args = WarehouseDocumentPreviewArgs(
      type: 'in',
      documentDate: DateTime.now(),
      notes: ctrl.notesCtrl.text.trim().isEmpty
          ? null
          : ctrl.notesCtrl.text.trim(),
      username: ctrl.username.isEmpty ? 'Noma\'lum' : ctrl.username,
      items: previewItems,
    );

    context
        .pushNamed(
      AppRoutes.warehouseDocumentPreviewName,
      extra: args,
    )
        .then((result) {
      if (result != null && mounted) context.pop(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Kirim hujjati'),
            titleSpacing: 0,
            leading: IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                strokeWidth: 2,
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text("Ko'rib chiqish"),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Items section label + import button ─────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
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
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
                      child: TextButton.icon(
                        onPressed: () async {
                          final result =
                              await ProductionBatchPickerBottomSheet.show(
                                  context);
                          if (result != null && mounted) {
                            ctrl.addRowsFromProductionBatch(
                                result.batch, result.items);
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Partiyadan import'),
                      ),
                    ),
                  ],
                ),

                // ── Table header ────────────────────────────────────────────
                const _DesktopTableHeader(),
                const Divider(height: 1, color: AppColors.divider),

                // ── Table rows ──────────────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: ctrl.items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final row = ctrl.items[index];
                      return _DesktopItemRow(
                        key: ValueKey(row.id),
                        row: row,
                        allItems: ctrl.items,
                        index: index,
                        onRemove: () => ctrl.removeRow(index),
                        onChanged: () {
                          ctrl.promoteIfSentinel(row);
                          ctrl.updateRow(row);
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),

                // ── Notes ───────────────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: TextFormField(
                    controller: ctrl.notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Izoh (ixtiyoriy)',
                      hintText: "Qo'shimcha ma'lumot...",
                      alignLabelWithHint: true,
                    ),
                  ),
                ),

                // ── Status bar ──────────────────────────────────────────────
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
                            label: 'Mahsulotlar', value: '${filled.length}'),
                        const SizedBox(width: 16),
                        _TotalChip(label: 'Jami dona', value: '$totalQty'),
                        const SizedBox(width: 16),
                        _TotalChip(
                            label: 'Jami m²',
                            value: '${totalSqm.toStringAsFixed(2)} m²'),
                        const Spacer(),
                        Text(
                          'Sana: $_formattedDate  ·  Xodim: ${ctrl.username.isEmpty ? 'Noma\'lum' : ctrl.username}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _formattedDate {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

// ── Status bar chip ───────────────────────────────────────────────────────────

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
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ── Desktop table header ──────────────────────────────────────────────────────

class _DesktopTableHeader extends StatelessWidget {
  const _DesktopTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: const Row(
        children: [
          _HeaderCell(label: '#', fixedWidth: 40),
          _HeaderCell(label: 'Mahsulot', flex: 3),
          _HeaderCell(label: 'Rang', flex: 2),
          _HeaderCell(label: 'Tur', flex: 1),
          _HeaderCell(label: 'Sifat', flex: 1),
          _HeaderCell(label: 'O\'lcham', flex: 2),
          _HeaderCell(label: 'Mijoz', flex: 2),
          _HeaderCell(label: 'Miqdor', fixedWidth: 130),
          _HeaderCell(label: 'Izoh', flex: 2),
          SizedBox(width: 40),
        ],
      ),
    );
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

// ── Desktop item row ──────────────────────────────────────────────────────────

class _DesktopItemRow extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _DesktopItemRow({
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

    return Container(
      color: isEven ? null : AppColors.surface.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // #
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
              child: _DesktopProductCell(
                row: row,
                allItems: allItems,
                onChanged: onChanged,
              ),
            ),
          ),

          // Color column — entity first, prefill as fallback
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
                                style: Theme.of(context).textTheme.bodyMedium,
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

          // Tur column
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: row.typeName != null
                  ? Text(
                      row.typeName!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

          // Sifat column
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: row.qualityName != null
                  ? Text(
                      row.qualityName!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

          // Size column
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: product != null && product.productTypeId != null
                  ? _DesktopSizeCell(
                      row: row,
                      allItems: allItems,
                      productTypeId: product.productTypeId!,
                      onChanged: onChanged,
                    )
                  : row.prefilledProductTypeId != null
                      ? _DesktopSizeCell(
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

          // Partiya (source batch) column
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: row.sourceBatchTitle != null
                  ? Builder(builder: (context) {
                      final isOrder = row.sourceType == 'order_item';
                      final label = isOrder && row.sourceClientShopName != null
                          ? [
                              row.sourceClientShopName!,
                              if (row.sourceClientRegion != null)
                                row.sourceClientRegion!,
                            ].join(' / ')
                          : row.sourceBatchTitle!;
                      final color =
                          isOrder ? AppColors.success : AppColors.primary;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: color,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isOrder
                                  ? Icons.person_outline_rounded
                                  : Icons.precision_manufacturing_outlined,
                              size: 14,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                label,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                  : const SizedBox.shrink(),
            ),
          ),

          // Quantity
          SizedBox(
            width: 130,
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

          // Notes
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextFormField(
                controller: row.notesCtrl,
                decoration: const InputDecoration(
                  hintText: 'Izoh...',
                  isDense: true,
                ),
              ),
            ),
          ),

          // Remove action
          SizedBox(
            width: 40,
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
  }
}

// ── Desktop product picker cell ───────────────────────────────────────────────

class _DesktopProductCell extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final VoidCallback onChanged;

  const _DesktopProductCell({
    required this.row,
    required this.allItems,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    final isPrefilled = product == null && row.prefilledColorId != null;
    final displayName = product?.name ?? row.prefilledProductName;

    return InkWell(
      onTap: () async {
        final result = await ProductPickerBottomSheet.show(context);
        if (result != null) {
          row.selectedProduct = result.product;
          row.selectedColor = result.color;
          row.selectedSize = null;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
            Icon(
              displayName == null
                  ? Icons.search_rounded
                  : Icons.inventory_2_outlined,
              size: 14,
              color: displayName == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayName ?? 'Mahsulot tanlash',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: displayName == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

// ── Desktop size picker cell ──────────────────────────────────────────────────

class _DesktopSizeCell extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const _DesktopSizeCell({
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
          final isDuplicate = allItems.any(
            (r) {
              final rColorId = r.selectedColor?.id ?? r.prefilledColorId;
              final mColorId = row.selectedColor?.id ?? row.prefilledColorId;
              return r.id != row.id &&
                  rColorId == mColorId &&
                  r.selectedSize?.id == picked.id;
            },
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
            Icon(
              Icons.straighten_rounded,
              size: 14,
              color: displayDimensions == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayDimensions ?? 'O\'lcham',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: displayDimensions == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: displayDimensions != null
                          ? FontWeight.w600
                          : null,
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


