import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/filter_bar.dart';
import '../../../../core/ui/widgets/filter_dropdown.dart';
import '../../../../core/ui/widgets/filter_search_field.dart';
import '../../domain/entities/color_entity.dart';
import '../../domain/entities/product_quality_entity.dart';
import '../../domain/entities/product_type_entity.dart';

/// Desktop filter bar shown above the products table.
/// All state is owned by the parent; this widget is purely controlled.
class ProductFilterBar extends StatelessWidget {
  const ProductFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.productTypes,
    required this.productQualities,
    required this.colors,
    required this.selectedTypeId,
    required this.selectedQualityId,
    required this.selectedColorId,
    required this.selectedStatus,
    required this.onTypeChanged,
    required this.onQualityChanged,
    required this.onColorChanged,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  final List<ProductTypeEntity> productTypes;
  final List<ProductQualityEntity> productQualities;
  final List<ColorEntity> colors;

  final int? selectedTypeId;
  final int? selectedQualityId;
  final int? selectedColorId;
  final String? selectedStatus;

  final ValueChanged<int?> onTypeChanged;
  final ValueChanged<int?> onQualityChanged;
  final ValueChanged<int?> onColorChanged;
  final ValueChanged<String?> onStatusChanged;

  final VoidCallback onRefresh;

  bool get _hasActiveFilters =>
      selectedTypeId != null ||
      selectedQualityId != null ||
      selectedColorId != null ||
      selectedStatus != null;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      hasActiveFilters: _hasActiveFilters,
      onClearFilters: () {
        onTypeChanged(null);
        onQualityChanged(null);
        onColorChanged(null);
        onStatusChanged(null);
      },
      onRefresh: onRefresh,
      filters: [
        FilterSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
        ),
        const SizedBox(width: 12),
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
                    child: Text(q.density != null
                        ? '${q.qualityName} (${q.density})'
                        : q.qualityName),
                  ))
              .toList(),
          onChanged: onQualityChanged,
        ),
        const SizedBox(width: 8),
        FilterDropdown<int>(
          hint: 'Rang',
          value: selectedColorId,
          items: colors
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList(),
          onChanged: onColorChanged,
        ),
        const SizedBox(width: 8),
        FilterDropdown<String>(
          hint: 'Holat',
          value: selectedStatus,
          items: const [
            DropdownMenuItem(value: 'active', child: Text('Faol')),
            DropdownMenuItem(value: 'archived', child: Text('Arxivlangan')),
          ],
          onChanged: onStatusChanged,
        ),
      ],
    );
  }
}
