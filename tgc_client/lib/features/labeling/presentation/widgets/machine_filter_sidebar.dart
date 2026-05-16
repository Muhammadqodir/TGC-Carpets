import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/labeling_item_entity.dart';

class MachineFilterSidebar extends StatelessWidget {
  const MachineFilterSidebar({
    super.key,
    required this.groups,
    required this.selectedMachine,
    required this.onMachineSelected,
  });

  /// Keys are `item.machineName ?? '—'`.
  final Map<String, List<LabelingItemEntity>> groups;
  final String? selectedMachine;
  final ValueChanged<String?> onMachineSelected;

  @override
  Widget build(BuildContext context) {
    final totalItems = groups.values.fold(0, (s, l) => s + l.length);
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: const Text(
              'Mashinalar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _MachineTile(
            title: 'Barchasi',
            subtitle: '$totalItems ta mahsulot',
            isSelected: selectedMachine == null,
            onTap: () => onMachineSelected(null),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: (groups.entries.toList()
                    ..sort((a, b) {
                      final aId = a.value.isNotEmpty
                          ? (a.value.first.machineId ?? 0)
                          : 0;
                      final bId = b.value.isNotEmpty
                          ? (b.value.first.machineId ?? 0)
                          : 0;
                      return aId.compareTo(bId);
                    }))
                  .map((entry) {
                final machineName = entry.key;
                final machineItems = entry.value;
                final remaining =
                    machineItems.fold(0, (s, i) => s + i.remainingQuantity);
                return _MachineTile(
                  title: machineName,
                  subtitle: '${machineItems.length} xil • $remaining qoldi',
                  isSelected: selectedMachine == machineName,
                  onTap: () => onMachineSelected(machineName),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineTile extends StatelessWidget {
  const _MachineTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: isSelected
              ? const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.primary, width: 3),
                  ),
                )
              : null,
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSetup01,
                size: 20,
                strokeWidth: 1.5,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color:
                                    isSelected ? AppColors.primary : null,
                              ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
