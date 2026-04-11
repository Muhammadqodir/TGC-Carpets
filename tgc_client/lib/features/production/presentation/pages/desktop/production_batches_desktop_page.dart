import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/machine_entity.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../../domain/repositories/production_repository.dart';
import '../../bloc/production_batches_bloc.dart';
import '../../bloc/production_batches_event.dart';
import '../../bloc/production_batches_state.dart';
import '../../widget/production_batch_table.dart';
import '../../widget/production_filter_bar.dart';
import '../args/production_batch_detail_args.dart';
import '../../../../../core/di/injection.dart';

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
  MachineEntity? _selectedMachine;
  DateTimeRange? _selectedDateRange;
  List<MachineEntity> _machines = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMachines();
  }

  Future<void> _loadMachines() async {
    final repo = sl<ProductionRepository>();
    final result = await repo.getMachines();
    result.fold((_) {}, (paginated) {
      if (mounted) {
        setState(() => _machines = paginated.data);
      }
    });
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
    MachineEntity? machine,
    DateTimeRange? dateRange,
  }) {
    setState(() {
      _selectedStatus = status;
      _selectedMachine = machine;
      _selectedDateRange = dateRange;
    });
    context.read<ProductionBatchesBloc>().add(
          ProductionBatchesFiltersChanged(
            status: status,
            machineId: machine?.id,
            dateRange: dateRange,
          ),
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

  Future<void> _navigateToEdit(ProductionBatchEntity batch) async {
    final updated = await context.pushNamed(
      AppRoutes.editProductionBatchName,
      extra: batch,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
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
          ProductionFilterBar(
            selectedStatus: _selectedStatus,
            selectedMachine: _selectedMachine,
            selectedDateRange: _selectedDateRange,
            machines: _machines,
            onStatusChanged: (v) => _applyFilters(
              status: v,
              machine: _selectedMachine,
              dateRange: _selectedDateRange,
            ),
            onMachineChanged: (v) => _applyFilters(
              status: _selectedStatus,
              machine: v,
              dateRange: _selectedDateRange,
            ),
            onDateRangeChanged: (v) => _applyFilters(
              status: _selectedStatus,
              machine: _selectedMachine,
              dateRange: v,
            ),
            onRefresh: () => context
                .read<ProductionBatchesBloc>()
                .add(const ProductionBatchesRefreshRequested()),
          ),
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
                        child: Text('Ishlab chiqarish partiyalari topilmadi.'));
                  }
                  return ProductionBatchTable(
                    batches: state.batches,
                    isLoadingMore: state.isLoadingMore,
                    scrollController: _scrollController,
                    onViewDetail: _navigateToDetail,
                    onEdit: _navigateToEdit,
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
}
