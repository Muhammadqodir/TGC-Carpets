import 'package:equatable/equatable.dart';

import '../../domain/entities/product_analytics_entity.dart';

abstract class TopProductsFilterState extends Equatable {
  final int? typeId;
  final int? qualityId;
  final int? colorId;
  final int? sizeId;
  final int? edgeId;
  final int limit;

  const TopProductsFilterState({
    this.typeId,
    this.qualityId,
    this.colorId,
    this.sizeId,
    this.edgeId,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [typeId, qualityId, colorId, sizeId, edgeId, limit];
}

class TopProductsFilterInitial extends TopProductsFilterState {
  const TopProductsFilterInitial() : super(limit: 10);
}

class TopProductsFilterLoading extends TopProductsFilterState {
  final List<TopProductItem> previousProducts;

  const TopProductsFilterLoading({
    required List<TopProductItem> previous,
    super.typeId,
    super.qualityId,
    super.colorId,
    super.sizeId,
    super.edgeId,
    super.limit,
  }) : previousProducts = previous;

  @override
  List<Object?> get props =>
      [...super.props, previousProducts];
}

class TopProductsFilterLoaded extends TopProductsFilterState {
  final List<TopProductItem> products;

  const TopProductsFilterLoaded({
    required this.products,
    super.typeId,
    super.qualityId,
    super.colorId,
    super.sizeId,
    super.edgeId,
    super.limit,
  });

  @override
  List<Object?> get props => [...super.props, products];
}

class TopProductsFilterError extends TopProductsFilterState {
  final String message;

  const TopProductsFilterError({
    required this.message,
    super.typeId,
    super.qualityId,
    super.colorId,
    super.sizeId,
    super.edgeId,
    super.limit,
  });

  @override
  List<Object?> get props => [...super.props, message];
}
