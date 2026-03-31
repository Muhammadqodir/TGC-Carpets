import 'package:equatable/equatable.dart';
import '../../domain/entities/product_entity.dart';

abstract class ProductsState extends Equatable {
  const ProductsState();

  @override
  List<Object?> get props => [];
}

class ProductsInitial extends ProductsState {
  const ProductsInitial();
}

class ProductsLoading extends ProductsState {
  const ProductsLoading();
}

class ProductsLoaded extends ProductsState {
  final List<ProductEntity> products;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;

  const ProductsLoaded({
    required this.products,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
  });

  ProductsLoaded copyWith({
    List<ProductEntity>? products,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
  }) =>
      ProductsLoaded(
        products: products ?? this.products,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
      );

  @override
  List<Object?> get props => [products, hasNextPage, isLoadingMore, currentPage];
}

class ProductsError extends ProductsState {
  final String message;

  const ProductsError(this.message);

  @override
  List<Object?> get props => [message];
}
