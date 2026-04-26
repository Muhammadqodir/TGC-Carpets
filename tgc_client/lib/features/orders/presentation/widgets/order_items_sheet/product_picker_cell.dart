import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_form_controller.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_item_row.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_picker_bottom_sheet.dart';

class ProductPickerCell extends StatelessWidget {
  final OrderItemRow row;
  final OrderFormController ctrl;
  final Function() onDelete;

  const ProductPickerCell({
    super.key,
    required this.row,
    required this.ctrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    final isPrefilled = product == null && row.prefilledColorId != null;
    final displayName = product?.name ?? row.prefilledProductName;
    final displayColor = row.selectedColor?.colorName ?? row.prefilledColorName;
    return InkWell(
      onTap: () async {
        final oldColorId = row.selectedColor?.id ?? row.prefilledColorId;
        final result = await ProductPickerBottomSheet.show(context);
        if (result == null || result.color == null || oldColorId == null) {
          return;
        }
        final updated = ctrl.updateMatrixProductRow(
          oldColorId,
          result.product,
          result.color!,
        );
        if (!updated && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Bu mahsulot varianti allaqachon qo'shilgan."),
              backgroundColor: AppColors.error,
            ),
          );
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1,
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (displayName != null)
              IconButton(
                onPressed: onDelete,
                color: AppColors.error,
                icon: HugeIcon(
                  strokeWidth: 2,
                  icon: HugeIcons.strokeRoundedCancelCircle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
