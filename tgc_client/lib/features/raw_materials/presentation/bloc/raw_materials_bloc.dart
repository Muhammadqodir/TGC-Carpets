import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/raw_material_entity.dart';
import '../../domain/usecases/get_raw_materials_usecase.dart';
import '../../domain/repositories/raw_material_repository.dart';
import 'raw_materials_event.dart';
import 'raw_materials_state.dart';

class RawMaterialsBloc extends Bloc<RawMaterialsEvent, RawMaterialsState> {
  final GetRawMaterialsUseCase getRawMaterialsUseCase;
  final RawMaterialRepository repository;

  String? _filterType;
  String _searchQuery = '';
  int _currentPage = 1;
  Timer? _debounce;

  RawMaterialsBloc({
    required this.getRawMaterialsUseCase,
    required this.repository,
  }) : super(const RawMaterialsInitial()) {
    on<RawMaterialsLoadRequested>(_onLoad);
    on<RawMaterialsRefreshRequested>(_onRefresh);
    on<RawMaterialsNextPageRequested>(_onNextPage);
    on<RawMaterialsTypeFilterChanged>(_onTypeFilter);
    on<RawMaterialsSearchChanged>(_onSearch);
    on<RawMaterialDeleteRequested>(_onDelete);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    RawMaterialsLoadRequested event,
    Emitter<RawMaterialsState> emit,
  ) async {
    emit(const RawMaterialsLoading());
    await _fetch(emit, page: 1, replace: true);
  }

  Future<void> _onRefresh(
    RawMaterialsRefreshRequested event,
    Emitter<RawMaterialsState> emit,
  ) async {
    emit(const RawMaterialsLoading());
    await _fetch(emit, page: 1, replace: true);
  }

  void _onTypeFilter(
    RawMaterialsTypeFilterChanged event,
    Emitter<RawMaterialsState> emit,
  ) {
    _filterType = event.type;
    add(const RawMaterialsLoadRequested());
  }

  void _onSearch(
    RawMaterialsSearchChanged event,
    Emitter<RawMaterialsState> emit,
  ) {
    _debounce?.cancel();
    _searchQuery = event.query;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      add(const RawMaterialsLoadRequested());
    });
  }

  Future<void> _onNextPage(
    RawMaterialsNextPageRequested event,
    Emitter<RawMaterialsState> emit,
  ) async {
    final current = state;
    if (current is! RawMaterialsLoaded ||
        !current.hasNextPage ||
        current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));
    await _fetch(emit, page: _currentPage + 1, replace: false);
  }

  Future<void> _onDelete(
    RawMaterialDeleteRequested event,
    Emitter<RawMaterialsState> emit,
  ) async {
    final result = await repository.deleteMaterial(event.id);
    result.fold(
      (failure) => null, // silently ignore; caller shows snackbar
      (_) {
        if (state is RawMaterialsLoaded) {
          final loaded = state as RawMaterialsLoaded;
          emit(loaded.copyWith(
            materials: loaded.materials.where((m) => m.id != event.id).toList(),
          ));
        }
      },
    );
  }

  Future<void> _fetch(
    Emitter<RawMaterialsState> emit, {
    required int page,
    required bool replace,
  }) async {
    final result = await getRawMaterialsUseCase(
      type:    _filterType,
      search:  _searchQuery.isNotEmpty ? _searchQuery : null,
      page:    page,
      perPage: 50,
    );

    result.fold(
      (failure) => emit(RawMaterialsError(failure.message)),
      (paginated) {
        _currentPage = paginated.currentPage;
        final existing = replace
            ? <RawMaterialEntity>[]
            : (state is RawMaterialsLoaded
                ? (state as RawMaterialsLoaded).materials
                : <RawMaterialEntity>[]);

        emit(RawMaterialsLoaded(
          materials:   [...existing, ...paginated.data],
          hasNextPage: paginated.currentPage < paginated.lastPage,
          activeType:  _filterType,
        ));
      },
    );
  }
}
