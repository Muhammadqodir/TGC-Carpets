import 'package:equatable/equatable.dart';

import '../../domain/entities/warehouse_document_entity.dart';

abstract class WarehouseDocsState extends Equatable {
  const WarehouseDocsState();

  @override
  List<Object?> get props => [];
}

class WarehouseDocsInitial extends WarehouseDocsState {
  const WarehouseDocsInitial();
}

class WarehouseDocsLoading extends WarehouseDocsState {
  const WarehouseDocsLoading();
}

class WarehouseDocsLoaded extends WarehouseDocsState {
  final List<WarehouseDocumentEntity> documents;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;
  final String? activeTypeFilter;

  const WarehouseDocsLoaded({
    required this.documents,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeTypeFilter,
  });

  WarehouseDocsLoaded copyWith({
    List<WarehouseDocumentEntity>? documents,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    String? activeTypeFilter,
    bool clearTypeFilter = false,
  }) =>
      WarehouseDocsLoaded(
        documents: documents ?? this.documents,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        activeTypeFilter:
            clearTypeFilter ? null : (activeTypeFilter ?? this.activeTypeFilter),
      );

  @override
  List<Object?> get props =>
      [documents, hasNextPage, isLoadingMore, currentPage, activeTypeFilter];
}

class WarehouseDocsError extends WarehouseDocsState {
  final String message;

  const WarehouseDocsError(this.message);

  @override
  List<Object?> get props => [message];
}
