import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/extensions/amount.dart';
import 'package:tgc_client/core/widgets/range_date_picker.dart';
import 'package:tgc_client/core/widgets/static_grid.dart';
import 'package:tgc_client/features/dashboard/domain/entities/dashboard_stats_entity.dart';
import 'package:tgc_client/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:tgc_client/features/dashboard/presentation/bloc/dashboard_state.dart';

class DashboardPanel extends StatelessWidget {
  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final bool visible;

  const DashboardPanel({
    super.key,
    required this.range,
    required this.onRangeChanged,
    this.visible = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RangeDatePicker(
            value: range,
            onChanged: onRangeChanged,
          ),
          const SizedBox(height: 4),
          BlocBuilder<DashboardBloc, DashboardState>(
            builder: (_, state) {
              if (state is DashboardLoading || state is DashboardInitial) {
                return _StatGrid(stats: null, isVisible: visible);
              }
              if (state is DashboardStatsLoaded) {
                return _StatGrid(stats: state.stats, isVisible: visible);
              }
              return _StatGrid(stats: null, isVisible: visible);
            },
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final DashboardStatsEntity? stats;
  final bool isVisible;

  const _StatGrid({required this.stats, this.isVisible = false});

  @override
  Widget build(BuildContext context) {
    return StaticGrid(
      columnCount: 2,
      gap: 2,
      children: [
        Expanded(
          child: _StatData(
            title: 'Ishlab chiqarish',
            value: isVisible
                ? (stats != null ? '${stats!.productionQuantity}ta' : '—')
                : '•••',
            icon: HugeIcons.strokeRoundedDatabaseAdd,
            loading: stats == null,
          ),
        ),
        Expanded(
          child: _StatData(
            title: 'Omborda',
            value: isVisible
                ? (stats != null ? '${stats!.warehouseStock}ta' : '—')
                : '•••',
            icon: HugeIcons.strokeRoundedWarehouse,
            loading: stats == null,
          ),
        ),
        Expanded(
          child: _StatData(
            title: 'Savdo hajmi',
            value: isVisible
                ? (stats != null ? '${stats!.salesQuantity}ta' : '—')
                : '•••',
            icon: HugeIcons.strokeRoundedDatabaseExport,
            loading: stats == null,
          ),
        ),
        Expanded(
          child: _StatData(
            title: 'Savdo so\'mda',
            value: isVisible
                ? (stats != null ? stats!.salesAmount.toCurrencyShort() : '—')
                : '•••',
            icon: HugeIcons.strokeRoundedDollarSquare,
            loading: stats == null,
          ),
        ),
      ],
    );
  }
}

class _StatData extends StatelessWidget {
  const _StatData({
    required this.title,
    required this.value,
    required this.icon,
    this.loading = false,
  });

  final String title;
  final String value;
  final dynamic icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  loading
                      ? const SizedBox(
                          height: 16,
                          width: 56,
                          child: LinearProgressIndicator(),
                        )
                      : Text(
                          value,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
