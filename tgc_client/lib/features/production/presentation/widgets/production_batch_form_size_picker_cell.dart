import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../products/presentation/widgets/product_size_picker_sheet.dart';
import 'batch_item_row.dart';

/// Size picker cell for production batch form.
/// Opens size picker dialog and validates against duplicates.
class ProductionBatchFormSizePickerCell extends StatelessWidget {
  final BatchItemRow row;
  final List<BatchItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const ProductionBatchFormSizePickerCell({
    super.key,
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
        height: 40,
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
            Expanded(
              child: Text(
                displayDimensions ?? "O'lcham",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
