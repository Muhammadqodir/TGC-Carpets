import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/filter_bar.dart';
import '../../../../core/ui/widgets/filter_date_range_picker.dart';
import '../../../../core/ui/widgets/filter_dropdown.dart';

/// Desktop filter bar for the production batches list page.
/// All filter state is owned by the parent; this widget is purely controlled.
class ProductionBatchFilterBar extends StatelessWidget {
  const ProductionBatchFilterBar({
    super.key,
    required this.selectedStatus,
    required this.selectedType,
    required this.selectedDateRange,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onDateRangeChanged,
    required this.onRefresh,
  });

  final String? selectedStatus;
  final String? selectedType;
  final DateTimeRange? selectedDateRange;

  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onRefresh;

  bool get _hasActiveFilters =>
      selectedStatus != null ||
      selectedType != null ||
      selectedDateRange != null;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      hasActiveFilters: _hasActiveFilters,
      onClearFilters: () {
        onStatusChanged(null);
        onTypeChanged(null);
        onDateRangeChanged(null);
      },
      onRefresh: onRefresh,
      filters: [
        FilterDropdown<String>(
          hint: 'Holat',
          value: selectedStatus,
          items: const [
            DropdownMenuItem(value: 'planned', child: Text('Rejalashtirilgan')),
            DropdownMenuItem(
                value: 'in_progress', child: Text('Ishlab chiqarilmoqda')),
            DropdownMenuItem(value: 'completed', child: Text('Bajarildi')),
            DropdownMenuItem(value: 'cancelled', child: Text('Bekor qilindi')),
          ],
          onChanged: onStatusChanged,
        ),
        const SizedBox(width: 8),
        FilterDropdown<String>(
          hint: 'Tur',
          value: selectedType,
          items: const [
            DropdownMenuItem(
                value: 'by_order', child: Text("Buyurtma bo'yicha")),
            DropdownMenuItem(value: 'for_stock', child: Text('Ombor uchun')),
            DropdownMenuItem(value: 'mixed', child: Text('Aralash')),
          ],
          onChanged: onTypeChanged,
        ),
        const SizedBox(width: 8),
        FilterDateRangePicker(
          value: selectedDateRange,
          onChanged: onDateRangeChanged,
        ),
      ],
    );
  }
}
