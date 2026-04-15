import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class PaymentsEvent extends Equatable {
  const PaymentsEvent();

  @override
  List<Object?> get props => [];
}

class PaymentsLoadRequested extends PaymentsEvent {
  const PaymentsLoadRequested();
}

class PaymentsRefreshRequested extends PaymentsEvent {
  const PaymentsRefreshRequested();
}

class PaymentsFiltersChanged extends PaymentsEvent {
  final int? clientId;
  final DateTimeRange? dateRange;

  const PaymentsFiltersChanged({this.clientId, this.dateRange});

  @override
  List<Object?> get props => [clientId, dateRange];
}

class PaymentsNextPageRequested extends PaymentsEvent {
  const PaymentsNextPageRequested();
}

class PaymentDeleted extends PaymentsEvent {
  final int id;
  const PaymentDeleted(this.id);

  @override
  List<Object?> get props => [id];
}
