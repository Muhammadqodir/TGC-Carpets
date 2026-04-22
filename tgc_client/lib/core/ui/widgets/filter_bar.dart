import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../theme/app_colors.dart';

/// Reusable desktop filter bar container.
///
/// Provides the consistent surface background, padding, Spacer, optional
/// clear-filters button and refresh button.  The caller builds the individual
/// filter chips/dropdowns and passes them as [filters].
///
/// Spacing between filters (e.g. [SizedBox] width 8) should be included in
/// the [filters] list, exactly as it was in each feature's own Row.
///
/// Example:
/// ```dart
/// FilterBar(
///   filters: [
///     FilterSearchField(controller: _search, onChanged: _onSearch),
///     const SizedBox(width: 12),
///     FilterDropdown<int>(hint: 'Turi', value: _type, items: ..., onChanged: ...),
///     const SizedBox(width: 8),
///     FilterDropdown<int>(hint: 'Sifat', value: _quality, items: ..., onChanged: ...),
///   ],
///   hasActiveFilters: _hasActiveFilters,
///   onClearFilters: _clearFilters,
///   onRefresh: _load,
/// )
/// ```
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.filters,
    this.hasActiveFilters = false,
    this.onClearFilters,
    this.onRefresh,
  });

  /// The filter widgets (including spacing SizedBoxes between them).
  final List<Widget> filters;

  /// When `true` and [onClearFilters] is provided, shows the clear-filters
  /// icon button in error colour.
  final bool hasActiveFilters;

  final VoidCallback? onClearFilters;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ...filters,
              if (hasActiveFilters && onClearFilters != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Filtrlarni tozalash',
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFilterRemove,
                    strokeWidth: 1.5,
                  ),
                  color: AppColors.error,
                  onPressed: onClearFilters,
                ),
              ],
              // const Spacer(),
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Yangilash',
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedReload,
                    strokeWidth: 2.5,
                  ),
                  onPressed: onRefresh,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
