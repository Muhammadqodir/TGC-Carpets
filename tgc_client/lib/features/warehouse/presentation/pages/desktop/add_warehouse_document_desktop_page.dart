import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/ui/widgets/desktop_status_bar.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../products/presentation/widgets/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widgets/product_size_picker_sheet.dart';
import '../args/warehouse_document_preview_args.dart';
import '../../widgets/warehouse_document_form_controller.dart';
import '../../widgets/warehouse_item_row.dart';

/// Desktop variant of the "add warehouse document" form.
/// Displays items as an editable table with sticky column headers.
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

    final hasUnpickedColor = filledItems.any((r) => r.selectedColor == null);
    if (hasUnpickedColor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcha qatorlardagi mahsulot rangini tanlang.'),
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

    final previewItems = filledItems
        .map((row) => WarehouseItemPreviewRow(
              productId: row.selectedProduct!.id,
              productName: row.selectedProduct!.name,
              quality: row.selectedProduct!.productQuality?.qualityName,
              type: row.selectedProduct!.productType?.type,
              color: row.selectedColor?.colorName,
              productColorId: row.selectedColor?.id,
              productSizeId: row.selectedSize?.id,
              sizeLabel: row.selectedSize?.dimensions,
              sizeLength: row.selectedSize?.length,
              sizeWidth: row.selectedSize?.width,
              quantity: int.parse(row.quantityCtrl.text.trim()),
              itemNotes: row.notesCtrl.text.trim().isEmpty
                  ? null
                  : row.notesCtrl.text.trim(),
            ))
        .toList();

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
                // ── Items header label ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  child: Text(
                    'Mahsulotlar',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),

                // ── Table header ───────────────────────────────────────────────
                const _DesktopTableHeader(),
                const Divider(height: 1, color: AppColors.divider),

                // ── Table rows ─────────────────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: ctrl.items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final row = ctrl.items[index];
                      return _DesktopItemTableRow(
                        key: ValueKey(row.id),
                        row: row,
                        allItems: ctrl.items,
                        index: index,
                        canRemove: row.selectedProduct != null,
                        onRemove: () => ctrl.removeItem(index),
                        onChanged: ctrl.notifyChanged,
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: ctrl.notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Izoh (ixtiyoriy)',
                          hintText: 'Qo\'shimcha ma\'lumot...',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                DesktopStatusBar(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text('Hujjat sanasi: $_formattedDate'),
                      ),
                      Expanded(
                        child: Text(
                          textAlign: TextAlign.end,
                          'Xodim: ${ctrl.username.isEmpty ? 'Noma\'lum' : ctrl.username}',
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
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

// ── Desktop table header ─────────────────────────────────────────────────────

class _DesktopTableHeader extends StatelessWidget {
  const _DesktopTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          _HeaderCell(label: '#', fixedWidth: 40),
          _HeaderCell(label: 'Mahsulot', flex: 3),
          _HeaderCell(label: 'Sifat', flex: 1),
          _HeaderCell(label: 'Tur', flex: 1),
          _HeaderCell(label: 'Rang', flex: 2),
          _HeaderCell(label: 'O\'lcham', flex: 2),
          _HeaderCell(label: 'Miqdor', fixedWidth: 150),
          _HeaderCell(label: 'Izoh', flex: 2),
          const SizedBox(width: 40), // actions column
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

// ── Desktop editable item row ─────────────────────────────────────────────────

class _DesktopItemTableRow extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _DesktopItemTableRow({
    super.key,
    required this.row,
    required this.allItems,
    required this.index,
    required this.canRemove,
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
              child: _DesktopProductPickerCell(
                row: row,
                allItems: allItems,
                onChanged: onChanged,
              ),
            ),
          ),

          // Quality
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: product?.productQuality != null
                  ? Text(
                      product!.productQuality!.qualityName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text('—',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
            ),
          ),

          // Type
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: product?.productType != null
                  ? Text(
                      product!.productType!.type,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text('—',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
            ),
          ),

          // Color (thumbnail + name)
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
                  : Text('—',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
            ),
          ),

          // Size picker
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: product != null && product.productTypeId != null
                  ? _DesktopSizePickerCell(
                      row: row,
                      allItems: allItems,
                      productTypeId: product.productTypeId!,
                      onChanged: onChanged,
                    )
                  : Text('—',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
            ),
          ),

          // Quantity
          SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CountInput(
                controller: row.quantityCtrl,
                dense: true,
                validator: (v) {
                  // Skip validation for empty rows
                  if (product == null) return null;
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
            child: canRemove
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

// ── Desktop cell widgets ──────────────────────────────────────────────────────

class _DesktopProductPickerCell extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final VoidCallback onChanged;

  const _DesktopProductPickerCell({
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
                    content: Text(
                        'Bu mahsulot varianti allaqachon qo\'shilgan.'),
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: product == null ? AppColors.divider : AppColors.primary,
            width: product == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
          color: product != null
              ? AppColors.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              product == null
                  ? Icons.search_rounded
                  : Icons.inventory_2_outlined,
              size: 14,
              color:
                  product == null ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                product == null ? 'Mahsulot tanlash' : product.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: product == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (product != null)
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

class _DesktopSizePickerCell extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const _DesktopSizePickerCell({
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: size == null ? AppColors.divider : AppColors.primary,
            width: size == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
          color:
              size != null ? AppColors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 14,
              color: size == null ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                size == null ? 'O\'lcham' : size.dimensions,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: size == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: size != null ? FontWeight.w600 : null,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
