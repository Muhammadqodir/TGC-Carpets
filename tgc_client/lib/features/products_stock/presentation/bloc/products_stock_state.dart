import 'package:equatable/equatable.dart';
import '../../domain/entities/stock_variant_entity.dart';

abstract class ProductsStockState extends Equatable {
  const ProductsStockState();

  @override
  List<Object?> get props => [];
}

class ProductsStockInitial extends ProductsStockState {
  const ProductsStockInitial();
}

class ProductsStockLoading extends ProductsStockState {
  const ProductsStockLoading();
}

class ProductsStockLoaded extends ProductsStockState {
  final List<StockVariantEntity> variants;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;
  final int total;
  final int? filterTypeId;
  final int? filterQualityId;
  final int? filterSizeId;

  const ProductsStockLoaded({
    required this.variants,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    required this.total,
    this.filterTypeId,
    this.filterQualityId,
    this.filterSizeId,
  });

  ProductsStockLoaded copyWith({
    List<StockVariantEntity>? variants,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    int? total,
    int? filterTypeId,
    int? filterQualityId,
    int? filterSizeId,
  }) =>
      ProductsStockLoaded(
        variants:        variants ?? this.variants,
        hasNextPage:     hasNextPage ?? this.hasNextPage,
        isLoadingMore:   isLoadingMore ?? this.isLoadingMore,
        currentPage:     currentPage ?? this.currentPage,
        total:           total ?? this.total,
        filterTypeId:    filterTypeId ?? this.filterTypeId,
        filterQualityId: filterQualityId ?? this.filterQualityId,
        filterSizeId:    filterSizeId ?? this.filterSizeId,
      );

  @override
  List<Object?> get props => [
        variants,
        hasNextPage,
        isLoadingMore,
        currentPage,
        total,
        filterTypeId,
        filterQualityId,
        filterSizeId,
      ];
}

class ProductsStockError extends ProductsStockState {
  final String message;

  const ProductsStockError(this.message);

  @override
  List<Object?> get props => [message];
}
