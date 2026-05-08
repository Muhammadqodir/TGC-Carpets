import 'package:equatable/equatable.dart';

abstract class ProductionBatchesEvent extends Equatable {
  const ProductionBatchesEvent();

  @override
  List<Object?> get props => [];
}

class ProductionBatchesLoadRequested extends ProductionBatchesEvent {
  const ProductionBatchesLoadRequested();
}

class ProductionBatchesRefreshRequested extends ProductionBatchesEvent {
  const ProductionBatchesRefreshRequested();
}

class ProductionBatchesFiltersChanged extends ProductionBatchesEvent {
  final String? status;
  final String? type;
  final DateTimeRangeSimple? dateRange;

  const ProductionBatchesFiltersChanged({
    this.status,
    this.type,
    this.dateRange,
  });

  @override
  List<Object?> get props => [status, type, dateRange];
}

class ProductionBatchesStatusFilterChanged extends ProductionBatchesEvent {
  final String? status;

  const ProductionBatchesStatusFilterChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class ProductionBatchesNextPageRequested extends ProductionBatchesEvent {
  const ProductionBatchesNextPageRequested();
}

class ProductionBatchDeleteRequested extends ProductionBatchesEvent {
  final int batchId;
  final String batchTitle;

  const ProductionBatchDeleteRequested({
    required this.batchId,
    required this.batchTitle,
  });

  @override
  List<Object?> get props => [batchId, batchTitle];
}

/// Simple value class to carry a date range without depending on Flutter's
/// [DateTimeRange] from the event layer (avoids importing material.dart here).
class DateTimeRangeSimple extends Equatable {
  final DateTime start;
  final DateTime end;

  const DateTimeRangeSimple({required this.start, required this.end});

  @override
  List<Object?> get props => [start, end];
}
