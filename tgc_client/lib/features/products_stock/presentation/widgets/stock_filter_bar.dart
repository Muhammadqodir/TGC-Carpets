import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/filter_bar.dart';
import '../../../../core/ui/widgets/filter_dropdown.dart';
import '../../../../core/ui/widgets/filter_search_field.dart';
import '../../../products/domain/entities/product_quality_entity.dart';
import '../../../products/domain/entities/product_type_entity.dart';

/// Desktop filter bar for the Products Stock screen.
/// All state is owned by the parent; this widget is purely controlled.
class StockFilterBar extends StatelessWidget {
  const StockFilterBar({
    super.key,
    required this.productTypes,
    required this.productQualities,
    required this.selectedTypeId,
    required this.selectedQualityId,
    required this.onTypeChanged,
    required this.onQualityChanged,
    required this.onRefresh,
    required this.searchController,
    required this.onSearchChanged,
  });

  final List<ProductTypeEntity> productTypes;
  final List<ProductQualityEntity> productQualities;

  final int? selectedTypeId;
  final int? selectedQualityId;

  final ValueChanged<int?> onTypeChanged;
  final ValueChanged<int?> onQualityChanged;

  final VoidCallback onRefresh;

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  bool get _hasActiveFilters =>
      selectedTypeId != null ||
      selectedQualityId != null;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      hasActiveFilters: _hasActiveFilters,
      onClearFilters: () {
        onTypeChanged(null);
        onQualityChanged(null);
      },
      onRefresh: onRefresh,
      filters: [
        FilterSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
        ),
        const SizedBox(width: 8),
        FilterDropdown<int>(
          hint: 'Turi',
          value: selectedTypeId,
          items: productTypes
              .map((t) => DropdownMenuItem(value: t.id, child: Text(t.type)))
              .toList(),
          onChanged: onTypeChanged,
        ),
        const SizedBox(width: 8),
        FilterDropdown<int>(
          hint: 'Sifat',
          value: selectedQualityId,
          items: productQualities
              .map((q) => DropdownMenuItem(
                    value: q.id,
                    child: Text(
                      q.density != null
                          ? '${q.qualityName} (${q.density})'
                          : q.qualityName,
                    ),
                  ))
              .toList(),
          onChanged: onQualityChanged,
        ),
      ],
    );
  }
}
