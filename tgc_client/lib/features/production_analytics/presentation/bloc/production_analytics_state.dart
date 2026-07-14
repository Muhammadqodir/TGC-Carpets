import 'package:equatable/equatable.dart';

import '../../domain/entities/production_analytics_entity.dart';

abstract class ProductionAnalyticsState extends Equatable {
  const ProductionAnalyticsState();

  @override
  List<Object?> get props => [];
}

class ProductionAnalyticsInitial extends ProductionAnalyticsState {
  const ProductionAnalyticsInitial();
}

class ProductionAnalyticsLoading extends ProductionAnalyticsState {
  const ProductionAnalyticsLoading();
}

class ProductionAnalyticsLoaded extends ProductionAnalyticsState {
  final ProductionAnalyticsEntity data;

  const ProductionAnalyticsLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class ProductionAnalyticsError extends ProductionAnalyticsState {
  final String message;

  const ProductionAnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
