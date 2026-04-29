import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../products/presentation/widgets/product_size_picker_sheet.dart';
import 'warehouse_item_row.dart';

/// Size picker cell for warehouse document form.
/// Opens size picker sheet and validates for duplicates.
class WarehouseDocumentFormSizePickerCell extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const WarehouseDocumentFormSizePickerCell({
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
