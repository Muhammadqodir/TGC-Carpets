import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

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
  final int? machineId;
  final DateTimeRange? dateRange;

  const ProductionBatchesFiltersChanged({
    this.status,
    this.machineId,
    this.dateRange,
  });

  @override
  List<Object?> get props => [status, machineId, dateRange];
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

class ProductionBatchDeleted extends ProductionBatchesEvent {
  final int batchId;

  const ProductionBatchDeleted(this.batchId);

  @override
  List<Object?> get props => [batchId];
}
