import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/labeling_item_entity.dart';

class BatchFilterSidebar extends StatelessWidget {
  const BatchFilterSidebar({
    super.key,
    required this.groups,
    required this.selectedBatchId,
    required this.onBatchSelected,
  });

  final Map<int, List<LabelingItemEntity>> groups;
  final int? selectedBatchId;
  final ValueChanged<int?> onBatchSelected;

  @override
  Widget build(BuildContext context) {
    final totalItems = groups.values.fold(0, (s, l) => s + l.length);
    return Container(
      width: 250,
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
              'Partiyalar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _BatchTile(
            title: 'Barchasi',
            subtitle: '$totalItems ta mahsulot',
            isSelected: selectedBatchId == null,
            onTap: () => onBatchSelected(null),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: groups.entries.map((entry) {
                final batchId = entry.key;
                final batchItems = entry.value;
                final title =
                    batchItems.first.batchTitle ?? 'Batch #$batchId';
                final remaining =
                    batchItems.fold(0, (s, i) => s + i.remainingQuantity);
                return _BatchTile(
                  title: title,
                  subtitle:
                      '${batchItems.length} xil • $remaining qoldi',
                  isSelected: selectedBatchId == batchId,
                  onTap: () => onBatchSelected(batchId),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({
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
