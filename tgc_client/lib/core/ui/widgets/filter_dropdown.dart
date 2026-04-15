import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Generic reusable dropdown for desktop filter bars.
///
/// When [value] is non-null the chip is highlighted with a primary-tinted
/// background and a primary border.  A leading "Barchasi" null item is always
/// prepended automatically — pass [allLabel] to override the text.
///
/// Example:
/// ```dart
/// FilterDropdown<int>(
///   hint: 'Turi',
///   value: selectedTypeId,
///   items: types.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
///   onChanged: onTypeChanged,
/// )
/// ```
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.allLabel = 'Barchasi',
  });

  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  /// Label of the first (null-value) "show all" item. Defaults to `'Barchasi'`.
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.divider,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textPrimary),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          isDense: true,
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text(
                allLabel,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
