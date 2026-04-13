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
  final int? productSizeId;

  const ProductsStockFilterChanged({
    this.productTypeId,
    this.productQualityId,
    this.productSizeId,
  });

  @override
  List<Object?> get props => [productTypeId, productQualityId, productSizeId];
}
