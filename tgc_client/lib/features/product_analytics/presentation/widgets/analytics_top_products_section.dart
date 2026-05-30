import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_analytics_entity.dart';

enum _FilterBy { type, quality }

class AnalyticsTopProductsSection extends StatefulWidget {
  final List<TopProductItem> items;

  const AnalyticsTopProductsSection({super.key, required this.items});

  @override
  State<AnalyticsTopProductsSection> createState() =>
      _AnalyticsTopProductsSectionState();
}

class _AnalyticsTopProductsSectionState
    extends State<AnalyticsTopProductsSection> {
  _FilterBy _filterBy = _FilterBy.type;

  // Unique label values for the selected dimension
  List<String> get _labels {
    final values = widget.items
        .map((e) => _filterBy == _FilterBy.type ? e.typeName : e.qualityName)
        .toSet()
        .toList()
      ..sort();
    return ['Barchasi', ...values];
  }

  String _selectedLabel = 'Barchasi';

  List<TopProductItem> get _filtered {
    if (_selectedLabel == 'Barchasi') return widget.items;
    return widget.items.where((e) {
      final val = _filterBy == _FilterBy.type ? e.typeName : e.qualityName;
      return val == _selectedLabel;
    }).toList();
  }

  void _onFilterByChanged(_FilterBy? val) {
    if (val == null) return;
    setState(() {
      _filterBy = val;
      _selectedLabel = 'Barchasi';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final filtered = _filtered;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Top mahsulotlar',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
                // Dimension toggle
                _DimensionToggle(
                  value: _filterBy,
                  onChanged: _onFilterByChanged,
                ),
              ],
            ),
          ),

          // ── Filter label dropdown ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _LabelDropdown(
              labels: _labels,
              selected: _selectedLabel,
              onChanged: (val) {
                if (val != null) setState(() => _selectedLabel = val);
              },
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Product list ──────────────────────────────────────────────
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _ProductRow(
                rank:       index + 1,
                item:       item,
                filterBy:   _filterBy,
              );
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Dimension toggle (Tur / Sifat) ────────────────────────────────────────────

class _DimensionToggle extends StatelessWidget {
  final _FilterBy value;
  final ValueChanged<_FilterBy?> onChanged;

  const _DimensionToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_FilterBy>(
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(value: _FilterBy.type,    label: Text('Tur')),
        ButtonSegment(value: _FilterBy.quality, label: Text('Sifat')),
      ],
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.firstOrNull),
    );
  }
}

// ── Label filter dropdown ──────────────────────────────────────────────────────

class _LabelDropdown extends StatelessWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String?> onChanged;

  const _LabelDropdown({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          items: labels
              .map(
                (l) => DropdownMenuItem(
                  value: l,
                  child: Text(l, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Single product row ────────────────────────────────────────────────────────

class _ProductRow extends StatelessWidget {
  final int rank;
  final TopProductItem item;
  final _FilterBy filterBy;

  const _ProductRow({
    required this.rank,
    required this.item,
    required this.filterBy,
  });

  @override
  Widget build(BuildContext context) {
    final badge =
        filterBy == _FilterBy.type ? item.typeName : item.qualityName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: rank <= 3
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        rank <= 3 ? FontWeight.w700 : FontWeight.normal,
                  ),
            ),
          ),
          // Name + badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _Badge(label: badge),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Quantity + percentage
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.totalQuantity}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              Text(
                '${item.percentage}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
