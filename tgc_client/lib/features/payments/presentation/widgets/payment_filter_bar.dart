import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';

/// Filter bar for the Payments page.
class PaymentFilterBar extends StatelessWidget {
  const PaymentFilterBar({
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
          _ClientDropdown(
            clients: clients,
            selectedClientId: selectedClientId,
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

class _ClientDropdown extends StatelessWidget {
  const _ClientDropdown({
    required this.clients,
    required this.selectedClientId,
    required this.onChanged,
  });

  final List<ClientEntity> clients;
  final int? selectedClientId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedClientId,
          hint: const Text('Mijoz'),
          items: [
            const DropdownMenuItem<int>(
              value: null,
              child: Text('Barcha mijozlar'),
            ),
            ...clients.map(
              (c) => DropdownMenuItem<int>(
                value: c.id,
                child: Text(c.shopName, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
          isDense: true,
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

  String get _label {
    if (value == null) return 'Sana';
    final s = value!.start;
    final e = value!.end;
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    return '${fmt(s)} – ${fmt(e)}';
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: value,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: value != null
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                value != null ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              size: 16,
              strokeWidth: 1.5,
              color: value != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: value != null
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
