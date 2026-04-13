import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/shipment_entity.dart';
import '../../domain/usecases/get_shipments_usecase.dart';
import 'shipments_event.dart';
import 'shipments_state.dart';

class ShipmentsBloc extends Bloc<ShipmentsEvent, ShipmentsState> {
  final GetShipmentsUseCase getShipmentsUseCase;

  int? _activeClientId;
  DateTimeRange? _activeDateRange;

  ShipmentsBloc({required this.getShipmentsUseCase})
      : super(const ShipmentsInitial()) {
    on<ShipmentsLoadRequested>(_onLoadRequested);
    on<ShipmentsRefreshRequested>(_onRefreshRequested);
    on<ShipmentsFiltersChanged>(_onFiltersChanged);
    on<ShipmentsNextPageRequested>(_onNextPageRequested);
  }

  Future<void> _onLoadRequested(
    ShipmentsLoadRequested event,
    Emitter<ShipmentsState> emit,
  ) async {
    emit(const ShipmentsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    ShipmentsRefreshRequested event,
    Emitter<ShipmentsState> emit,
  ) async {
    emit(const ShipmentsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onFiltersChanged(
    ShipmentsFiltersChanged event,
    Emitter<ShipmentsState> emit,
  ) async {
    _activeClientId = event.clientId;
    _activeDateRange = event.dateRange;
    emit(const ShipmentsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onNextPageRequested(
    ShipmentsNextPageRequested event,
    Emitter<ShipmentsState> emit,
  ) async {
    final current = state;
    if (current is! ShipmentsLoaded ||
        !current.hasNextPage ||
        current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  Future<void> _fetchPage(
    Emitter<ShipmentsState> emit, {
    required int page,
    required bool replace,
  }) async {
    String? dateFrom;
    String? dateTo;
    if (_activeDateRange != null) {
      final start = _activeDateRange!.start;
      final end   = _activeDateRange!.end;
      dateFrom =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      dateTo =
          '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    }

    final result = await getShipmentsUseCase(
      clientId: _activeClientId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      page: page,
    );

    result.fold(
      (failure) => emit(ShipmentsError(failure.message)),
      (paginated) {
        final current = state;
        final existing = (!replace && current is ShipmentsLoaded)
            ? current.shipments
            : <ShipmentEntity>[];
        final merged = <ShipmentEntity>[...existing, ...paginated.data]
          ..sort((a, b) => b.shipmentDatetime.compareTo(a.shipmentDatetime));
        emit(ShipmentsLoaded(
          shipments: merged,
          hasNextPage: paginated.hasNextPage,
          currentPage: paginated.currentPage,
          activeClientId: _activeClientId,
          activeDateRange: _activeDateRange,
        ));
      },
    );
  }
}
