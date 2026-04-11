import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../bloc/production_batches_bloc.dart';
import '../../bloc/production_batches_event.dart';
import '../../bloc/production_batches_state.dart';
import '../../widget/production_batch_card.dart';
import '../args/production_batch_detail_args.dart';

class ProductionBatchesMobilePage extends StatefulWidget {
  const ProductionBatchesMobilePage({super.key});

  @override
  State<ProductionBatchesMobilePage> createState() =>
      _ProductionBatchesMobilePageState();
}

class _ProductionBatchesMobilePageState
    extends State<ProductionBatchesMobilePage> {
  final _scrollController = ScrollController();
  String? _selectedStatus;

  static const _statusFilters = <String?, String>{
    null: 'Barchasi',
    'planned': 'Rejalashtirilgan',
    'in_progress': 'Ishlab chiqarilmoqda',
    'completed': 'Yakunlangan',
    'cancelled': 'Bekor qilingan',
  };

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

  void _onStatusChanged(String? status) {
    setState(() => _selectedStatus = status);
    context.read<ProductionBatchesBloc>().add(
          ProductionBatchesFiltersChanged(status: status),
        );
  }

  Future<void> _navigateToDetail(ProductionBatchEntity batch) async {
    final updated = await context.pushNamed(
      AppRoutes.productionBatchDetailName,
      extra: ProductionBatchDetailArgs(batch: batch),
    );
    if (updated == true && mounted) {
      context
          .read<ProductionBatchesBloc>()
          .add(const ProductionBatchesRefreshRequested());
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ishlab chiqarish'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created =
              await context.pushNamed(AppRoutes.addProductionBatchName);
          if (created == true && context.mounted) {
            context
                .read<ProductionBatchesBloc>()
                .add(const ProductionBatchesRefreshRequested());
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildStatusChips(),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: BlocBuilder<ProductionBatchesBloc,
                ProductionBatchesState>(
              builder: (context, state) {
                if (state is ProductionBatchesLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ProductionBatchesError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
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
                    ),
                  );
                }
                if (state is ProductionBatchesLoaded) {
                  if (state.batches.isEmpty) {
                    return const Center(
                        child:
                            Text('Ishlab chiqarish partiyalari topilmadi.'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      context
                          .read<ProductionBatchesBloc>()
                          .add(const ProductionBatchesRefreshRequested());
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.batches.length +
                          (state.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.batches.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                                child: CircularProgressIndicator()),
                          );
                        }
                        final batch = state.batches[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ProductionBatchCard(
                            batch: batch,
                            onTap: () => _navigateToDetail(batch),
                          ),
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _statusFilters.entries.map((entry) {
          final isSelected = _selectedStatus == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              selected: isSelected,
              label: Text(entry.value),
              onSelected: (_) => _onStatusChanged(entry.key),
              selectedColor: AppColors.primary.withAlpha(25),
              checkmarkColor: AppColors.primary,
            ),
          );
        }).toList(),
      ),
    );
  }
}
