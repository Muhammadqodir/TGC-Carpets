import 'package:equatable/equatable.dart';

abstract class ProductAnalyticsEvent extends Equatable {
  const ProductAnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class ProductAnalyticsLoadRequested extends ProductAnalyticsEvent {
  final String periodFrom;
  final String periodTo;
  final String trendBy;

  const ProductAnalyticsLoadRequested({
    required this.periodFrom,
    required this.periodTo,
    this.trendBy = 'day',
  });

  @override
  List<Object?> get props => [periodFrom, periodTo, trendBy];
}

class ProductAnalyticsPeriodChanged extends ProductAnalyticsEvent {
  final String periodFrom;
  final String periodTo;

  const ProductAnalyticsPeriodChanged({
    required this.periodFrom,
    required this.periodTo,
  });

  @override
  List<Object?> get props => [periodFrom, periodTo];
}
