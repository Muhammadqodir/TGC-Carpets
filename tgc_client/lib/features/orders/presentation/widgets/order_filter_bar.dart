import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../clients/domain/entities/client_entity.dart';
import '../../../clients/presentation/widgets/client_picker_bottom_sheet.dart';

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
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Status dropdown
          _OrderStatusDropdown(
            value: selectedStatus,
            onChanged: onStatusChanged,
          ),
          const SizedBox(width: 8),

          // Client picker button
          _ClientPickerButton(
            client: selectedClient,
            onChanged: onClientChanged,
          ),
          const SizedBox(width: 8),

          // Date range picker
          _DateRangePickerButton(
            value: selectedDateRange,
            onChanged: onDateRangeChanged,
          ),

          // Clear all filters
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
                onStatusChanged(null);
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

// ── Status dropdown ───────────────────────────────────────────────────────────

class _OrderStatusDropdown extends StatelessWidget {
  const _OrderStatusDropdown({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

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
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            'Holat',
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
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Barchasi',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const DropdownMenuItem(value: 'pending', child: Text('Kutilmoqda')),
            const DropdownMenuItem(
                value: 'planned',
                child: Text('Rejalashtirilgan')),
            const DropdownMenuItem(
                value: 'on_production',
                child: Text('Ishlab chiqarilmoqda')),
            const DropdownMenuItem(value: 'done', child: Text('Bajarildi')),
            const DropdownMenuItem(
                value: 'canceled', child: Text('Bekor qilindi')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Client picker button ──────────────────────────────────────────────────────

class _ClientPickerButton extends StatelessWidget {
  const _ClientPickerButton({
    required this.client,
    required this.onChanged,
  });

  final ClientEntity? client;
  final ValueChanged<ClientEntity?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = client != null;
    return InkWell(
      onTap: () async {
        final picked = await ClientPickerBottomSheet.show(context);
        if (picked != null) {
          onChanged(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store_outlined,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              isSelected ? client!.shopName : 'Mijoz',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close,
                    size: 14, color: AppColors.textSecondary),
              ),
            ] else ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  size: 16, color: AppColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Date range picker button ──────────────────────────────────────────────────

class _DateRangePickerButton extends StatelessWidget {
  const _DateRangePickerButton({
    required this.value,
    required this.onChanged,
  });

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pick(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: value,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = value != null;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
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
              isSelected
                  ? '${_fmt(value!.start)} — ${_fmt(value!.end)}'
                  : 'Sana',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
