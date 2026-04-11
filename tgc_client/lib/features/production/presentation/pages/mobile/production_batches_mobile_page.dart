import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/production_batches_bloc.dart';
import '../../bloc/production_batches_event.dart';
import '../../bloc/production_batches_state.dart';
import '../../widgets/production_batch_card.dart';

class ProductionBatchesMobilePage extends StatefulWidget {
  const ProductionBatchesMobilePage({super.key});

  @override
  State<ProductionBatchesMobilePage> createState() =>
      _ProductionBatchesMobilePageState();
}

class _ProductionBatchesMobilePageState
    extends State<ProductionBatchesMobilePage> {
  final _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ishlab chiqarish'),
        titleSpacing: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            strokeWidth: 2,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await context
                  .pushNamed(AppRoutes.addProductionBatchName);
              if (created == true && context.mounted) {
                context
                    .read<ProductionBatchesBloc>()
                    .add(const ProductionBatchesRefreshRequested());
              }
            },
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              strokeWidth: 2,
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: _StatusFilterBar(),
          ),
        ),
      ),
      body: Column(
        children: [
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
                        child: Text('Ishlab chiqarish batchlari topilmadi.'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async => context
                        .read<ProductionBatchesBloc>()
                        .add(const ProductionBatchesRefreshRequested()),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.batches.length +
                          (state.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        if (index >= state.batches.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        final batch = state.batches[index];
                        return ProductionBatchCard(
                          batch: batch,
                          onTap: () => context.pushNamed(
                            AppRoutes.productionBatchDetailName,
                            extra: batch,
                          ),
                          onEdit: batch.status == 'planned'
                              ? () async {
                                  final updated =
                                      await context.pushNamed(
                                    AppRoutes.editProductionBatchName,
                                    extra: batch,
                                  );
                                  if (updated == true && context.mounted) {
                                    context
                                        .read<ProductionBatchesBloc>()
                                        .add(const ProductionBatchesRefreshRequested());
                                  }
                                }
                              : null,
                        );
                      },
                    ),
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
              return _MobileStatusBar(state: state);
            },
          ),
        ],
      ),
    );
  }
}

// ── Mobile status bar ─────────────────────────────────────────────────────────

class _MobileStatusBar extends StatelessWidget {
  const _MobileStatusBar({required this.state});

  final ProductionBatchesLoaded state;

  @override
  Widget build(BuildContext context) {
    final planned    = state.batches.where((b) => b.status == 'planned').length;
    final inProgress = state.batches.where((b) => b.status == 'in_progress').length;
    final completed  = state.batches.where((b) => b.status == 'completed').length;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MobileStatItem(label: 'Jami',    value: '${state.total}', color: AppColors.textPrimary),
          _MobileStatItem(label: 'Reja',    value: '$planned',       color: AppColors.textSecondary),
          _MobileStatItem(label: "Jarayon", value: '$inProgress',    color: AppColors.primaryLight),
          _MobileStatItem(label: 'Tayyor',  value: '$completed',     color: AppColors.success),
        ],
      ),
    );
  }
}

class _MobileStatItem extends StatelessWidget {
  const _MobileStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

// ── Mobile status filter chips ────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar();

  static const _statusFilters = [
    (label: 'Barchasi',           value: null),
    (label: 'Reja',               value: 'planned'),
    (label: 'Jarayon',            value: 'in_progress'),
    (label: 'Bajarildi',          value: 'completed'),
    (label: 'Bekor qilindi',      value: 'cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductionBatchesBloc, ProductionBatchesState>(
      buildWhen: (prev, curr) =>
          curr is ProductionBatchesLoaded || prev is ProductionBatchesLoaded,
      builder: (context, state) {
        final activeFilter =
            state is ProductionBatchesLoaded ? state.activeStatusFilter : null;
        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _statusFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter   = _statusFilters[index];
              final isActive = activeFilter == filter.value;
              return FilterChip(
                selectedColor: Colors.white,
                backgroundColor: AppColors.primary,
                label: Text(
                  filter.label,
                  style: TextStyle(
                    color: isActive ? AppColors.primary : Colors.white,
                  ),
                ),
                selected: isActive,
                onSelected: (_) {
                  context.read<ProductionBatchesBloc>().add(
                        ProductionBatchesStatusFilterChanged(filter.value),
                      );
                },
              );
            },
          ),
        );
      },
    );
  }
}
