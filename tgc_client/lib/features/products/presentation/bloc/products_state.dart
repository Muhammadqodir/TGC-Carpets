import 'package:equatable/equatable.dart';
import '../../domain/entities/product_entity.dart';

abstract class ProductsState extends Equatable {
  const ProductsState();

  @override
  List<Object?> get props => [];
}

// ─── Action status ──────────────────────────────────────────────────────────

sealed class ProductActionStatus extends Equatable {
  const ProductActionStatus();
}

class ProductActionIdle extends ProductActionStatus {
  const ProductActionIdle();
  @override
  List<Object?> get props => [];
}

class ProductActionPending extends ProductActionStatus {
  final int productId;
  const ProductActionPending(this.productId);
  @override
  List<Object?> get props => [productId];
}

class ProductActionSuccess extends ProductActionStatus {
  final String message;
  const ProductActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class ProductActionFailure extends ProductActionStatus {
  final String message;
  const ProductActionFailure(this.message);
  @override
  List<Object?> get props => [message];
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
  final int total;
  final int? filterTypeId;
  final int? filterQualityId;
  final int? filterColorId;
  final String? filterStatus;
  final ProductActionStatus actionStatus;

  const ProductsLoaded({
    required this.products,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    required this.total,
    this.filterTypeId,
    this.filterQualityId,
    this.filterColorId,
    this.filterStatus,
    this.actionStatus = const ProductActionIdle(),
  });

  ProductsLoaded copyWith({
    List<ProductEntity>? products,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    int? total,
    ProductActionStatus? actionStatus,
    Object? filterTypeId = _sentinel,
    Object? filterQualityId = _sentinel,
    Object? filterColorId = _sentinel,
    Object? filterStatus = _sentinel,
  }) =>
      ProductsLoaded(
        products: products ?? this.products,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        total: total ?? this.total,
        actionStatus: actionStatus ?? this.actionStatus,
        filterTypeId:
            filterTypeId == _sentinel ? this.filterTypeId : filterTypeId as int?,
        filterQualityId:
            filterQualityId == _sentinel ? this.filterQualityId : filterQualityId as int?,
        filterColorId:
            filterColorId == _sentinel ? this.filterColorId : filterColorId as int?,
        filterStatus:
            filterStatus == _sentinel ? this.filterStatus : filterStatus as String?,
      );

  @override
  List<Object?> get props =>
      [products, hasNextPage, isLoadingMore, currentPage, total, filterTypeId, filterQualityId, filterColorId, filterStatus, actionStatus];
}

const _sentinel = Object();

class ProductsError extends ProductsState {
  final String message;

  const ProductsError(this.message);

  @override
  List<Object?> get props => [message];
}
