import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

class ProductionAnalyticsPeriodSelector extends StatelessWidget {
  final String periodFrom;
  final String periodTo;
  final ValueChanged<(String from, String to)> onPeriodChanged;

  const ProductionAnalyticsPeriodSelector({
    super.key,
    required this.periodFrom,
    required this.periodTo,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Davr',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PresetChip(
                  label: '7 kun',
                  isSelected: _isPreset(7),
                  onTap: () => _applyPreset(7),
                ),
                const SizedBox(width: 8),
                _PresetChip(
                  label: '30 kun',
                  isSelected: _isPreset(30),
                  onTap: () => _applyPreset(30),
                ),
                const SizedBox(width: 8),
                _PresetChip(
                  label: '90 kun',
                  isSelected: _isPreset(90),
                  onTap: () => _applyPreset(90),
                ),
                const SizedBox(width: 8),
                _PresetChip(
                  label: '1 yil',
                  isSelected: _isPreset(365),
                  onTap: () => _applyPreset(365),
                ),
                const SizedBox(width: 8),
                _DateRangeChip(
                  periodFrom: periodFrom,
                  periodTo:   periodTo,
                  isCustom:   !_isAnyPreset,
                  onTap: () => _pickCustomRange(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isPreset(int days) {
    final to   = DateTime.parse(periodTo);
    final from = DateTime.parse(periodFrom);
    final today = _today();
    return to.year == today.year &&
        to.month == today.month &&
        to.day == today.day &&
        to.difference(from).inDays == days - 1;
  }

  bool get _isAnyPreset =>
      _isPreset(7) || _isPreset(30) || _isPreset(90) || _isPreset(365);

  void _applyPreset(int days) {
    final today = _today();
    final from  = today.subtract(Duration(days: days - 1));
    onPeriodChanged((
      DateFormat('yyyy-MM-dd').format(from),
      DateFormat('yyyy-MM-dd').format(today),
    ));
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final initial = DateTimeRange(
      start: DateTime.parse(periodFrom),
      end:   DateTime.parse(periodTo),
    );
    final picked = await showDateRangePicker(
      context:          context,
      firstDate:        DateTime(2020),
      lastDate:         DateTime.now(),
      initialDateRange: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      onPeriodChanged((
        DateFormat('yyyy-MM-dd').format(picked.start),
        DateFormat('yyyy-MM-dd').format(picked.end),
      ));
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.divider,
      ),
      backgroundColor: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  final String periodFrom;
  final String periodTo;
  final bool isCustom;
  final VoidCallback onTap;

  const _DateRangeChip({
    required this.periodFrom,
    required this.periodTo,
    required this.isCustom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yy');
    final label = isCustom
        ? '${fmt.format(DateTime.parse(periodFrom))} – ${fmt.format(DateTime.parse(periodTo))}'
        : 'Boshqa davr';

    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.date_range, size: 16),
      onPressed: onTap,
      backgroundColor: isCustom ? AppColors.primary.withAlpha(20) : AppColors.surface,
      labelStyle: TextStyle(
        color: isCustom ? AppColors.primary : AppColors.textSecondary,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isCustom ? AppColors.primary : AppColors.divider,
      ),
    );
  }
}
