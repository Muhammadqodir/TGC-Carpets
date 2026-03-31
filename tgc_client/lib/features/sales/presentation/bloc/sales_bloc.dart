import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_sales_usecase.dart';
import 'sales_event.dart';
import 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final GetSalesUseCase getSalesUseCase;

  String? _paymentStatusFilter;

  SalesBloc({required this.getSalesUseCase}) : super(const SalesInitial()) {
    on<SalesLoadRequested>(_onLoadRequested);
    on<SalesFilterChanged>(_onFilterChanged);
    on<SalesNextPageRequested>(_onNextPageRequested);
    on<SalesRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onLoadRequested(
    SalesLoadRequested event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    SalesRefreshRequested event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onFilterChanged(
    SalesFilterChanged event,
    Emitter<SalesState> emit,
  ) async {
    _paymentStatusFilter = event.paymentStatus;
    emit(const SalesLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onNextPageRequested(
    SalesNextPageRequested event,
    Emitter<SalesState> emit,
  ) async {
    final current = state;
    if (current is! SalesLoaded || !current.hasNextPage || current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  Future<void> _fetchPage(
    Emitter<SalesState> emit, {
    required int page,
    required bool replace,
  }) async {
    final result = await getSalesUseCase(
      paymentStatus: _paymentStatusFilter,
      page: page,
    );

    result.fold(
      (failure) => emit(SalesError(failure.message)),
      (paginated) {
        final current = state;
        final existing =
            (!replace && current is SalesLoaded) ? current.sales : [];
        emit(SalesLoaded(
          sales: [...existing, ...paginated.data],
          hasNextPage: paginated.hasNextPage,
          currentPage: paginated.currentPage,
          activeFilter: _paymentStatusFilter,
        ));
      },
    );
  }
}
