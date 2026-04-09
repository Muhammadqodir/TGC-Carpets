import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => [];
}

class OrdersLoadRequested extends OrdersEvent {
  const OrdersLoadRequested();
}

class OrdersRefreshRequested extends OrdersEvent {
  const OrdersRefreshRequested();
}

class OrdersFiltersChanged extends OrdersEvent {
  final String? status;
  final int? clientId;
  final DateTimeRange? dateRange;

  const OrdersFiltersChanged({
    this.status,
    this.clientId,
    this.dateRange,
  });

  @override
  List<Object?> get props => [status, clientId, dateRange];
}

class OrdersStatusFilterChanged extends OrdersEvent {
  final String? status; // null = all

  const OrdersStatusFilterChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class OrdersNextPageRequested extends OrdersEvent {
  const OrdersNextPageRequested();
}

class OrderDeleted extends OrdersEvent {
  final int orderId;

  const OrderDeleted(this.orderId);

  @override
  List<Object?> get props => [orderId];
}
