import 'package:equatable/equatable.dart';

import '../../domain/entities/production_batch_entity.dart';
import 'production_batches_event.dart';

// ── Action status for row-level operations (e.g. delete) ─────────────────────

sealed class ProductionBatchActionStatus extends Equatable {
  const ProductionBatchActionStatus();
}

class ProductionBatchActionIdle extends ProductionBatchActionStatus {
  const ProductionBatchActionIdle();
  @override
  List<Object?> get props => [];
}

class ProductionBatchActionPending extends ProductionBatchActionStatus {
  final int batchId;
  const ProductionBatchActionPending(this.batchId);
  @override
  List<Object?> get props => [batchId];
}

class ProductionBatchActionSuccess extends ProductionBatchActionStatus {
  final String message;
  const ProductionBatchActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class ProductionBatchActionFailure extends ProductionBatchActionStatus {
  final String message;
  const ProductionBatchActionFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// ── States ────────────────────────────────────────────────────────────────────

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
  final int total;
  final String? activeStatusFilter;
  final String? activeTypeFilter;
  final DateTimeRangeSimple? activeDateRange;
  final ProductionBatchActionStatus actionStatus;

  const ProductionBatchesLoaded({
    required this.batches,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    required this.total,
    this.activeStatusFilter,
    this.activeTypeFilter,
    this.activeDateRange,
    this.actionStatus = const ProductionBatchActionIdle(),
  });

  ProductionBatchesLoaded copyWith({
    List<ProductionBatchEntity>? batches,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    int? total,
    String? activeStatusFilter,
    String? activeTypeFilter,
    DateTimeRangeSimple? activeDateRange,
    bool clearStatusFilter = false,
    bool clearTypeFilter = false,
    bool clearDateRange = false,
    ProductionBatchActionStatus? actionStatus,
  }) =>
      ProductionBatchesLoaded(
        batches:            batches       ?? this.batches,
        hasNextPage:        hasNextPage   ?? this.hasNextPage,
        isLoadingMore:      isLoadingMore ?? this.isLoadingMore,
        currentPage:        currentPage   ?? this.currentPage,
        total:              total         ?? this.total,
        activeStatusFilter: clearStatusFilter ? null : (activeStatusFilter ?? this.activeStatusFilter),
        activeTypeFilter:   clearTypeFilter   ? null : (activeTypeFilter   ?? this.activeTypeFilter),
        activeDateRange:    clearDateRange     ? null : (activeDateRange    ?? this.activeDateRange),
        actionStatus:       actionStatus  ?? this.actionStatus,
      );

  @override
  List<Object?> get props => [
        batches,
        hasNextPage,
        isLoadingMore,
        currentPage,
        total,
        activeStatusFilter,
        activeTypeFilter,
        activeDateRange,
        actionStatus,
      ];
}

class ProductionBatchesError extends ProductionBatchesState {
  final String message;

  const ProductionBatchesError(this.message);

  @override
  List<Object?> get props => [message];
}
