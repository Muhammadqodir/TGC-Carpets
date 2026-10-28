import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_analytics_entity.dart';
import '../bloc/product_analytics_bloc.dart';
import '../bloc/product_analytics_event.dart';
import '../bloc/product_analytics_state.dart';
import '../widgets/analytics_dimension_section.dart';
import '../widgets/analytics_period_selector.dart';
import '../widgets/analytics_summary_cards.dart';
import '../widgets/analytics_top_products_section.dart';
import '../widgets/analytics_trend_chart.dart';

class ProductAnalyticsPage extends StatelessWidget {
  const ProductAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final from  = DateFormat('yyyy-MM-dd').format(
      today.subtract(const Duration(days: 29)),
    );
    final to = DateFormat('yyyy-MM-dd').format(today);

    return BlocProvider(
      create: (_) => sl<ProductAnalyticsBloc>()
        ..add(ProductAnalyticsLoadRequested(
          periodFrom: from,
          periodTo:   to,
          trendBy:    'day',
        )),
      child: const _ProductAnalyticsView(),
    );
  }
}

class _ProductAnalyticsView extends StatefulWidget {
  const _ProductAnalyticsView();

  @override
  State<_ProductAnalyticsView> createState() => _ProductAnalyticsViewState();
}

class _ProductAnalyticsViewState extends State<_ProductAnalyticsView> {
  // Held here, above the bloc builder, so it survives the loading spinner
  // that replaces the content on every period change or refresh.
  AnalyticsMetric _metric = AnalyticsMetric.quantity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Buyurtma tahlili'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          BlocBuilder<ProductAnalyticsBloc, ProductAnalyticsState>(
            builder: (context, state) {
              if (state is ProductAnalyticsLoaded) {
                return IconButton(
                  onPressed: () {
                    context.read<ProductAnalyticsBloc>().add(
                          ProductAnalyticsLoadRequested(
                            periodFrom: state.data.periodFrom,
                            periodTo:   state.data.periodTo,
                            trendBy:    state.data.trendBy,
                          ),
                        );
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Yangilash',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<ProductAnalyticsBloc, ProductAnalyticsState>(
        builder: (context, state) {
          // Period selector is always shown
          final periodFrom = state is ProductAnalyticsLoaded
              ? state.data.periodFrom
              : DateFormat('yyyy-MM-dd')
                  .format(DateTime.now().subtract(const Duration(days: 29)));
          final periodTo = state is ProductAnalyticsLoaded
              ? state.data.periodTo
              : DateFormat('yyyy-MM-dd').format(DateTime.now());

          return Column(
            children: [
              // ── Period Selector ─────────────────────────────────────────
              AnalyticsPeriodSelector(
                periodFrom: periodFrom,
                periodTo:   periodTo,
                trailing: _MetricSwitcher(
                  value: _metric,
                  onChanged: (m) => setState(() => _metric = m),
                ),
                onPeriodChanged: (range) {
                  context.read<ProductAnalyticsBloc>().add(
                        ProductAnalyticsPeriodChanged(
                          periodFrom: range.$1,
                          periodTo:   range.$2,
                        ),
                      );
                },
              ),
              const Divider(height: 1, color: AppColors.divider),

              // ── Content ─────────────────────────────────────────────────
              Expanded(
                child: switch (state) {
                  ProductAnalyticsLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ProductAnalyticsError(:final message) => _ErrorState(
                      message: message,
                      onRetry: () => context.read<ProductAnalyticsBloc>().add(
                            ProductAnalyticsLoadRequested(
                              periodFrom: periodFrom,
                              periodTo:   periodTo,
                            ),
                          ),
                    ),
                  ProductAnalyticsLoaded(:final data) =>
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Responsive: >700px = 2-col grid, else single column
                        final isWide = constraints.maxWidth > 700;
                        return _AnalyticsContent(
                          data: data,
                          isWide: isWide,
                          metric: _metric,
                        );
                      },
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Content layout ───────────────────────────────────────────────────────────

class _AnalyticsContent extends StatelessWidget {
  final ProductAnalyticsEntity data;
  final bool isWide;
  final AnalyticsMetric metric;

  const _AnalyticsContent({
    required this.data,
    required this.isWide,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final sections = [
      AnalyticsDimensionSection(
        title: 'Tur bo\'yicha',
        items: data.byType,
        metric: metric,
        accentColor: AppColors.primary,
      ),
      AnalyticsDimensionSection(
        title: 'Rang bo\'yicha',
        items: data.byColor,
        metric: metric,
        accentColor: const Color(0xFF7B5EA7),
      ),
      AnalyticsDimensionSection(
        title: 'O\'lcham bo\'yicha',
        items: data.bySize,
        metric: metric,
        accentColor: const Color(0xFF2196A6),
      ),
      AnalyticsDimensionSection(
        title: 'Sifat bo\'yicha',
        items: data.byQuality,
        metric: metric,
        accentColor: AppColors.accent,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary cards
          AnalyticsSummaryCards(
            totalOrders: data.summary.totalOrders,
            totalItems:  data.summary.totalItems,
            totalSqm:    data.summary.totalSqm,
            metric:      metric,
          ),

          // Trend chart
          if (data.trend.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Buyurtmalar dinamikasi',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                child: AnalyticsTrendChart(
                  trend:   data.trend,
                  trendBy: data.trendBy,
                  metric:  metric,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Dimension sections — responsive grid
          if (isWide)
            _TwoColumnGrid(sections: sections)
          else
            _SingleColumn(sections: sections),

          // Top products table
          const SizedBox(height: 12),
          AnalyticsTopProductsSection(
            periodFrom:     data.periodFrom,
            periodTo:       data.periodTo,
            typeOptions:    data.byType,
            qualityOptions: data.byQuality,
            colorOptions:   data.byColor,
            sizeOptions:    data.bySize,
            edgeOptions:    data.byEdge,
            metric:         metric,
          ),
        ],
      ),
    );
  }
}

class _MetricSwitcher extends StatelessWidget {
  final AnalyticsMetric value;
  final ValueChanged<AnalyticsMetric> onChanged;

  const _MetricSwitcher({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AnalyticsMetric>(
      segments: const [
        ButtonSegment(
          value: AnalyticsMetric.quantity,
          label: Text('Dona'),
          icon: Icon(Icons.numbers_rounded, size: 16),
        ),
        ButtonSegment(
          value: AnalyticsMetric.sqm,
          label: Text('m²'),
          icon: Icon(Icons.square_foot_rounded, size: 16),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _TwoColumnGrid extends StatelessWidget {
  final List<Widget> sections;

  const _TwoColumnGrid({required this.sections});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < sections.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: sections[i]),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < sections.length
                    ? sections[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < sections.length) rows.add(const SizedBox(height: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _SingleColumn extends StatelessWidget {
  final List<Widget> sections;

  const _SingleColumn({required this.sections});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sections
          .expand((s) => [s, const SizedBox(height: 12)])
          .take(sections.length * 2 - 1)
          .toList(),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }
}
