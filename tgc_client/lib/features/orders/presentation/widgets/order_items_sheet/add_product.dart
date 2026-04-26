import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_form_controller.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_picker_bottom_sheet.dart';

class AddProduct extends StatelessWidget {
  const AddProduct({super.key, required this.ctrl});

  final OrderFormController ctrl;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await ProductPickerBottomSheet.show(context);
        if (result == null || result.color == null) return;
        final added = ctrl.addMatrixColorRow(result.product, result.color!);
        if (!added && context.mounted) {
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
    );
  }
}
