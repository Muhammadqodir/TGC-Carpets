import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/warehouse_document_entity.dart';
import '../../domain/usecases/get_warehouse_documents_usecase.dart';
import 'warehouse_docs_event.dart';
import 'warehouse_docs_state.dart';

class WarehouseDocsBloc extends Bloc<WarehouseDocsEvent, WarehouseDocsState> {
  final GetWarehouseDocumentsUseCase getWarehouseDocumentsUseCase;

  String? _activeTypeFilter;

  WarehouseDocsBloc({required this.getWarehouseDocumentsUseCase})
      : super(const WarehouseDocsInitial()) {
    on<WarehouseDocsLoadRequested>(_onLoadRequested);
    on<WarehouseDocsTypeFilterChanged>(_onTypeFilterChanged);
    on<WarehouseDocsNextPageRequested>(_onNextPageRequested);
    on<WarehouseDocsRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onLoadRequested(
    WarehouseDocsLoadRequested event,
    Emitter<WarehouseDocsState> emit,
  ) async {
    emit(const WarehouseDocsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    WarehouseDocsRefreshRequested event,
    Emitter<WarehouseDocsState> emit,
  ) async {
    emit(const WarehouseDocsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onTypeFilterChanged(
    WarehouseDocsTypeFilterChanged event,
    Emitter<WarehouseDocsState> emit,
  ) async {
    _activeTypeFilter = event.type;
    emit(const WarehouseDocsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onNextPageRequested(
    WarehouseDocsNextPageRequested event,
    Emitter<WarehouseDocsState> emit,
  ) async {
    final current = state;
    if (current is! WarehouseDocsLoaded ||
        !current.hasNextPage ||
        current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  Future<void> _fetchPage(
    Emitter<WarehouseDocsState> emit, {
    required int page,
    required bool replace,
  }) async {
    final result = await getWarehouseDocumentsUseCase(
      type: _activeTypeFilter,
      page: page,
    );

    result.fold(
      (failure) => emit(WarehouseDocsError(failure.message)),
      (paginated) {
        final current = state;
        final existing =
            (!replace && current is WarehouseDocsLoaded) ? current.documents : <WarehouseDocumentEntity>[];
        final merged = <WarehouseDocumentEntity>[...existing, ...paginated.data]
          ..sort((a, b) => b.documentDate.compareTo(a.documentDate));
        emit(WarehouseDocsLoaded(
          documents: merged,
          hasNextPage: paginated.hasNextPage,
          currentPage: paginated.currentPage,
          activeTypeFilter: _activeTypeFilter,
        ));
      },
    );
  }
}
