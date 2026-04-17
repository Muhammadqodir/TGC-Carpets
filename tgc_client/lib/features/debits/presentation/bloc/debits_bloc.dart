import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_client_debits_usecase.dart';
import 'debits_event.dart';
import 'debits_state.dart';

class DebitsBloc extends Bloc<DebitsEvent, DebitsState> {
  final GetClientDebitsUseCase getClientDebitsUseCase;

  String? _activeSearch;
  String? _activeRegion;
  bool _activeHasBalance = false;

  DebitsBloc({required this.getClientDebitsUseCase})
      : super(const DebitsInitial()) {
    on<DebitsLoadRequested>(_onLoadRequested);
    on<DebitsRefreshRequested>(_onRefreshRequested);
    on<DebitsFiltersChanged>(_onFiltersChanged);
    on<DebitsNextPageRequested>(_onNextPageRequested);
  }

  Future<void> _onLoadRequested(
    DebitsLoadRequested event,
    Emitter<DebitsState> emit,
  ) async {
    emit(const DebitsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    DebitsRefreshRequested event,
    Emitter<DebitsState> emit,
  ) async {
    emit(const DebitsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onFiltersChanged(
    DebitsFiltersChanged event,
    Emitter<DebitsState> emit,
  ) async {
    _activeSearch     = event.search;
    _activeRegion     = event.region;
    _activeHasBalance = event.hasBalance;
    emit(const DebitsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onNextPageRequested(
    DebitsNextPageRequested event,
    Emitter<DebitsState> emit,
  ) async {
    final current = state;
    if (current is! DebitsLoaded || !current.hasNextPage || current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  Future<void> _fetchPage(
    Emitter<DebitsState> emit, {
    required int page,
    required bool replace,
  }) async {
    final result = await getClientDebitsUseCase(
      search:     _activeSearch,
      region:     _activeRegion,
      hasBalance: _activeHasBalance,
      page:       page,
    );

    result.fold(
      (failure) => emit(DebitsError(failure.message)),
      (paginated) {
        final existing = (state is DebitsLoaded && !replace)
            ? (state as DebitsLoaded).clients
            : <dynamic>[];

        emit(DebitsLoaded(
          clients:          [...existing, ...paginated.data],
          hasNextPage:      paginated.currentPage < paginated.lastPage,
          currentPage:      paginated.currentPage,
          activeSearch:     _activeSearch,
          activeRegion:     _activeRegion,
          activeHasBalance: _activeHasBalance,
        ));
      },
    );
  }
}
