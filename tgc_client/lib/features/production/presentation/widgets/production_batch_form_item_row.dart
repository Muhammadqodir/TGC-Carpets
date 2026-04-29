import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/count_input.dart';
import 'batch_item_row.dart';
import 'production_batch_form_product_picker_cell.dart';
import 'production_batch_form_size_picker_cell.dart';

/// Adaptive row widget for production batch form items.
/// Displays full columns on desktop, compact layout on mobile.
class ProductionBatchFormItemRow extends StatelessWidget {
  final BatchItemRow row;
  final List<BatchItemRow> allItems;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const ProductionBatchFormItemRow({
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
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ProductionBatchFormProductPickerCell(
                  isMobile: !isDesktop,
                  row: row,
                  allItems: allItems,
                  onChanged: onChanged,
                ),
              ),
            ),

            if (isDesktop) ...[
              // Tur/Quality column
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: BodyText(
                    text: "${row.qualityName ?? '—'} / ${row.typeName ?? '—'}",
                  ),
                ),
              ),
            ],

            // Size column
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: product != null && product.productTypeId != null
                    ? ProductionBatchFormSizePickerCell(
                        row: row,
                        allItems: allItems,
                        productTypeId: product.productTypeId!,
                        onChanged: onChanged,
                      )
                    : row.prefilledProductTypeId != null
                        ? ProductionBatchFormSizePickerCell(
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

            if (isDesktop)
              // Source column
              SizedBox(
                width: 150,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: row.sourceClientName != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedAddToList,
                                strokeWidth: 2,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  row.sourceClientName!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ))
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
    });
  }
}
