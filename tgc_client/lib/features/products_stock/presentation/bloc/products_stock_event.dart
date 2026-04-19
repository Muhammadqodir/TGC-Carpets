import 'package:equatable/equatable.dart';

abstract class ProductsStockEvent extends Equatable {
  const ProductsStockEvent();

  @override
  List<Object?> get props => [];
}

class ProductsStockLoadRequested extends ProductsStockEvent {
  const ProductsStockLoadRequested();
}

class ProductsStockRefreshRequested extends ProductsStockEvent {
  const ProductsStockRefreshRequested();
}

class ProductsStockNextPageRequested extends ProductsStockEvent {
  const ProductsStockNextPageRequested();
}

class ProductsStockFilterChanged extends ProductsStockEvent {
  final int? productTypeId;
  final int? productQualityId;

  const ProductsStockFilterChanged({
    this.productTypeId,
    this.productQualityId,
  });

  @override
  List<Object?> get props => [productTypeId, productQualityId];
}

class ProductsStockSearchChanged extends ProductsStockEvent {
  final String query;

  const ProductsStockSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}
