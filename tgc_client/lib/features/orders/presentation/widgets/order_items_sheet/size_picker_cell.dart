import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/products/domain/entities/product_size_entity.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_size_picker_sheet.dart';

class SizePickerCell extends StatelessWidget {
  const SizePickerCell({
    super.key,
    required this.size,
    required this.onRemove,
    required this.onReplace,
  });

  final ProductSizeEntity size;
  final VoidCallback onRemove;
  final void Function(ProductSizeEntity) onReplace;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await ProductSizePickerSheet.show(
          context,
          productTypeId: size.productTypeId,
        );
        if (picked != null) onReplace(picked);
      },
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(5),
      ),
      child: Container(
        width: 120,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(6),
          color: AppColors.primary.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "E: ${size.width}\nU: ${size.length}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
            IconButton(
              color: AppColors.error,
              onPressed: onRemove,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCancelCircle,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
