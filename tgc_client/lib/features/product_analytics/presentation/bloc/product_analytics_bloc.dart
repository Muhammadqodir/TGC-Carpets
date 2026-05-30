import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_product_analytics_usecase.dart';
import 'product_analytics_event.dart';
import 'product_analytics_state.dart';

class ProductAnalyticsBloc
    extends Bloc<ProductAnalyticsEvent, ProductAnalyticsState> {
  final GetProductAnalyticsUseCase _getAnalyticsUseCase;

  ProductAnalyticsBloc({
    required GetProductAnalyticsUseCase getAnalyticsUseCase,
  })  : _getAnalyticsUseCase = getAnalyticsUseCase,
        super(const ProductAnalyticsInitial()) {
    on<ProductAnalyticsLoadRequested>(_onLoadRequested);
    on<ProductAnalyticsPeriodChanged>(_onPeriodChanged);
  }

  Future<void> _onLoadRequested(
    ProductAnalyticsLoadRequested event,
    Emitter<ProductAnalyticsState> emit,
  ) async {
    emit(const ProductAnalyticsLoading());
    final result = await _getAnalyticsUseCase(
      GetProductAnalyticsParams(
        periodFrom: event.periodFrom,
        periodTo:   event.periodTo,
        trendBy:    event.trendBy,
      ),
    );
    result.fold(
      (failure) => emit(ProductAnalyticsError(failure.message)),
      (data)    => emit(ProductAnalyticsLoaded(data)),
    );
  }

  Future<void> _onPeriodChanged(
    ProductAnalyticsPeriodChanged event,
    Emitter<ProductAnalyticsState> emit,
  ) async {
    // Reuse load logic; trendBy inferred from period length
    final trendBy = _inferTrendBy(event.periodFrom, event.periodTo);
    add(ProductAnalyticsLoadRequested(
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
