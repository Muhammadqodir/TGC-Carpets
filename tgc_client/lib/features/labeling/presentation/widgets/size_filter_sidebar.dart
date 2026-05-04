import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/labeling_item_entity.dart';

class SizeFilterSidebar extends StatelessWidget {
  const SizeFilterSidebar({
    super.key,
    required this.groups,
    required this.selectedSize,
    required this.onSizeSelected,
  });

  final Map<String, List<LabelingItemEntity>> groups;
  final String? selectedSize;
  final ValueChanged<String?> onSizeSelected;

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
              'O\'lchamlar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _SizeTile(
            title: 'Barchasi',
            subtitle: '$totalItems ta mahsulot',
            isSelected: selectedSize == null,
            onTap: () => onSizeSelected(null),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: groups.entries.map((entry) {
                final sizeLabel = entry.key;
                final sizeItems = entry.value;
                final remaining =
                    sizeItems.fold(0, (s, i) => s + i.remainingQuantity);
                return _SizeTile(
                  title: sizeLabel,
                  subtitle: '${sizeItems.length} xil • $remaining qoldi',
                  isSelected: selectedSize == sizeLabel,
                  onTap: () => onSizeSelected(sizeLabel),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeTile extends StatelessWidget {
  const _SizeTile({
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
                icon: HugeIcons.strokeRoundedRuler,
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
