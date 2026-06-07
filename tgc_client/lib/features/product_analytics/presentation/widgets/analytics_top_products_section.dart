import 'package:flutter/material.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';

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
  String _selectedLabel = 'Barchasi';

  List<String> get _labels {
    final values = widget.items
        .map((e) => _filterBy == _FilterBy.type ? e.typeName : e.qualityName)
        .toSet()
        .toList()
      ..sort();
    return ['Barchasi', ...values];
  }

  /// Top 10 for the current filter selection.
  List<TopProductItem> get _filtered {
    final all = _selectedLabel == 'Barchasi'
        ? widget.items
        : widget.items.where((e) {
            final val =
                _filterBy == _FilterBy.type ? e.typeName : e.qualityName;
            return val == _selectedLabel;
          }).toList();
    return all.take(10).toList();
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
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Top mahsulotlar (10)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
                _DimensionToggle(
                  value: _filterBy,
                  onChanged: _onFilterByChanged,
                ),
              ],
            ),
          ),

          // ── Filter dropdown ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _LabelDropdown(
              labels: _labels,
              selected: _selectedLabel,
              onChanged: (val) {
                if (val != null) setState(() => _selectedLabel = val);
              },
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Product tiles ─────────────────────────────────────────────
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) => _ProductTile(
              rank: index + 1,
              item: filtered[index],
              filterBy: _filterBy,
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Dimension toggle ──────────────────────────────────────────────────────────

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
        ButtonSegment(value: _FilterBy.type, label: Text('Tur')),
        ButtonSegment(value: _FilterBy.quality, label: Text('Sifat')),
      ],
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.firstOrNull),
    );
  }
}

// ── Label filter dropdown ─────────────────────────────────────────────────────

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
              .map((l) => DropdownMenuItem(
                    value: l,
                    child: Text(l, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Expandable product tile ───────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final int rank;
  final TopProductItem item;
  final _FilterBy filterBy;

  const _ProductTile({
    required this.rank,
    required this.item,
    required this.filterBy,
  });

  @override
  Widget build(BuildContext context) {
    final badge = filterBy == _FilterBy.type ? item.typeName : item.qualityName;
    final hasDetails = item.colors.isNotEmpty || item.sizes.isNotEmpty;

    return Theme(
      // Remove default ExpansionTile dividers
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        trailing: hasDetails ? null : const SizedBox.shrink(),
        title: Row(
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
            // Quantity + %
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
        children: [
          Container(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.colors.isNotEmpty)
                  _ColorBreakdown(colors: item.colors),
                if (item.sizes.isNotEmpty) _SizeBreakdown(sizes: item.sizes),
                const SizedBox(height: 8),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ── Color breakdown ───────────────────────────────────────────────────────────

class _ColorBreakdown extends StatelessWidget {
  final List<ProductColorBreakdown> colors;
  const _ColorBreakdown({required this.colors});

  /// Deterministic swatch fallback when no image is available.
  static Color _swatchOf(String name) {
    final hue = (name.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.55, 0.48).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ranglar',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: colors
                .map((c) => _ColorChip(c: c, swatchOf: _swatchOf))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final ProductColorBreakdown c;
  final Color Function(String) swatchOf;

  const _ColorChip({required this.c, required this.swatchOf});

  @override
  Widget build(BuildContext context) {
    const size = 20.0;

    Widget thumbnail;
    if (c.imageUrl != null) {
      thumbnail = AppThumbnail(
        imageUrl: c.imageUrl!,
        size: 30,
      );
    } else {
      thumbnail = _swatchCircle(swatchOf(c.name), size);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        thumbnail,
        const SizedBox(width: 5),
        Text(
          '${c.name}  ${c.percentage}%',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }

  Widget _swatchCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
    );
  }
}

// ── Size breakdown ────────────────────────────────────────────────────────────

class _SizeBreakdown extends StatelessWidget {
  final List<ProductSizeBreakdown> sizes;
  const _SizeBreakdown({required this.sizes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "O'lchamlar",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sizes.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  '${s.label}  ${s.percentage}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

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
