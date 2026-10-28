import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../product_analytics/domain/entities/product_analytics_entity.dart';
import '../../../product_analytics/presentation/widgets/analytics_period_selector.dart';
import '../../domain/entities/production_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';
import '../bloc/production_analytics_bloc.dart';
import '../bloc/production_analytics_event.dart';
import '../bloc/production_analytics_state.dart';
import '../widgets/production_analytics_summary_cards.dart';
import '../widgets/production_capacity_section.dart';
import '../widgets/production_hourly_chart.dart';
import '../widgets/production_shift_trend_chart.dart';
import '../widgets/production_ops_summary_cards.dart';

class ProductionAnalyticsPage extends StatelessWidget {
  const ProductionAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final from  = DateFormat('yyyy-MM-dd').format(
      today.subtract(const Duration(days: 29)),
    );
    final to = DateFormat('yyyy-MM-dd').format(today);

    return BlocProvider(
      create: (_) => sl<ProductionAnalyticsBloc>()
        ..add(ProductionAnalyticsLoadRequested(
          periodFrom: from,
          periodTo:   to,
          trendBy:    'day',
        )),
      child: const _ProductionAnalyticsView(),
    );
  }
}

class _ProductionAnalyticsView extends StatefulWidget {
  const _ProductionAnalyticsView();

  @override
  State<_ProductionAnalyticsView> createState() => _ProductionAnalyticsViewState();
}

class _ProductionAnalyticsViewState extends State<_ProductionAnalyticsView> {
  // Held above the bloc builder so it survives the loading spinner.
  AnalyticsMetric _metric = AnalyticsMetric.quantity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ishlab chiqarish tahlili'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          BlocBuilder<ProductionAnalyticsBloc, ProductionAnalyticsState>(
            builder: (context, state) {
              if (state is ProductionAnalyticsLoaded) {
                return IconButton(
                  onPressed: () {
                    context.read<ProductionAnalyticsBloc>().add(
                          ProductionAnalyticsLoadRequested(
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
      body: BlocBuilder<ProductionAnalyticsBloc, ProductionAnalyticsState>(
        builder: (context, state) {
          // Period selector is always shown
          final periodFrom = state is ProductionAnalyticsLoaded
              ? state.data.periodFrom
              : DateFormat('yyyy-MM-dd')
                  .format(DateTime.now().subtract(const Duration(days: 29)));
          final periodTo = state is ProductionAnalyticsLoaded
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
                  context.read<ProductionAnalyticsBloc>().add(
                        ProductionAnalyticsPeriodChanged(
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
                  ProductionAnalyticsLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ProductionAnalyticsError(:final message) => _ErrorState(
                      message: message,
                      onRetry: () => context.read<ProductionAnalyticsBloc>().add(
                            ProductionAnalyticsLoadRequested(
                              periodFrom: periodFrom,
                              periodTo:   periodTo,
                            ),
                          ),
                    ),
                  ProductionAnalyticsLoaded(:final data) =>
                    _AnalyticsContent(data: data, metric: _metric),
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
  final ProductionAnalyticsEntity data;
  final AnalyticsMetric metric;

  const _AnalyticsContent({required this.data, required this.metric});

  @override
  Widget build(BuildContext context) {
    final ops = data.operations;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Output per day, split by shift
          if (ops != null) ...[
            _SectionCard(
              title: 'Ishlab chiqarish dinamikasi',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                child: ProductionShiftTrendChart(
                  trend:      ops.trend,
                  shifts:     ops.byShift,
                  trendBy:    ops.trendBy,
                  periodFrom: data.periodFrom,
                  periodTo:   data.periodTo,
                  metric:     metric,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Summary cards
          ProductionAnalyticsSummaryCards(
            totalBatches:  data.summary.totalBatches,
            totalProduced: data.summary.totalProduced,
            totalSqm:      data.summary.totalSqm,
            metric:        metric,
          ),

          if (ops != null) ...[
            const SizedBox(height: 4),
            _OperationsBlock(ops: ops, metric: metric),
          ],
        ],
      ),
    );
  }
}

// ─── Shifts, machines, hours ──────────────────────────────────────────────────

class _OperationsBlock extends StatelessWidget {
  final ProductionOperationsEntity ops;
  final AnalyticsMetric metric;

  const _OperationsBlock({required this.ops, required this.metric});

  @override
  Widget build(BuildContext context) {
    final start = '${ops.dayStartHour.toString().padLeft(2, '0')}:00';
    final note = StringBuffer(
      'Yorliq chop etilgan vaqt bo\'yicha. Ish kuni $start da boshlanadi, '
      'quvvat — davrdagi eng yaxshi kun.',
    );
    if (ops.backfilledExcluded > 0) {
      note.write(' Iyul 2026 dan oldingi ${ops.backfilledExcluded} dona '
          '(kim/qachon noma\'lum) hisobga olinmagan.');
    }

    final shifts = ProductionCapacitySection(
      title: 'Smenalar bo\'yicha',
      subtitle: 'Kim yorliq chop etgan · brak — kim kiritgan',
      rows: ops.byShift,
      metric: metric,
      icon: Icons.groups_2_outlined,
    );
    final machines = ProductionMachineGrid(
      rows: ops.byMachine,
      metric: metric,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            note.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        ProductionOpsSummaryCards(ops: ops, metric: metric),
        const SizedBox(height: 12),
        shifts,
        const SizedBox(height: 12),
        machines,
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Soatlik ishlab chiqarish',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 0, 10),
                  child: Text(
                    'Tanlangan davrda har bir soatda jami qancha ishlab chiqarilgan '
                    '(yorliq chop etilgan vaqt bo\'yicha)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                ProductionHourlyChart(
                  cells: ops.heatmap,
                  shifts: ops.byShift,
                  metric: metric,
                ),
              ],
            ),
          ),
        ),
      ],
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
