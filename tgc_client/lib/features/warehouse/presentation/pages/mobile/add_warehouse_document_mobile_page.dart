import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../products/presentation/widget/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widget/product_size_picker_sheet.dart';
import '../args/warehouse_document_preview_args.dart';
import '../../widget/warehouse_document_form_controller.dart';
import '../../widget/warehouse_item_row.dart';

/// Mobile variant of the "add warehouse document" form.
/// All form state lives in [controller], owned by the parent page.
class AddWarehouseDocumentMobilePage extends StatefulWidget {
  const AddWarehouseDocumentMobilePage({
    super.key,
    required this.controller,
  });

  final WarehouseDocumentFormController controller;

  @override
  State<AddWarehouseDocumentMobilePage> createState() =>
      _AddWarehouseDocumentMobilePageState();
}

class _AddWarehouseDocumentMobilePageState
    extends State<AddWarehouseDocumentMobilePage> {
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

    context.pushNamed(
      AppRoutes.warehouseDocumentPreviewName,
      extra: args,
    ).then((result) {
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
          appBar: AppBar(
            title: const Text('Kirim hujjati'),
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
                      // ── Header info ──────────────────────────────────────
                      const _SectionHeader(title: 'Hujjat ma\'lumotlari'),
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

                      // ── Items ────────────────────────────────────────────
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

                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: SafeArea(
                  top: false,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Ko'rib chiqish"),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Mobile item form row ─────────────────────────────────────────────────────

class _MobileItemFormRow extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
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
            // Row header
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
                ]
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _MobileProductPickerButton(
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
                      // Skip validation for empty rows
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

            if (product != null && product.productTypeId != null) ...[
              const SizedBox(height: 8),
              _MobileSizePicker(
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

class _MobileProductPickerButton extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final VoidCallback onChanged;

  const _MobileProductPickerButton({
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
          color:
              product != null ? AppColors.primary.withValues(alpha: 0.05) : null,
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
                            if (product.productQuality?.qualityName != null)
                              product.productQuality!.qualityName,
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

class _MobileSizePicker extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const _MobileSizePicker({
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
              color:
                  size == null ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                size == null ? 'O\'lcham tanlash' : size.dimensions,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: size == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight:
                          size != null ? FontWeight.w600 : null,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color:
                  size == null ? AppColors.textSecondary : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
