import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/filter_bar.dart';
import '../../../../core/ui/widgets/filter_client_picker.dart';
import '../../../../core/ui/widgets/filter_date_range_picker.dart';
import '../../../clients/domain/entities/client_entity.dart';

/// Filter bar for the Payments page.
class PaymentFilterBar extends StatelessWidget {
  const PaymentFilterBar({
    super.key,
    required this.selectedClient,
    required this.selectedDateRange,
    required this.onClientChanged,
    required this.onDateRangeChanged,
    required this.onRefresh,
  });

  final ClientEntity? selectedClient;
  final DateTimeRange? selectedDateRange;
  final ValueChanged<ClientEntity?> onClientChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onRefresh;

  bool get _hasActiveFilters =>
      selectedClient != null || selectedDateRange != null;

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
