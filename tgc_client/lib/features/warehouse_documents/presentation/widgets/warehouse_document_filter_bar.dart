import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/filter_bar.dart';
import '../../../../core/ui/widgets/filter_date_range_picker.dart';
import '../../../../core/ui/widgets/filter_dropdown.dart';
import '../../../../core/ui/widgets/filter_search_field.dart';
import '../../../employees/domain/entities/employee_entity.dart';

/// Desktop filter bar for warehouse documents.
/// All state is owned by the parent; this widget is purely controlled.
class WarehouseDocumentFilterBar extends StatelessWidget {
  const WarehouseDocumentFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.employees,
    required this.selectedType,
    required this.selectedUserId,
    required this.selectedDateRange,
    required this.onTypeChanged,
    required this.onUserChanged,
    required this.onDateRangeChanged,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  final List<EmployeeEntity> employees;

  final String? selectedType;
  final int? selectedUserId;
  final DateTimeRange? selectedDateRange;

  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<int?> onUserChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  final VoidCallback onRefresh;

  bool get _hasActiveFilters =>
      selectedType != null ||
      selectedUserId != null ||
      selectedDateRange != null;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      hasActiveFilters: _hasActiveFilters,
      onClearFilters: () {
        onTypeChanged(null);
        onUserChanged(null);
        onDateRangeChanged(null);
      },
      onRefresh: onRefresh,
      filters: [
        FilterSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
        ),
        const SizedBox(width: 12),
        FilterDropdown<String>(
          hint: 'Turi',
          value: selectedType,
          items: const [
            DropdownMenuItem(value: 'in', child: Text('Kirim')),
            DropdownMenuItem(value: 'out', child: Text('Chiqim')),
            DropdownMenuItem(value: 'return', child: Text('Qaytish')),
          ],
          onChanged: onTypeChanged,
        ),
        const SizedBox(width: 8),
        FilterDropdown<int>(
          hint: 'Foydalanuvchi',
          value: selectedUserId,
          items: employees
              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
              .toList(),
          onChanged: onUserChanged,
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
