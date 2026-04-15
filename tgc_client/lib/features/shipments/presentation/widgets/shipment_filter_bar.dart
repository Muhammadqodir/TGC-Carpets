import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/filter_bar.dart';
import '../../../../core/ui/widgets/filter_date_range_picker.dart';
import '../../../../core/ui/widgets/filter_dropdown.dart';
import '../../../clients/domain/entities/client_entity.dart';

/// Filter bar for the Shipments page.
/// All state is owned by the parent; this widget is purely controlled.
class ShipmentFilterBar extends StatelessWidget {
  const ShipmentFilterBar({
    super.key,
    required this.clients,
    required this.selectedClientId,
    required this.selectedDateRange,
    required this.onClientChanged,
    required this.onDateRangeChanged,
    required this.onRefresh,
  });

  final List<ClientEntity> clients;
  final int? selectedClientId;
  final DateTimeRange? selectedDateRange;
  final ValueChanged<int?> onClientChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onRefresh;

  bool get _hasActiveFilters =>
      selectedClientId != null || selectedDateRange != null;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      hasActiveFilters: _hasActiveFilters,
      onClearFilters: () {
        onClientChanged(null);
        onDateRangeChanged(null);
      },
      onRefresh: onRefresh,
      filters: [
        FilterDropdown<int>(
          hint: 'Mijoz',
          value: selectedClientId,
          items: clients
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.shopName),
                  ))
              .toList(),
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
