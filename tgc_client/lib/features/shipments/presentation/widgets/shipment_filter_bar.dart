import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';

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
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Client dropdown
          _FilterDropdown<int>(
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

          // Date range picker
          _DateRangePickerButton(
            value: selectedDateRange,
            onChanged: onDateRangeChanged,
          ),

          // Clear filters
          if (_hasActiveFilters) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Filtrlarni tozalash',
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedFilterRemove,
                strokeWidth: 1.5,
              ),
              color: AppColors.error,
              onPressed: () {
                onClientChanged(null);
                onDateRangeChanged(null);
              },
            ),
          ],

          const Spacer(),

          // Refresh
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
    );
  }
}

// ---------------------------------------------------------------------------

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: value != null
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value != null ? AppColors.primary : AppColors.divider,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          isDense: true,
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text(
                'Barchasi',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DateRangePickerButton extends StatelessWidget {
  const _DateRangePickerButton({
    required this.value,
    required this.onChanged,
  });

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: value,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pickDateRange(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: value != null
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value != null ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              value != null
                  ? '${_formatDate(value!.start)} — ${_formatDate(value!.end)}'
                  : 'Sana',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: value != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
            ),
            if (value != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close, size: 14,
                    color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
