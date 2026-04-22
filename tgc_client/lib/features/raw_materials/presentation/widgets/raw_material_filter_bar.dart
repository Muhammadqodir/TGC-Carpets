import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/filter_bar.dart';
import '../../../../core/ui/widgets/filter_dropdown.dart';
import '../../../../core/ui/widgets/filter_search_field.dart';

/// Desktop filter bar for the Raw Materials screen.
/// All state is owned by the parent; this widget is purely controlled.
class RawMaterialFilterBar extends StatelessWidget {
  const RawMaterialFilterBar({
    super.key,
    required this.types,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onRefresh,
    required this.searchController,
    required this.onSearchChanged,
  });

  final List<String> types;
  final String? selectedType;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onRefresh;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  bool get _hasActiveFilters => selectedType != null;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      hasActiveFilters: _hasActiveFilters,
      onClearFilters: () => onTypeChanged(null),
      onRefresh: onRefresh,
      filters: [
        FilterSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
          hint: 'Xom ashyo qidirish...',
        ),
        const SizedBox(width: 8),
        FilterDropdown<String>(
          hint: 'Turi',
          value: selectedType,
          items: types
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: onTypeChanged,
        ),
      ],
    );
  }
}
