import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_production_analytics_usecase.dart';
import 'production_analytics_event.dart';
import 'production_analytics_state.dart';

class ProductionAnalyticsBloc
    extends Bloc<ProductionAnalyticsEvent, ProductionAnalyticsState> {
  final GetProductionAnalyticsUseCase _getAnalyticsUseCase;

  ProductionAnalyticsBloc({
    required GetProductionAnalyticsUseCase getAnalyticsUseCase,
  })  : _getAnalyticsUseCase = getAnalyticsUseCase,
        super(const ProductionAnalyticsInitial()) {
    on<ProductionAnalyticsLoadRequested>(_onLoadRequested);
    on<ProductionAnalyticsPeriodChanged>(_onPeriodChanged);
  }

  Future<void> _onLoadRequested(
    ProductionAnalyticsLoadRequested event,
    Emitter<ProductionAnalyticsState> emit,
  ) async {
    emit(const ProductionAnalyticsLoading());
    final result = await _getAnalyticsUseCase(
      GetProductionAnalyticsParams(
        periodFrom: event.periodFrom,
        periodTo:   event.periodTo,
        trendBy:    event.trendBy,
      ),
    );
    result.fold(
      (failure) => emit(ProductionAnalyticsError(failure.message)),
      (data)    => emit(ProductionAnalyticsLoaded(data)),
    );
  }

  Future<void> _onPeriodChanged(
    ProductionAnalyticsPeriodChanged event,
    Emitter<ProductionAnalyticsState> emit,
  ) async {
    // Reuse load logic; trendBy inferred from period length
    final trendBy = _inferTrendBy(event.periodFrom, event.periodTo);
    add(ProductionAnalyticsLoadRequested(
      periodFrom: event.periodFrom,
      periodTo:   event.periodTo,
      trendBy:    trendBy,
    ));
  }

  /// Auto-select trend granularity: day ≤60d | week ≤180d | month >180d
  String _inferTrendBy(String from, String to) {
    final days = DateTime.parse(to).difference(DateTime.parse(from)).inDays;
    if (days <= 60) return 'day';
    if (days <= 180) return 'week';
    return 'month';
  }
}
