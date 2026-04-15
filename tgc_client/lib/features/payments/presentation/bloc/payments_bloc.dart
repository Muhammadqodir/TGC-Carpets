import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/payment_entity.dart';
import '../../domain/usecases/delete_payment_usecase.dart';
import '../../domain/usecases/get_payments_usecase.dart';
import 'payments_event.dart';
import 'payments_state.dart';

class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  final GetPaymentsUseCase getPaymentsUseCase;
  final DeletePaymentUseCase deletePaymentUseCase;

  int? _activeClientId;
  DateTimeRange? _activeDateRange;

  PaymentsBloc({
    required this.getPaymentsUseCase,
    required this.deletePaymentUseCase,
  }) : super(const PaymentsInitial()) {
    on<PaymentsLoadRequested>(_onLoadRequested);
    on<PaymentsRefreshRequested>(_onRefreshRequested);
    on<PaymentsFiltersChanged>(_onFiltersChanged);
    on<PaymentsNextPageRequested>(_onNextPageRequested);
    on<PaymentDeleted>(_onDeleted);
  }

  Future<void> _onLoadRequested(
    PaymentsLoadRequested event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(const PaymentsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    PaymentsRefreshRequested event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(const PaymentsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onFiltersChanged(
    PaymentsFiltersChanged event,
    Emitter<PaymentsState> emit,
  ) async {
    _activeClientId = event.clientId;
    _activeDateRange = event.dateRange;
    emit(const PaymentsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onNextPageRequested(
    PaymentsNextPageRequested event,
    Emitter<PaymentsState> emit,
  ) async {
    final current = state;
    if (current is! PaymentsLoaded ||
        !current.hasNextPage ||
        current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  Future<void> _onDeleted(
    PaymentDeleted event,
    Emitter<PaymentsState> emit,
  ) async {
    final result = await deletePaymentUseCase(event.id);
    result.fold(
      (failure) => emit(PaymentsError(failure.message)),
      (_) {
        final current = state;
        if (current is PaymentsLoaded) {
          emit(current.copyWith(
            payments: current.payments.where((p) => p.id != event.id).toList(),
          ));
        }
      },
    );
  }

  Future<void> _fetchPage(
    Emitter<PaymentsState> emit, {
    required int page,
    required bool replace,
  }) async {
    String? dateFrom;
    String? dateTo;
    if (_activeDateRange != null) {
      final start = _activeDateRange!.start;
      final end = _activeDateRange!.end;
      dateFrom =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      dateTo =
          '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    }

    final result = await getPaymentsUseCase(
      clientId: _activeClientId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      page: page,
    );

    result.fold(
      (failure) => emit(PaymentsError(failure.message)),
      (paginated) {
        final current = state;
        final existing = (!replace && current is PaymentsLoaded)
            ? current.payments
            : <PaymentEntity>[];
        final merged = <PaymentEntity>[...existing, ...paginated.data]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        emit(PaymentsLoaded(
          payments: merged,
          hasNextPage: paginated.hasNextPage,
          currentPage: paginated.currentPage,
          activeClientId: _activeClientId,
          activeDateRange: _activeDateRange,
        ));
      },
    );
  }
}
