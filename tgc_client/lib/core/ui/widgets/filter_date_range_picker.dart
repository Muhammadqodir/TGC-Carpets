import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Reusable date-range picker button for desktop filter bars.
///
/// Renders a chip-style [InkWell] that opens [showDateRangePicker] on tap.
/// When a range is selected it shows formatted dates and an inline × button
/// to clear the selection.
class FilterDateRangePicker extends StatelessWidget {
  const FilterDateRangePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Sana',
    this.firstDate,
    this.lastDate,
  });

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;

  /// Placeholder text shown when no range is selected.
  final String hint;

  /// Defaults to `DateTime(2020)`.
  final DateTime? firstDate;

  /// Defaults to `DateTime(2100)`.
  final DateTime? lastDate;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pick(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2100),
      initialDateRange: value,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = value != null;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              isSelected
                  ? '${_fmt(value!.start)} — ${_fmt(value!.end)}'
                  : hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
