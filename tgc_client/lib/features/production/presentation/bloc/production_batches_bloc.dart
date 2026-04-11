import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/production_batch_entity.dart';
import '../../domain/usecases/get_production_batches_usecase.dart';
import 'production_batches_event.dart';
import 'production_batches_state.dart';

class ProductionBatchesBloc
    extends Bloc<ProductionBatchesEvent, ProductionBatchesState> {
  final GetProductionBatchesUseCase getProductionBatchesUseCase;

  String? _activeStatusFilter;
  int? _activeMachineIdFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  ProductionBatchesBloc({required this.getProductionBatchesUseCase})
      : super(const ProductionBatchesInitial()) {
    on<ProductionBatchesLoadRequested>(_onLoadRequested);
    on<ProductionBatchesRefreshRequested>(_onRefreshRequested);
    on<ProductionBatchesFiltersChanged>(_onFiltersChanged);
    on<ProductionBatchesStatusFilterChanged>(_onStatusFilterChanged);
    on<ProductionBatchesNextPageRequested>(_onNextPageRequested);
    on<ProductionBatchDeleted>(_onBatchDeleted);
  }

  Future<void> _onLoadRequested(
    ProductionBatchesLoadRequested event,
    Emitter<ProductionBatchesState> emit,
  ) async {
    emit(const ProductionBatchesLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    ProductionBatchesRefreshRequested event,
    Emitter<ProductionBatchesState> emit,
  ) async {
    emit(const ProductionBatchesLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onFiltersChanged(
    ProductionBatchesFiltersChanged event,
    Emitter<ProductionBatchesState> emit,
  ) async {
    _activeStatusFilter = event.status;
    _activeMachineIdFilter = event.machineId;
    _dateFrom = event.dateRange?.start;
    _dateTo = event.dateRange?.end;
    emit(const ProductionBatchesLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onStatusFilterChanged(
    ProductionBatchesStatusFilterChanged event,
    Emitter<ProductionBatchesState> emit,
  ) async {
    _activeStatusFilter = event.status;
    emit(const ProductionBatchesLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onNextPageRequested(
    ProductionBatchesNextPageRequested event,
    Emitter<ProductionBatchesState> emit,
  ) async {
    final current = state;
    if (current is! ProductionBatchesLoaded ||
        !current.hasNextPage ||
        current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  void _onBatchDeleted(
      ProductionBatchDeleted event, Emitter<ProductionBatchesState> emit) {
    final current = state;
    if (current is ProductionBatchesLoaded) {
      emit(current.copyWith(
        batches:
            current.batches.where((b) => b.id != event.batchId).toList(),
      ));
    }
  }

  Future<void> _fetchPage(
    Emitter<ProductionBatchesState> emit, {
    required int page,
    required bool replace,
  }) async {
    String? dateFrom;
    String? dateTo;
    if (_dateFrom != null) {
      dateFrom =
          '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}';
    }
    if (_dateTo != null) {
      dateTo =
          '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}';
    }

    final result = await getProductionBatchesUseCase(
      status: _activeStatusFilter,
      machineId: _activeMachineIdFilter,
      dateFrom: dateFrom,
      dateTo: dateTo,
      page: page,
    );

    result.fold(
      (failure) => emit(ProductionBatchesError(failure.message)),
      (paginated) {
        final current = state;
        final existing = (!replace && current is ProductionBatchesLoaded)
            ? current.batches
            : <ProductionBatchEntity>[];
        final merged = [...existing, ...paginated.data];
        emit(ProductionBatchesLoaded(
          batches: merged,
          hasNextPage: paginated.hasNextPage,
          currentPage: paginated.currentPage,
          activeStatusFilter: _activeStatusFilter,
          activeMachineIdFilter: _activeMachineIdFilter,
        ));
      },
    );
  }
}
