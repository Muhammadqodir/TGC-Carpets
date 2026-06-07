import 'package:flutter/material.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/product_analytics_remote_datasource.dart';
import '../../domain/entities/product_analytics_entity.dart';
import '../../data/models/product_analytics_model.dart';

class AnalyticsTopProductsSection extends StatefulWidget {
  final String periodFrom;
  final String periodTo;
  final List<AnalyticsDimensionItem> byType;
  final List<AnalyticsDimensionItem> byQuality;
  final List<AnalyticsDimensionItem> bySize;
  final List<AnalyticsDimensionItem> byColor;
  final List<AnalyticsDimensionItem> byEdge;

  const AnalyticsTopProductsSection({
    super.key,
    required this.periodFrom,
    required this.periodTo,
    required this.byType,
    required this.byQuality,
    required this.bySize,
    required this.byColor,
    required this.byEdge,
  });

  @override
  State<AnalyticsTopProductsSection> createState() =>
      _AnalyticsTopProductsSectionState();
}

class _AnalyticsTopProductsSectionState
    extends State<AnalyticsTopProductsSection> {
  static const _countOptions = [10, 20, 30, 40, 50];

  int _limit = 10;
  int? _typeId;
  int? _qualityId;
  int? _sizeId;
  int? _colorId;
  int? _edgeId;

  bool _loading = false;
  String? _error;
  List<TopProductItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(AnalyticsTopProductsSection old) {
    super.didUpdateWidget(old);
    if (old.periodFrom != widget.periodFrom ||
        old.periodTo != widget.periodTo) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = sl<ProductAnalyticsRemoteDataSource>();
      final result = await ds.getTopProducts(
        periodFrom: widget.periodFrom,
        periodTo:   widget.periodTo,
        limit:      _limit,
        typeId:     _typeId,
        qualityId:  _qualityId,
        sizeId:     _sizeId,
        colorId:    _colorId,
        edgeId:     _edgeId,
      );
      if (mounted) setState(() => _items = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    setState(() {
      _typeId    = null;
      _qualityId = null;
      _sizeId    = null;
      _colorId   = null;
      _edgeId    = null;
      _limit     = 10;
    });
    _fetch();
  }

  bool get _hasActiveFilter =>
      _typeId != null ||
      _qualityId != null ||
      _sizeId != null ||
      _colorId != null ||
      _edgeId != null ||
      _limit != 10;

  @override
  Widget build(BuildContext context) {
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
                    'Top mahsulotlar ($_limit)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
                if (_hasActiveFilter)
                  TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: const Text('Tozalash'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // ── Filters ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // Row 1: type + quality
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown<int?>(
                        label: 'Tur',
                        value: _typeId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Barchasi')),
                          ...widget.byType.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _typeId = v);
                          _fetch();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterDropdown<int?>(
                        label: 'Sifat',
                        value: _qualityId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Barchasi')),
                          ...widget.byQuality.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _qualityId = v);
                          _fetch();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: size + color
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown<int?>(
                        label: "O'lcham",
                        value: _sizeId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Barchasi')),
                          ...widget.bySize.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _sizeId = v);
                          _fetch();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterDropdown<int?>(
                        label: 'Rang',
                        value: _colorId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Barchasi')),
                          ...widget.byColor.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _colorId = v);
                          _fetch();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 3: edge + count
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown<int?>(
                        label: 'Qirrа',
                        value: _edgeId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Barchasi')),
                          ...widget.byEdge.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _edgeId = v);
                          _fetch();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterDropdown<int>(
                        label: 'Soni',
                        value: _limit,
                        items: _countOptions
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text('Top $c'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _limit = v);
                          _fetch();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Content ───────────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _fetch,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Ma\'lumot topilmadi',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) => _ProductTile(
                rank: index + 1,
                item: _items[index],
              ),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Filter dropdown ───────────────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Expandable product tile ───────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final int rank;
  final TopProductItem item;

  const _ProductTile({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    final hasDetails = item.colors.isNotEmpty || item.sizes.isNotEmpty;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        trailing: hasDetails ? null : const SizedBox.shrink(),
        title: Row(
          children: [
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
                  Row(
                    children: [
                      _Badge(label: item.typeName),
                      const SizedBox(width: 4),
                      _Badge(label: item.qualityName, secondary: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
          SizedBox(
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
          ),
        ],
      ),
    );
  }
}

// ── Color breakdown ───────────────────────────────────────────────────────────

class _ColorBreakdown extends StatelessWidget {
  final List<ProductColorBreakdown> colors;
  const _ColorBreakdown({required this.colors});

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
      thumbnail = AppThumbnail(imageUrl: c.imageUrl!, size: 30);
    } else {
      thumbnail = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: swatchOf(c.name),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12, width: 0.5),
        ),
      );
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
  final bool secondary;

  const _Badge({required this.label, this.secondary = false});

  @override
  Widget build(BuildContext context) {
    final color = secondary ? AppColors.accent : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
