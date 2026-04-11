import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/production_batches_bloc.dart';
import '../../bloc/production_batches_event.dart';
import '../../bloc/production_batches_state.dart';
import '../../widgets/production_batch_filter_bar.dart';
import '../../widgets/production_batch_table.dart';

class ProductionBatchesDesktopPage extends StatefulWidget {
  const ProductionBatchesDesktopPage({super.key});

  @override
  State<ProductionBatchesDesktopPage> createState() =>
      _ProductionBatchesDesktopPageState();
}

class _ProductionBatchesDesktopPageState
    extends State<ProductionBatchesDesktopPage> {
  final _scrollController = ScrollController();

  String? _selectedStatus;
  String? _selectedType;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context
          .read<ProductionBatchesBloc>()
          .add(const ProductionBatchesNextPageRequested());
    }
  }

  void _applyFilters({
    String? status,
    String? type,
    DateTimeRange? dateRange,
  }) {
    setState(() {
      _selectedStatus    = status;
      _selectedType      = type;
      _selectedDateRange = dateRange;
    });
    context.read<ProductionBatchesBloc>().add(
          ProductionBatchesFiltersChanged(
            status: status,
            type: type,
            dateRange: dateRange != null
                ? DateTimeRangeSimple(
                    start: dateRange.start,
                    end: dateRange.end,
                  )
                : null,
          ),
        );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ishlab chiqarish'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Yangi batch",
            onPressed: () async {
              final created = await context
                  .pushNamed(AppRoutes.addProductionBatchName);
              if (created == true && context.mounted) {
                context
                    .read<ProductionBatchesBloc>()
                    .add(const ProductionBatchesRefreshRequested());
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter bar
          ProductionBatchFilterBar(
            selectedStatus:      _selectedStatus,
            selectedType:        _selectedType,
            selectedDateRange:   _selectedDateRange,
            onStatusChanged: (v) => _applyFilters(
              status:    v,
              type:      _selectedType,
              dateRange: _selectedDateRange,
            ),
            onTypeChanged: (v) => _applyFilters(
              status:    _selectedStatus,
              type:      v,
              dateRange: _selectedDateRange,
            ),
            onDateRangeChanged: (v) => _applyFilters(
              status:    _selectedStatus,
              type:      _selectedType,
              dateRange: v,
            ),
            onRefresh: () => context
                .read<ProductionBatchesBloc>()
                .add(const ProductionBatchesRefreshRequested()),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Table
          Expanded(
            child: BlocBuilder<ProductionBatchesBloc, ProductionBatchesState>(
              builder: (context, state) {
                if (state is ProductionBatchesLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ProductionBatchesError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context
                              .read<ProductionBatchesBloc>()
                              .add(const ProductionBatchesRefreshRequested()),
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is ProductionBatchesLoaded) {
                  if (state.batches.isEmpty) {
                    return const Center(
                        child: Text('Ishlab chiqarish batcklari topilmadi.'));
                  }
                  return ProductionBatchTable(
                    batches:          state.batches,
                    isLoadingMore:    state.isLoadingMore,
                    scrollController: _scrollController,
                    onView: (batch) => context.pushNamed(
                      AppRoutes.productionBatchDetailName,
                      extra: batch,
                    ),
                    onEdit: (batch) async {
                      final updated = await context.pushNamed(
                        AppRoutes.editProductionBatchName,
                        extra: batch,
                      );
                      if (updated == true && context.mounted) {
                        context
                            .read<ProductionBatchesBloc>()
                            .add(const ProductionBatchesRefreshRequested());
                      }
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Status bar
          const Divider(height: 1, color: AppColors.divider),
          BlocBuilder<ProductionBatchesBloc, ProductionBatchesState>(
            builder: (context, state) {
              if (state is! ProductionBatchesLoaded) {
                return const SizedBox.shrink();
              }
              return _StatusBar(state: state);
            },
          ),
        ],
      ),
    );
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});

  final ProductionBatchesLoaded state;

  @override
  Widget build(BuildContext context) {
    final planned    = state.batches.where((b) => b.status == 'planned').length;
    final inProgress = state.batches.where((b) => b.status == 'in_progress').length;
    final completed  = state.batches.where((b) => b.status == 'completed').length;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatItem(
            label: 'Jami',
            value: '${state.total}',
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 20),
          _StatItem(
            label: 'Rejalashtirilgan',
            value: '$planned',
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 20),
          _StatItem(
            label: 'Ishlab chiqarilmoqda',
            value: '$inProgress',
            color: AppColors.primaryLight,
          ),
          const SizedBox(width: 20),
          _StatItem(
            label: 'Bajarildi',
            value: '$completed',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
      ],
    );
  }
}
