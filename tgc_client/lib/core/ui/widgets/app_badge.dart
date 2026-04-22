import 'package:flutter/material.dart';

/// A small coloured label pill. Generic and reusable across all features.
///
/// Usage:
/// ```dart
/// AppBadge(label: 'Juda yaxshi', color: AppColors.success)
/// ```
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.textColor = Colors.white,
    this.color = Colors.black,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
