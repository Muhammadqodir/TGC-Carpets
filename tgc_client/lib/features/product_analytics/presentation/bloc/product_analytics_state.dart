import 'package:equatable/equatable.dart';

import '../../domain/entities/product_analytics_entity.dart';

abstract class ProductAnalyticsState extends Equatable {
  const ProductAnalyticsState();

  @override
  List<Object?> get props => [];
}

class ProductAnalyticsInitial extends ProductAnalyticsState {
  const ProductAnalyticsInitial();
}

class ProductAnalyticsLoading extends ProductAnalyticsState {
  const ProductAnalyticsLoading();
}

class ProductAnalyticsLoaded extends ProductAnalyticsState {
  final ProductAnalyticsEntity data;

  const ProductAnalyticsLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class ProductAnalyticsError extends ProductAnalyticsState {
  final String message;

  const ProductAnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
