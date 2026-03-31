import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_clients_usecase.dart';
import 'clients_event.dart';
import 'clients_state.dart';

class ClientsBloc extends Bloc<ClientsEvent, ClientsState> {
  final GetClientsUseCase getClientsUseCase;

  String _searchQuery = '';
  Timer? _debounce;

  ClientsBloc({required this.getClientsUseCase}) : super(const ClientsInitial()) {
    on<ClientsLoadRequested>(_onLoadRequested);
    on<ClientsSearchChanged>(_onSearchChanged);
    on<ClientsNextPageRequested>(_onNextPageRequested);
    on<ClientsRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onLoadRequested(
    ClientsLoadRequested event,
    Emitter<ClientsState> emit,
  ) async {
    emit(const ClientsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    ClientsRefreshRequested event,
    Emitter<ClientsState> emit,
  ) async {
    emit(const ClientsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  void _onSearchChanged(
    ClientsSearchChanged event,
    Emitter<ClientsState> emit,
  ) {
    _searchQuery = event.query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      add(const ClientsLoadRequested());
    });
  }

  Future<void> _onNextPageRequested(
    ClientsNextPageRequested event,
    Emitter<ClientsState> emit,
  ) async {
    final current = state;
    if (current is! ClientsLoaded || !current.hasNextPage || current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  Future<void> _fetchPage(
    Emitter<ClientsState> emit, {
    required int page,
    required bool replace,
  }) async {
    final result = await getClientsUseCase(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      page: page,
    );

    result.fold(
      (failure) => emit(ClientsError(failure.message)),
      (paginated) {
        final current = state;
        final existing =
            (!replace && current is ClientsLoaded) ? current.clients : [];
        emit(ClientsLoaded(
          clients: [...existing, ...paginated.data],
          hasNextPage: paginated.hasNextPage,
          currentPage: paginated.currentPage,
        ));
      },
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
