import 'package:flutter/material.dart';

/// A small rounded status pill. Generic and reusable across all features.
///
/// Usage:
/// ```dart
/// AppStatusChip(label: 'Faol', color: AppColors.success)
/// AppStatusChip(label: 'Arxivlangan', color: AppColors.textSecondary)
/// ```
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
