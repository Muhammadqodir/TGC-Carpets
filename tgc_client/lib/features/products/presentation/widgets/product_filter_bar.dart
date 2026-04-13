import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/products/domain/entities/product_quality_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_type_entity.dart';

/// Desktop filter bar shown above the products table.
/// All state is owned by the parent; this widget is purely controlled.
class ProductFilterBar extends StatelessWidget {
  const ProductFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.productTypes,
    required this.productQualities,
    required this.selectedTypeId,
    required this.selectedQualityId,
    required this.selectedStatus,
    required this.onTypeChanged,
    required this.onQualityChanged,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  final List<ProductTypeEntity> productTypes;
  final List<ProductQualityEntity> productQualities;

  final int? selectedTypeId;
  final int? selectedQualityId;
  final String? selectedStatus;

  final ValueChanged<int?> onTypeChanged;
  final ValueChanged<int?> onQualityChanged;
  final ValueChanged<String?> onStatusChanged;

  final VoidCallback onRefresh;

  bool get _hasActiveFilters =>
      selectedTypeId != null ||
      selectedQualityId != null ||
      selectedStatus != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Search field
          _FilterSearchField(
            controller: searchController,
            onChanged: onSearchChanged,
          ),
          const SizedBox(width: 12),

          // Type dropdown
          _FilterDropdown<int>(
            hint: 'Turi',
            value: selectedTypeId,
            items: productTypes
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.type)))
                .toList(),
            onChanged: onTypeChanged,
          ),
          const SizedBox(width: 8),

          // Quality dropdown
          _FilterDropdown<int>(
            hint: 'Sifat',
            value: selectedQualityId,
            items: productQualities
                .map((q) => DropdownMenuItem(
                      value: q.id,
                      child: Text(q.density != null
                          ? '${q.qualityName} (${q.density})'
                          : q.qualityName),
                    ))
                .toList(),
            onChanged: onQualityChanged,
          ),
          const SizedBox(width: 8),

          // Status dropdown
          _FilterDropdown<String>(
            hint: 'Holat',
            value: selectedStatus,
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Faol')),
              DropdownMenuItem(value: 'archived', child: Text('Arxivlangan')),
            ],
            onChanged: onStatusChanged,
          ),

          // Clear filters button
          if (_hasActiveFilters) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Filtrlarni tozalash',
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedFilterRemove,
                strokeWidth: 1.5,
              ),
              color: AppColors.error,
              onPressed: () {
                onTypeChanged(null);
                onQualityChanged(null);
                onStatusChanged(null);
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

class _FilterSearchField extends StatelessWidget {
  const _FilterSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Qidirish...',
          prefixIcon: const Icon(Icons.search_outlined, size: 18),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
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
