import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_form_controller.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_item_row.dart';
import 'package:tgc_client/features/products/domain/entities/product_size_entity.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_picker_bottom_sheet.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_size_picker_sheet.dart';

class OrderItemsSheet extends StatefulWidget {
  const OrderItemsSheet({super.key, required this.ctrl});

  final OrderFormController ctrl;

  @override
  State<OrderItemsSheet> createState() => _OrderItemsSheetState();
}

class _OrderItemsSheetState extends State<OrderItemsSheet> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onCtrlChanged);
  }

  void _onCtrlChanged() => setState(() {});

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrlChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: Column(
            children: [
              SizedBox(height: 40),
              ...widget.ctrl.getUniqueItems().map(
                    (row) => _ProductPickerCell(
                      row: row,
                      allItems: widget.ctrl.filledItems,
                      onChanged: widget.ctrl.notifyChanged,
                    ),
                  ),
              // _ProductPickerCell(row: , allItems: allItems, onChanged: widget.ctrl.notifyChanged)
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //Sizes list
                Row(
                  children: [
                    ...widget.ctrl.matrixSizeColumns.map(
                      (size) => Container(
                        width: 100,
                        height: 40,
                        padding: EdgeInsets.all(8),
                        child: Text("${size.width}x${size.length}"),
                      ),
                    ),
                    _AddSize(onSizeAdded: (ProductSizeEntity size) {
                      widget.ctrl.addMatrixSizeColumn(size);
                    }),
                  ],
                ),

                // Quantity cells — one row per filled product+colour, one cell per size
                ...widget.ctrl.filledItems.map(
                  (row) {
                    final colorId =
                        row.selectedColor?.id ?? row.prefilledColorId;
                    if (colorId == null) return const SizedBox.shrink();
                    return SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          ...widget.ctrl.matrixSizeColumns.map(
                            (size) => SizedBox(
                              width: 100,
                              height: 40,
                              child: TextField(
                                controller: widget.ctrl
                                    .matrixCellCtrl(colorId, size.id),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 13),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide:
                                        BorderSide(color: AppColors.divider),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide:
                                        BorderSide(color: AppColors.divider),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(5)),
                                    borderSide: BorderSide(
                                        color: AppColors.primary, width: 1.5),
                                  ),
                                  hintText: '—',
                                  hintStyle: const TextStyle(
                                      color: AppColors.divider, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
        height: 40,
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

class _AddSize extends StatelessWidget {
  final Function(ProductSizeEntity) onSizeAdded;

  const _AddSize({required this.onSizeAdded, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: InkWell(
        onTap: () async {
          final picked = await ProductSizePickerSheet.show(
            context,
          );
          if (picked != null) {
            onSizeAdded(picked);
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.primary,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
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
                  "O'lcham qo'shish",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.add,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
