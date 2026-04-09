import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/order_entity.dart';

abstract class OrdersState extends Equatable {
  const OrdersState();

  @override
  List<Object?> get props => [];
}

class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersLoaded extends OrdersState {
  final List<OrderEntity> orders;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;
  final String? activeStatusFilter;
  final int? activeClientIdFilter;
  final DateTimeRange? activeDateRange;

  const OrdersLoaded({
    required this.orders,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeStatusFilter,
    this.activeClientIdFilter,
    this.activeDateRange,
  });

  OrdersLoaded copyWith({
    List<OrderEntity>? orders,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    String? activeStatusFilter,
    int? activeClientIdFilter,
    DateTimeRange? activeDateRange,
    bool clearStatusFilter = false,
    bool clearClientIdFilter = false,
    bool clearDateRange = false,
  }) =>
      OrdersLoaded(
        orders: orders ?? this.orders,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        activeStatusFilter:
            clearStatusFilter ? null : (activeStatusFilter ?? this.activeStatusFilter),
        activeClientIdFilter:
            clearClientIdFilter ? null : (activeClientIdFilter ?? this.activeClientIdFilter),
        activeDateRange:
            clearDateRange ? null : (activeDateRange ?? this.activeDateRange),
      );

  @override
  List<Object?> get props => [
        orders,
        hasNextPage,
        isLoadingMore,
        currentPage,
        activeStatusFilter,
        activeClientIdFilter,
        activeDateRange,
      ];
}

class OrdersError extends OrdersState {
  final String message;

  const OrdersError(this.message);

  @override
  List<Object?> get props => [message];
}
