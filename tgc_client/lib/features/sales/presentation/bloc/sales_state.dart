import 'package:equatable/equatable.dart';
import '../../domain/entities/sale_entity.dart';

abstract class SalesState extends Equatable {
  const SalesState();

  @override
  List<Object?> get props => [];
}

class SalesInitial extends SalesState {
  const SalesInitial();
}

class SalesLoading extends SalesState {
  const SalesLoading();
}

class SalesLoaded extends SalesState {
  final List<SaleEntity> sales;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;
  final String? activeFilter;

  const SalesLoaded({
    required this.sales,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeFilter,
  });

  SalesLoaded copyWith({
    List<SaleEntity>? sales,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    String? activeFilter,
    bool clearFilter = false,
  }) =>
      SalesLoaded(
        sales: sales ?? this.sales,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
      );

  @override
  List<Object?> get props => [
        sales,
        hasNextPage,
        isLoadingMore,
        currentPage,
        activeFilter,
      ];
}

class SalesError extends SalesState {
  final String message;

  const SalesError(this.message);

  @override
  List<Object?> get props => [message];
}
