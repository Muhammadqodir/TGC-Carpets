import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';

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
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _StatusDropdown(value: selectedStatus, onChanged: onStatusChanged),
          const SizedBox(width: 8),
          _TypeDropdown(value: selectedType, onChanged: onTypeChanged),
          const SizedBox(width: 8),
          _DateRangeButton(
            value: selectedDateRange,
            onChanged: onDateRangeChanged,
          ),
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
                onTypeChanged(null);
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

// ── Status dropdown ───────────────────────────────────────────────────────────

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FilterChip(
      isActive: value != null,
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
            const DropdownMenuItem(value: 'planned',     child: Text('Rejalashtirilgan')),
            const DropdownMenuItem(value: 'in_progress', child: Text('Ishlab chiqarilmoqda')),
            const DropdownMenuItem(value: 'completed',   child: Text('Bajarildi')),
            const DropdownMenuItem(value: 'cancelled',   child: Text('Bekor qilindi')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Type dropdown ─────────────────────────────────────────────────────────────

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FilterChip(
      isActive: value != null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            'Tur',
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
            const DropdownMenuItem(value: 'by_order',  child: Text("Buyurtma bo'yicha")),
            const DropdownMenuItem(value: 'for_stock', child: Text('Ombor uchun')),
            const DropdownMenuItem(value: 'mixed',     child: Text('Aralash')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Date range button ─────────────────────────────────────────────────────────

class _DateRangeButton extends StatelessWidget {
  const _DateRangeButton({required this.value, required this.onChanged});

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value != null;
    final label = isSelected
        ? '${_fmt(value!.start)} – ${_fmt(value!.end)}'
        : 'Sana';

    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: value,
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: _FilterChip(
        isActive: isSelected,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ── Shared chip container ─────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.child, this.isActive = false});

  final Widget child;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.divider,
        ),
      ),
      child: child,
    );
  }
}
