import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/products/domain/entities/product_size_entity.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_product_size_multi_picker_sheet.dart';

class AddSize extends StatelessWidget {
  const AddSize({
    super.key,
    required this.onSizeAdded,
    required this.alreadySelectedSizeIds,
  });

  final bool Function(ProductSizeEntity) onSizeAdded;
  final Set<int> alreadySelectedSizeIds;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: InkWell(
        onTap: () async {
          final picked = await OrderProductSizeMultiPickerSheet.show(
            context,
            alreadySelectedSizeIds: alreadySelectedSizeIds,
          );
          if (picked != null && picked.isNotEmpty) {
            // Add all selected sizes
            for (final size in picked) {
              onSizeAdded(size);
            }
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              SizedBox(width: 6),
              HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: 14,
                strokeWidth: 2,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Qo'shish",
                  style: TextStyle(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
