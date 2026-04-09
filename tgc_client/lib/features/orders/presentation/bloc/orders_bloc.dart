import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/order_entity.dart';
import '../../domain/usecases/get_orders_usecase.dart';
import 'orders_event.dart';
import 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final GetOrdersUseCase getOrdersUseCase;

  String? _activeStatusFilter;
  int? _activeClientIdFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  OrdersBloc({required this.getOrdersUseCase})
      : super(const OrdersInitial()) {
    on<OrdersLoadRequested>(_onLoadRequested);
    on<OrdersRefreshRequested>(_onRefreshRequested);
    on<OrdersFiltersChanged>(_onFiltersChanged);
    on<OrdersStatusFilterChanged>(_onStatusFilterChanged);
    on<OrdersNextPageRequested>(_onNextPageRequested);
    on<OrderDeleted>(_onOrderDeleted);
  }

  Future<void> _onLoadRequested(
    OrdersLoadRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    OrdersRefreshRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onFiltersChanged(
    OrdersFiltersChanged event,
    Emitter<OrdersState> emit,
  ) async {
    _activeStatusFilter = event.status;
    _activeClientIdFilter = event.clientId;
    _dateFrom = event.dateRange?.start;
    _dateTo = event.dateRange?.end;
    emit(const OrdersLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onStatusFilterChanged(
    OrdersStatusFilterChanged event,
    Emitter<OrdersState> emit,
  ) async {
    _activeStatusFilter = event.status;
    emit(const OrdersLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onNextPageRequested(
    OrdersNextPageRequested event,
    Emitter<OrdersState> emit,
  ) async {
    final current = state;
    if (current is! OrdersLoaded || !current.hasNextPage || current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  void _onOrderDeleted(OrderDeleted event, Emitter<OrdersState> emit) {
    final current = state;
    if (current is OrdersLoaded) {
      emit(current.copyWith(
        orders: current.orders.where((o) => o.id != event.orderId).toList(),
      ));
    }
  }

  Future<void> _fetchPage(
    Emitter<OrdersState> emit, {
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

    final result = await getOrdersUseCase(
      status: _activeStatusFilter,
      clientId: _activeClientIdFilter,
      dateFrom: dateFrom,
      dateTo: dateTo,
      page: page,
    );

    result.fold(
      (failure) => emit(OrdersError(failure.message)),
      (paginated) {
        final current = state;
        final existing = (!replace && current is OrdersLoaded)
            ? current.orders
            : <OrderEntity>[];
        final merged = [...existing, ...paginated.data];
        emit(OrdersLoaded(
          orders: merged,
          hasNextPage: paginated.hasNextPage,
          currentPage: paginated.currentPage,
          activeStatusFilter: _activeStatusFilter,
          activeClientIdFilter: _activeClientIdFilter,
        ));
      },
    );
  }
}
