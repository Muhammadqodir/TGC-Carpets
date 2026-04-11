import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/production_batch_entity.dart';
import '../../domain/usecases/get_production_batches_usecase.dart';
import 'production_batches_event.dart';
import 'production_batches_state.dart';

class ProductionBatchesBloc
    extends Bloc<ProductionBatchesEvent, ProductionBatchesState> {
  final GetProductionBatchesUseCase getProductionBatchesUseCase;

  String? _activeStatusFilter;
  String? _activeTypeFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  ProductionBatchesBloc({required this.getProductionBatchesUseCase})
      : super(const ProductionBatchesInitial()) {
    on<ProductionBatchesLoadRequested>(_onLoadRequested);
    on<ProductionBatchesRefreshRequested>(_onRefreshRequested);
    on<ProductionBatchesFiltersChanged>(_onFiltersChanged);
    on<ProductionBatchesStatusFilterChanged>(_onStatusFilterChanged);
    on<ProductionBatchesNextPageRequested>(_onNextPageRequested);
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
    _activeTypeFilter   = event.type;
    _dateFrom = event.dateRange?.start;
    _dateTo   = event.dateRange?.end;
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

  Future<void> _fetchPage(
    Emitter<ProductionBatchesState> emit, {
    required int page,
    required bool replace,
  }) async {
    final dateFrom = _dateFrom != null
        ? '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}'
        : null;
    final dateTo = _dateTo != null
        ? '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}'
        : null;

    final result = await getProductionBatchesUseCase(
      status:   _activeStatusFilter,
      type:     _activeTypeFilter,
      dateFrom: dateFrom,
      dateTo:   dateTo,
      page:     page,
    );

    result.fold(
      (failure) => emit(ProductionBatchesError(failure.message)),
      (paginated) {
        final current  = state;
        final existing = (!replace && current is ProductionBatchesLoaded)
            ? current.batches
            : <ProductionBatchEntity>[];
        final merged = [...existing, ...paginated.data];
        emit(ProductionBatchesLoaded(
          batches:            merged,
          hasNextPage:        paginated.hasNextPage,
          currentPage:        paginated.currentPage,
          total:              paginated.total,
          activeStatusFilter: _activeStatusFilter,
          activeTypeFilter:   _activeTypeFilter,
          activeDateRange: (_dateFrom != null && _dateTo != null)
              ? DateTimeRangeSimple(start: _dateFrom!, end: _dateTo!)
              : null,
        ));
      },
    );
  }
}
