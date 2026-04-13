import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../products/presentation/widgets/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widgets/product_size_picker_sheet.dart';
import '../args/warehouse_document_preview_args.dart';
import '../../widgets/production_batch_picker_bottom_sheet.dart';
import '../../widgets/warehouse_document_form_controller.dart';
import '../../widgets/warehouse_item_row.dart';
import 'qr_scanner_screen.dart';

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
          content: Text("Kamida bitta mahsulot qo'shing."),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Only manually-added rows (no batch source) need color/size validation.
    final manualRows = filledItems.where((r) => r.sourceBatchId == null);

    final hasUnpickedColor = manualRows.any((r) => r.selectedColor == null);
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
          content: Text("Barcha qatorlardagi mahsulot o'lchamini tanlang."),
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
      final colorName = row.selectedColor?.colorName ?? row.prefilledColorName;
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
      username: ctrl.username.isEmpty ? "Noma'lum" : ctrl.username,
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
          appBar: AppBar(
            title: const Text('Kirim hujjati'),
            leading: IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                strokeWidth: 2,
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                tooltip: 'QR-kodni skanerlash',
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: () async {
                  final result = await QrScannerScreen.show(context);
                  if (result != null && mounted) {
                    ctrl.addOrIncrementFromQr(
                      result.item,
                      batchId: result.batchId,
                      batchTitle: result.batchTitle,
                    );
                  }
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Notes
                      TextFormField(
                        controller: ctrl.notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Izoh (ixtiyoriy)',
                          hintText: "Qo'shimcha ma'lumot...",
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section header + import button
                      Row(
                        children: [
                          Text(
                            'Mahsulotlar',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const Spacer(),
                          TextButton.icon(
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
                            label: const Text('Partiyadan'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ...ctrl.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;
                        return _MobileItemCard(
                          key: ValueKey(row.id),
                          row: row,
                          allItems: ctrl.items,
                          index: index,
                          onRemove: () => ctrl.removeRow(index),
                          canRemove: row.isFilled,
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

// -- Mobile item card --

class _MobileItemCard extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final int index;
  final VoidCallback onRemove;
  final bool canRemove;
  final VoidCallback onProductChanged;

  const _MobileItemCard({
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
                if (row.sourceBatchTitle != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (row.sourceType == 'order_item'
                              ? AppColors.success
                              : AppColors.primary)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: row.sourceType == 'order_item'
                            ? AppColors.success
                            : AppColors.primary,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          row.sourceType == 'order_item'
                              ? Icons.person_outline_rounded
                              : Icons.precision_manufacturing_outlined,
                          size: 11,
                          color: row.sourceType == 'order_item'
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          row.sourceType == 'order_item' &&
                                  row.sourceClientShopName != null
                              ? [
                                  row.sourceClientShopName!,
                                  if (row.sourceClientRegion != null)
                                    row.sourceClientRegion!,
                                ].join(' / ')
                              : row.sourceBatchTitle!,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: row.sourceType == 'order_item'
                                      ? AppColors.success
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (canRemove)
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
                      if (!row.isFilled) return null;
                      if (v == null || v.trim().isEmpty) return 'Miqdorni kiriting';
                      final qty = int.tryParse(v);
                      if (qty == null || qty < 1) return 'Kamida 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            // Prefill meta for batch-imported rows
            if (row.sourceBatchId != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (row.prefilledColorName != null) ...[
                    AppThumbnail(
                      imageUrl: row.prefilledColorImageUrl,
                      size: 20,
                      borderRadius: 4,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      row.prefilledColorName!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  if (row.prefilledSizeDimensions != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      row.prefilledSizeDimensions!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  if (row.qualityName != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      row.qualityName!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
            // Size picker for manually-added rows with product type
            if (row.sourceBatchId == null &&
                product != null &&
                product.productTypeId != null) ...[
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

// -- Mobile product picker button --

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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: (product == null && !isPrefilled)
                ? AppColors.divider
                : AppColors.primary,
            width: (product == null && !isPrefilled) ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
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
              size: 18,
              color: displayName == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayName ?? 'Mahsulot tanlash',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// -- Mobile size picker --

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
          color:
              size != null ? AppColors.primary.withValues(alpha: 0.05) : null,
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
                size == null ? "O'lcham tanlash" : size.dimensions,
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
