import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class WarehouseDocsEvent extends Equatable {
  const WarehouseDocsEvent();

  @override
  List<Object?> get props => [];
}

class WarehouseDocsLoadRequested extends WarehouseDocsEvent {
  const WarehouseDocsLoadRequested();
}

class WarehouseDocsFiltersChanged extends WarehouseDocsEvent {
  final String? type;
  final int? userId;
  final DateTimeRange? dateRange;

  const WarehouseDocsFiltersChanged({
    this.type,
    this.userId,
    this.dateRange,
  });

  @override
  List<Object?> get props => [type, userId, dateRange];
}

class WarehouseDocsTypeFilterChanged extends WarehouseDocsEvent {
  final String? type; // null = all

  const WarehouseDocsTypeFilterChanged(this.type);

  @override
  List<Object?> get props => [type];
}

class WarehouseDocsNextPageRequested extends WarehouseDocsEvent {
  const WarehouseDocsNextPageRequested();
}

class WarehouseDocsRefreshRequested extends WarehouseDocsEvent {
  const WarehouseDocsRefreshRequested();
}
