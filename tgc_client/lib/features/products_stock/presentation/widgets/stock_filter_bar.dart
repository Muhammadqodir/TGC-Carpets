import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/filter_bar.dart';
import '../../../../core/ui/widgets/filter_dropdown.dart';
import '../../../../core/ui/widgets/filter_search_field.dart';
import '../../../products/domain/entities/product_quality_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../../products/domain/entities/product_type_entity.dart';

/// Desktop filter bar for the Products Stock screen.
/// All state is owned by the parent; this widget is purely controlled.
///
/// Size dropdown items update dynamically whenever [productSizes] changes
/// (the parent loads sizes filtered by the selected type).
class StockFilterBar extends StatelessWidget {
  const StockFilterBar({
    super.key,
    required this.productTypes,
    required this.productQualities,
    required this.productSizes,
    required this.selectedTypeId,
    required this.selectedQualityId,
    required this.selectedSizeId,
    required this.onTypeChanged,
    required this.onQualityChanged,
    required this.onSizeChanged,
    required this.onRefresh,
    required this.searchController,
    required this.onSearchChanged,
    this.isLoadingSizes = false,
  });

  final List<ProductTypeEntity> productTypes;
  final List<ProductQualityEntity> productQualities;
  final List<ProductSizeEntity> productSizes;

  final int? selectedTypeId;
  final int? selectedQualityId;
  final int? selectedSizeId;

  final ValueChanged<int?> onTypeChanged;
  final ValueChanged<int?> onQualityChanged;
  final ValueChanged<int?> onSizeChanged;

  final VoidCallback onRefresh;
  final bool isLoadingSizes;

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  bool get _hasActiveFilters =>
      selectedTypeId != null ||
      selectedQualityId != null ||
      selectedSizeId != null;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      hasActiveFilters: _hasActiveFilters,
      onClearFilters: () {
        onTypeChanged(null);
        onQualityChanged(null);
        onSizeChanged(null);
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
        if (selectedTypeId != null) ...[
          const SizedBox(width: 8),
          isLoadingSizes
              ? const SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : FilterDropdown<int>(
                  hint: "O'lcham",
                  value: selectedSizeId,
                  items: productSizes
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.dimensions),
                          ))
                      .toList(),
                  onChanged: onSizeChanged,
                ),
        ],
      ],
    );
  }
}
