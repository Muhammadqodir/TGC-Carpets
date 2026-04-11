import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/production_batch_entity.dart';

abstract class ProductionBatchesState extends Equatable {
  const ProductionBatchesState();

  @override
  List<Object?> get props => [];
}

class ProductionBatchesInitial extends ProductionBatchesState {
  const ProductionBatchesInitial();
}

class ProductionBatchesLoading extends ProductionBatchesState {
  const ProductionBatchesLoading();
}

class ProductionBatchesLoaded extends ProductionBatchesState {
  final List<ProductionBatchEntity> batches;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;
  final String? activeStatusFilter;
  final int? activeMachineIdFilter;
  final DateTimeRange? activeDateRange;

  const ProductionBatchesLoaded({
    required this.batches,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeStatusFilter,
    this.activeMachineIdFilter,
    this.activeDateRange,
  });

  ProductionBatchesLoaded copyWith({
    List<ProductionBatchEntity>? batches,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    String? activeStatusFilter,
    int? activeMachineIdFilter,
    DateTimeRange? activeDateRange,
    bool clearStatusFilter = false,
    bool clearMachineIdFilter = false,
    bool clearDateRange = false,
  }) =>
      ProductionBatchesLoaded(
        batches: batches ?? this.batches,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        activeStatusFilter: clearStatusFilter
            ? null
            : (activeStatusFilter ?? this.activeStatusFilter),
        activeMachineIdFilter: clearMachineIdFilter
            ? null
            : (activeMachineIdFilter ?? this.activeMachineIdFilter),
        activeDateRange: clearDateRange
            ? null
            : (activeDateRange ?? this.activeDateRange),
      );

  @override
  List<Object?> get props => [
        batches,
        hasNextPage,
        isLoadingMore,
        currentPage,
        activeStatusFilter,
        activeMachineIdFilter,
        activeDateRange,
      ];
}

class ProductionBatchesError extends ProductionBatchesState {
  final String message;

  const ProductionBatchesError(this.message);

  @override
  List<Object?> get props => [message];
}
