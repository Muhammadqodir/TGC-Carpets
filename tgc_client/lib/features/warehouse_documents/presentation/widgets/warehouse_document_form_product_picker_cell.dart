import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../products/presentation/widgets/product_picker_bottom_sheet.dart';
import 'warehouse_item_row.dart';

/// Product picker cell for warehouse document form.
/// Opens product picker dialog and updates the row on selection.
/// Displays product name and color on desktop, adds quality on mobile.
class WarehouseDocumentFormProductPickerCell extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final VoidCallback onChanged;
  final bool isMobile;

  const WarehouseDocumentFormProductPickerCell({
    super.key,
    required this.row,
    required this.allItems,
    required this.onChanged,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    final isPrefilled = product == null && row.prefilledColorId != null;
    final String displayName =
        product?.name ?? row.prefilledProductName ?? 'Mahsulot tanlang';
    final String? displayColor =
        row.selectedColor?.colorName ?? row.prefilledColorName;
    final String? displayQuality =
        product?.productQuality?.qualityName ?? row.prefilledQualityName;
    final String colorThumbnail =
        row.selectedColor?.imageUrl ?? row.prefilledColorImageUrl ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
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
            height: 40,
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
                AppThumbnail(
                  imageUrl: colorThumbnail,
                  size: 28,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                      ),
                      if (displayColor != null)
                        Text(
                          "${displayColor.toUpperCase()}${!isMobile ? '' : ' / ${displayQuality ?? 'Sifat Noma\'lum'}'}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1,
                                  ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isMobile && row.sourceClientShopName != null) ...[
          SizedBox(height: 4),
          AppBadge(
            label:
                " ${row.sourceClientShopName ?? '-'} / ${row.sourceClientRegion ?? '-'}",
            color: AppColors.success,
          )
        ]
      ],
    );
  }
}
