import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

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
  final int? activeUserIdFilter;
  final DateTimeRange? activeDateRange;

  const WarehouseDocsLoaded({
    required this.documents,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeTypeFilter,
    this.activeUserIdFilter,
    this.activeDateRange,
  });

  WarehouseDocsLoaded copyWith({
    List<WarehouseDocumentEntity>? documents,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    String? activeTypeFilter,
    int? activeUserIdFilter,
    DateTimeRange? activeDateRange,
    bool clearTypeFilter = false,
    bool clearUserIdFilter = false,
    bool clearDateRange = false,
  }) =>
      WarehouseDocsLoaded(
        documents: documents ?? this.documents,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        activeTypeFilter:
            clearTypeFilter ? null : (activeTypeFilter ?? this.activeTypeFilter),
        activeUserIdFilter: clearUserIdFilter
            ? null
            : (activeUserIdFilter ?? this.activeUserIdFilter),
        activeDateRange: clearDateRange
            ? null
            : (activeDateRange ?? this.activeDateRange),
      );

  @override
  List<Object?> get props => [
        documents,
        hasNextPage,
        isLoadingMore,
        currentPage,
        activeTypeFilter,
        activeUserIdFilter,
        activeDateRange,
      ];
}

class WarehouseDocsError extends WarehouseDocsState {
  final String message;

  const WarehouseDocsError(this.message);

  @override
  List<Object?> get props => [message];
}
