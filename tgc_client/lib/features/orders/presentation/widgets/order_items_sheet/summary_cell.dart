import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';

class SummaryCell extends StatelessWidget {
  const SummaryCell({
    super.key,
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.04),
        border: Border.all(
            color: isHighlighted ? AppColors.primary : AppColors.divider,
            width: isHighlighted ? 2 : 1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
