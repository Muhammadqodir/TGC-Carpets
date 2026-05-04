import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/features/analytics/domain/usecases/get_client_analytics_usecase.dart';
import 'package:tgc_client/features/analytics/domain/usecases/get_financial_analytics_usecase.dart';
import 'package:tgc_client/features/analytics/domain/usecases/get_production_analytics_usecase.dart';
import 'package:tgc_client/features/analytics/domain/usecases/get_sales_analytics_usecase.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_event.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_state.dart';

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final GetSalesAnalyticsUseCase getSalesAnalyticsUseCase;
  final GetProductionAnalyticsUseCase getProductionAnalyticsUseCase;
  final GetFinancialAnalyticsUseCase getFinancialAnalyticsUseCase;
  final GetClientAnalyticsUseCase getClientAnalyticsUseCase;

  AnalyticsBloc({
    required this.getSalesAnalyticsUseCase,
    required this.getProductionAnalyticsUseCase,
    required this.getFinancialAnalyticsUseCase,
    required this.getClientAnalyticsUseCase,
  }) : super(AnalyticsInitial()) {
    on<SalesAnalyticsRequested>(_onSalesAnalyticsRequested);
    on<ProductionAnalyticsRequested>(_onProductionAnalyticsRequested);
    on<FinancialAnalyticsRequested>(_onFinancialAnalyticsRequested);
    on<ClientAnalyticsRequested>(_onClientAnalyticsRequested);
  }

  Future<void> _onSalesAnalyticsRequested(
    SalesAnalyticsRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(AnalyticsLoading());
    final result = await getSalesAnalyticsUseCase(from: event.from, to: event.to);
    result.fold(
      (failure) => emit(AnalyticsError(failure.message)),
      (data) => emit(SalesAnalyticsLoaded(
        data: data,
        from: event.from,
        to: event.to,
      )),
    );
  }

  Future<void> _onProductionAnalyticsRequested(
    ProductionAnalyticsRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(AnalyticsLoading());
    final result = await getProductionAnalyticsUseCase(from: event.from, to: event.to);
    result.fold(
      (failure) => emit(AnalyticsError(failure.message)),
      (data) => emit(ProductionAnalyticsLoaded(
        data: data,
        from: event.from,
        to: event.to,
      )),
    );
  }

  Future<void> _onFinancialAnalyticsRequested(
    FinancialAnalyticsRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(AnalyticsLoading());
    final result = await getFinancialAnalyticsUseCase(from: event.from, to: event.to);
    result.fold(
      (failure) => emit(AnalyticsError(failure.message)),
      (data) => emit(FinancialAnalyticsLoaded(
        data: data,
        from: event.from,
        to: event.to,
      )),
    );
  }

  Future<void> _onClientAnalyticsRequested(
    ClientAnalyticsRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(AnalyticsLoading());
    final result = await getClientAnalyticsUseCase(
      from: event.from,
      to: event.to,
      limit: event.limit,
    );
    result.fold(
      (failure) => emit(AnalyticsError(failure.message)),
      (data) => emit(ClientAnalyticsLoaded(
        data: data,
        from: event.from,
        to: event.to,
      )),
    );
  }
}
