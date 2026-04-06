import 'package:equatable/equatable.dart';
import '../../domain/entities/product_entity.dart';

abstract class ProductsEvent extends Equatable {
  const ProductsEvent();

  @override
  List<Object?> get props => [];
}

class ProductsLoadRequested extends ProductsEvent {
  const ProductsLoadRequested();
}

class ProductsSearchChanged extends ProductsEvent {
  final String query;

  const ProductsSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class ProductsNextPageRequested extends ProductsEvent {
  const ProductsNextPageRequested();
}

class ProductsRefreshRequested extends ProductsEvent {
  const ProductsRefreshRequested();
}

class ProductsFilterChanged extends ProductsEvent {
  final int? productTypeId;
  final int? productQualityId;
  final String? status;

  const ProductsFilterChanged({
    this.productTypeId,
    this.productQualityId,
    this.status,
  });

  @override
  List<Object?> get props => [productTypeId, productQualityId, status];
}

class ProductArchiveToggleRequested extends ProductsEvent {
  final ProductEntity product;

  const ProductArchiveToggleRequested(this.product);

  @override
  List<Object?> get props => [product];
}

class ProductDeleteRequested extends ProductsEvent {
  final int productId;

  const ProductDeleteRequested(this.productId);

  @override
  List<Object?> get props => [productId];
}
