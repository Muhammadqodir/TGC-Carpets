import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class ShipmentsEvent extends Equatable {
  const ShipmentsEvent();

  @override
  List<Object?> get props => [];
}

class ShipmentsLoadRequested extends ShipmentsEvent {
  const ShipmentsLoadRequested();
}

class ShipmentsRefreshRequested extends ShipmentsEvent {
  const ShipmentsRefreshRequested();
}

class ShipmentsFiltersChanged extends ShipmentsEvent {
  final int? clientId;
  final DateTimeRange? dateRange;

  const ShipmentsFiltersChanged({
    this.clientId,
    this.dateRange,
  });

  @override
  List<Object?> get props => [clientId, dateRange];
}

class ShipmentsNextPageRequested extends ShipmentsEvent {
  const ShipmentsNextPageRequested();
}
