import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/shipment_entity.dart';

abstract class ShipmentsState extends Equatable {
  const ShipmentsState();

  @override
  List<Object?> get props => [];
}

class ShipmentsInitial extends ShipmentsState {
  const ShipmentsInitial();
}

class ShipmentsLoading extends ShipmentsState {
  const ShipmentsLoading();
}

class ShipmentsLoaded extends ShipmentsState {
  final List<ShipmentEntity> shipments;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;
  final int? activeClientId;
  final DateTimeRange? activeDateRange;

  const ShipmentsLoaded({
    required this.shipments,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeClientId,
    this.activeDateRange,
  });

  ShipmentsLoaded copyWith({
    List<ShipmentEntity>? shipments,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    int? activeClientId,
    DateTimeRange? activeDateRange,
    bool clearClientId = false,
    bool clearDateRange = false,
  }) =>
      ShipmentsLoaded(
        shipments: shipments ?? this.shipments,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        activeClientId:
            clearClientId ? null : (activeClientId ?? this.activeClientId),
        activeDateRange:
            clearDateRange ? null : (activeDateRange ?? this.activeDateRange),
      );

  @override
  List<Object?> get props => [
        shipments,
        hasNextPage,
        isLoadingMore,
        currentPage,
        activeClientId,
        activeDateRange,
      ];
}

class ShipmentsError extends ShipmentsState {
  final String message;

  const ShipmentsError(this.message);

  @override
  List<Object?> get props => [message];
}
