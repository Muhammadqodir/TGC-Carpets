import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Status bar chip for displaying production batch metrics.
class ProductionBatchFormTotalChip extends StatelessWidget {
  final String label;
  final String value;

  const ProductionBatchFormTotalChip({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
