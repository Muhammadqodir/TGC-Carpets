import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';

/// A generic horizontal option-group selector.
///
/// Renders a row of tappable bordered boxes. An optional [label] is shown above
/// the row as a small secondary-colour caption (same pattern as other form
/// labels in the app).
class AppOptionSelector<T> extends StatelessWidget {
  /// Optional caption shown above the options row.
  final String? label;

  /// The ordered list of selectable options.
  final List<({String label, T value})> options;

  /// Currently selected value.
  final T selected;

  /// Called when the user taps a different option.
  final ValueChanged<T> onChanged;

  const AppOptionSelector({
    super.key,
    this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: options.map((opt) {
            final isSelected = selected == opt.value;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onChanged(opt.value),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.divider,
                        width: isSelected ? 1.5 : 1,
                      ),
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.07)
                          : null,
                    ),
                    child: Text(
                      opt.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
