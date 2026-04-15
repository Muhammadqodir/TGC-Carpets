import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/filter_bar.dart';
import '../../../../core/ui/widgets/filter_client_picker.dart';
import '../../../../core/ui/widgets/filter_date_range_picker.dart';
import '../../../../core/ui/widgets/filter_dropdown.dart';
import '../../../clients/domain/entities/client_entity.dart';

/// Desktop filter bar for the orders list page.
/// All filter state is owned by the parent; this widget is purely controlled.
class OrderFilterBar extends StatelessWidget {
  const OrderFilterBar({
    super.key,
    required this.selectedStatus,
    required this.selectedClient,
    required this.selectedDateRange,
    required this.onStatusChanged,
    required this.onClientChanged,
    required this.onDateRangeChanged,
    required this.onRefresh,
  });

  final String? selectedStatus;
  final ClientEntity? selectedClient;
  final DateTimeRange? selectedDateRange;

  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<ClientEntity?> onClientChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  final VoidCallback onRefresh;

  bool get _hasActiveFilters =>
      selectedStatus != null ||
      selectedClient != null ||
      selectedDateRange != null;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      hasActiveFilters: _hasActiveFilters,
      onClearFilters: () {
        onStatusChanged(null);
        onClientChanged(null);
        onDateRangeChanged(null);
      },
      onRefresh: onRefresh,
      filters: [
        FilterDropdown<String>(
          hint: 'Holat',
          value: selectedStatus,
          items: const [
            DropdownMenuItem(value: 'pending', child: Text('Kutilmoqda')),
            DropdownMenuItem(value: 'planned', child: Text('Rejalashtirilgan')),
            DropdownMenuItem(
                value: 'on_production', child: Text('Ishlab chiqarilmoqda')),
            DropdownMenuItem(value: 'done', child: Text('Bajarildi')),
            DropdownMenuItem(value: 'shipped', child: Text('Yuborildi')),
            DropdownMenuItem(value: 'canceled', child: Text('Bekor qilindi')),
          ],
          onChanged: onStatusChanged,
        ),
        const SizedBox(width: 8),
        FilterClientPicker(
          value: selectedClient,
          onChanged: onClientChanged,
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
