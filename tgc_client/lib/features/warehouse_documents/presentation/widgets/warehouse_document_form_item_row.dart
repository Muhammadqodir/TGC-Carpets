import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/count_input.dart';
import 'warehouse_document_form_product_picker_cell.dart';
import 'warehouse_document_form_size_picker_cell.dart';
import 'warehouse_item_row.dart';

/// Adaptive row widget for warehouse document form items.
/// Displays full columns on desktop, compact layout on mobile.
class WarehouseDocumentFormItemRow extends StatelessWidget {
  final WarehouseItemRow row;
  final List<WarehouseItemRow> allItems;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const WarehouseDocumentFormItemRow({
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
      final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      return Container(
        color: isEven ? null : AppColors.surface.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment:
              isDesktop ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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

            // Product picker (product name + color, quality on mobile)
            Expanded(
              flex: isDesktop ? 1 : 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: WarehouseDocumentFormProductPickerCell(
                  isMobile: !isDesktop,
                  row: row,
                  allItems: allItems,
                  onChanged: onChanged,
                ),
              ),
            ),

            if (isDesktop) ...[
              // Quality / Type column (desktop only)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    "${row.qualityName ?? '—'} / ${row.typeName ?? '—'}",
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Size column (desktop only)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildSizeCell(context, product),
                ),
              ),
              // Client / Batch column (mobile only)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildClientBatchCell(context),
                ),
              ),
            ],

            // Quantity
            SizedBox(
              width: 130,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CountInput(
                  height: 40,
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

  Widget _buildSizeCell(BuildContext context, dynamic product) {
    if (product != null && product.productTypeId != null) {
      return WarehouseDocumentFormSizePickerCell(
        row: row,
        allItems: allItems,
        productTypeId: product.productTypeId!,
        onChanged: onChanged,
      );
    } else if (row.prefilledProductTypeId != null) {
      return WarehouseDocumentFormSizePickerCell(
        row: row,
        allItems: allItems,
        productTypeId: row.prefilledProductTypeId!,
        onChanged: onChanged,
      );
    } else if (row.prefilledSizeDimensions != null) {
      return Text(
        row.prefilledSizeDimensions!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      );
    } else {
      return Text(
        '—',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      );
    }
  }

  Widget _buildClientBatchCell(BuildContext context) {
    if (row.sourceBatchTitle == null) {
      return const SizedBox.shrink();
    }

    final isOrder = row.sourceType == 'order_item';
    final label = isOrder
        ? [
            if (row.sourceClientShopName != null) row.sourceClientShopName!,
            if (row.sourceClientRegion != null) row.sourceClientRegion!,
          ].join(' / ')
        : 'Ombor uchun';
    final color = isOrder ? AppColors.success : AppColors.primary;

    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 8),
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
            isOrder ? Icons.person_outline_rounded : Icons.warehouse_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  row.sourceBatchTitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
