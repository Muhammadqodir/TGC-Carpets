import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_analytics_entity.dart';
import '../../domain/usecases/get_top_products_usecase.dart';
import '../bloc/top_products_filter_cubit.dart';
import '../bloc/top_products_filter_state.dart';

const _kLimitOptions = [10, 20, 30, 40, 50];

class AnalyticsTopProductsSection extends StatefulWidget {
  final String periodFrom;
  final String periodTo;
  final List<AnalyticsDimensionItem> typeOptions;
  final List<AnalyticsDimensionItem> qualityOptions;
  final List<AnalyticsDimensionItem> colorOptions;
  final List<AnalyticsDimensionItem> sizeOptions;
  final List<AnalyticsDimensionItem> edgeOptions;

  const AnalyticsTopProductsSection({
    super.key,
    required this.periodFrom,
    required this.periodTo,
    required this.typeOptions,
    required this.qualityOptions,
    required this.colorOptions,
    required this.sizeOptions,
    required this.edgeOptions,
  });

  @override
  State<AnalyticsTopProductsSection> createState() =>
      _AnalyticsTopProductsSectionState();
}

class _AnalyticsTopProductsSectionState
    extends State<AnalyticsTopProductsSection> {
  late final TopProductsFilterCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = TopProductsFilterCubit(
      useCase:    sl<GetTopProductsUseCase>(),
      periodFrom: widget.periodFrom,
      periodTo:   widget.periodTo,
    );
  }

  @override
  void didUpdateWidget(AnalyticsTopProductsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodFrom != widget.periodFrom ||
        oldWidget.periodTo != widget.periodTo) {
      _cubit.updatePeriod(widget.periodFrom, widget.periodTo);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: _TopProductsContent(
        typeOptions:    widget.typeOptions,
        qualityOptions: widget.qualityOptions,
        colorOptions:   widget.colorOptions,
        sizeOptions:    widget.sizeOptions,
        edgeOptions:    widget.edgeOptions,
      ),
    );
  }
}

// ── Main content ──────────────────────────────────────────────────────────────

class _TopProductsContent extends StatelessWidget {
  final List<AnalyticsDimensionItem> typeOptions;
  final List<AnalyticsDimensionItem> qualityOptions;
  final List<AnalyticsDimensionItem> colorOptions;
  final List<AnalyticsDimensionItem> sizeOptions;
  final List<AnalyticsDimensionItem> edgeOptions;

  const _TopProductsContent({
    required this.typeOptions,
    required this.qualityOptions,
    required this.colorOptions,
    required this.sizeOptions,
    required this.edgeOptions,
  });

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
      child: BlocBuilder<TopProductsFilterCubit, TopProductsFilterState>(
        builder: (context, state) {
          final cubit    = context.read<TopProductsFilterCubit>();
          final isLoading = state is TopProductsFilterLoading;
          final products  = switch (state) {
            TopProductsFilterLoaded(:final products) => products,
            TopProductsFilterLoading(:final previousProducts) => previousProducts,
            _ => const <TopProductItem>[],
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: BlocBuilder<TopProductsFilterCubit,
                          TopProductsFilterState>(
                        buildWhen: (a, b) => a.limit != b.limit,
                        builder: (context, s) => Text(
                          'Top mahsulotlar (${s.limit})',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (cubit.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: cubit.clearFilters,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Tozalash',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Filter bar ───────────────────────────────────────────────
              _FilterBar(
                state:          state,
                typeOptions:    typeOptions,
                qualityOptions: qualityOptions,
                colorOptions:   colorOptions,
                sizeOptions:    sizeOptions,
                edgeOptions:    edgeOptions,
                onTypeChanged:    (id) => cubit.setTypeId(id),
                onQualityChanged: (id) => cubit.setQualityId(id),
                onColorChanged:   (id) => cubit.setColorId(id),
                onSizeChanged:    (id) => cubit.setSizeId(id),
                onEdgeChanged:    (id) => cubit.setEdgeId(id),
                onLimitChanged:   (l)  => cubit.setLimit(l),
              ),

              const Divider(height: 1, color: AppColors.divider),

              // ── Error state ──────────────────────────────────────────────
              if (state is TopProductsFilterError)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                  ),
                )
              // ── Product tiles ────────────────────────────────────────────
              else if (products.isEmpty && !isLoading)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Mahsulotlar topilmadi',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                )
              else
                Opacity(
                  opacity: isLoading ? 0.5 : 1.0,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) => _ProductTile(
                      rank: index + 1,
                      item: products[index],
                    ),
                  ),
                ),

              const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final TopProductsFilterState state;
  final List<AnalyticsDimensionItem> typeOptions;
  final List<AnalyticsDimensionItem> qualityOptions;
  final List<AnalyticsDimensionItem> colorOptions;
  final List<AnalyticsDimensionItem> sizeOptions;
  final List<AnalyticsDimensionItem> edgeOptions;
  final ValueChanged<int?> onTypeChanged;
  final ValueChanged<int?> onQualityChanged;
  final ValueChanged<int?> onColorChanged;
  final ValueChanged<int?> onSizeChanged;
  final ValueChanged<int?> onEdgeChanged;
  final ValueChanged<int> onLimitChanged;

  const _FilterBar({
    required this.state,
    required this.typeOptions,
    required this.qualityOptions,
    required this.colorOptions,
    required this.sizeOptions,
    required this.edgeOptions,
    required this.onTypeChanged,
    required this.onQualityChanged,
    required this.onColorChanged,
    required this.onSizeChanged,
    required this.onEdgeChanged,
    required this.onLimitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _AttrDropdown<int?>(
            hint: 'Tur',
            value: state.typeId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Barchasi')),
              ...typeOptions.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: onTypeChanged,
            isActive: state.typeId != null,
          ),
          const SizedBox(width: 8),
          _AttrDropdown<int?>(
            hint: 'Sifat',
            value: state.qualityId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Barchasi')),
              ...qualityOptions.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: onQualityChanged,
            isActive: state.qualityId != null,
          ),
          const SizedBox(width: 8),
          _AttrDropdown<int?>(
            hint: 'Rang',
            value: state.colorId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Barchasi')),
              ...colorOptions.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: onColorChanged,
            isActive: state.colorId != null,
          ),
          const SizedBox(width: 8),
          _AttrDropdown<int?>(
            hint: "O'lcham",
            value: state.sizeId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Barchasi')),
              ...sizeOptions.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: onSizeChanged,
            isActive: state.sizeId != null,
          ),
          const SizedBox(width: 8),
          _AttrDropdown<int?>(
            hint: 'Chegara',
            value: state.edgeId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Barchasi')),
              ...edgeOptions.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: onEdgeChanged,
            isActive: state.edgeId != null,
          ),
          const SizedBox(width: 8),
          _AttrDropdown<int>(
            hint: 'Soni',
            value: state.limit,
            items: _kLimitOptions
                .map((n) => DropdownMenuItem(value: n, child: Text('$n ta')))
                .toList(),
            onChanged: (v) { if (v != null) onLimitChanged(v); },
            isActive: state.limit != 10,
          ),
        ],
      ),
    );
  }
}

// ── Generic attribute dropdown ────────────────────────────────────────────────

class _AttrDropdown<T> extends StatelessWidget {
  final String hint;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isActive;

  const _AttrDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withAlpha(18)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.divider,
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
                color: isActive ? AppColors.primary : AppColors.textPrimary,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
          items: items,
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
            // Name + badges
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
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _Badge(label: item.typeName),
                      const SizedBox(width: 4),
                      _Badge(
                        label: item.qualityName,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
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
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.colors.isNotEmpty)
                  _ColorBreakdown(colors: item.colors),
                if (item.sizes.isNotEmpty)
                  _SizeBreakdown(sizes: item.sizes),
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

    final Widget thumbnail = c.imageUrl != null
        ? AppThumbnail(imageUrl: c.imageUrl!, size: 30)
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: swatchOf(c.name),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12, width: 0.5),
            ),
          );

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
  final Color? color;
  const _Badge({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
