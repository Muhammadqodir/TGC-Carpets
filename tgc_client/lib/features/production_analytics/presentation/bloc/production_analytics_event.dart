import 'package:equatable/equatable.dart';

abstract class ProductionAnalyticsEvent extends Equatable {
  const ProductionAnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class ProductionAnalyticsLoadRequested extends ProductionAnalyticsEvent {
  final String periodFrom;
  final String periodTo;
  final String trendBy;

  const ProductionAnalyticsLoadRequested({
    required this.periodFrom,
    required this.periodTo,
    this.trendBy = 'day',
  });

  @override
  List<Object?> get props => [periodFrom, periodTo, trendBy];
}

class ProductionAnalyticsPeriodChanged extends ProductionAnalyticsEvent {
  final String periodFrom;
  final String periodTo;

  const ProductionAnalyticsPeriodChanged({
    required this.periodFrom,
    required this.periodTo,
  });

  @override
  List<Object?> get props => [periodFrom, periodTo];
}
