import 'package:equatable/equatable.dart';

abstract class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class SalesAnalyticsRequested extends AnalyticsEvent {
  final DateTime from;
  final DateTime to;

  const SalesAnalyticsRequested({required this.from, required this.to});

  @override
  List<Object?> get props => [from, to];
}

class ProductionAnalyticsRequested extends AnalyticsEvent {
  final DateTime from;
  final DateTime to;

  const ProductionAnalyticsRequested({required this.from, required this.to});

  @override
  List<Object?> get props => [from, to];
}

class FinancialAnalyticsRequested extends AnalyticsEvent {
  final DateTime from;
  final DateTime to;

  const FinancialAnalyticsRequested({required this.from, required this.to});

  @override
  List<Object?> get props => [from, to];
}

class ClientAnalyticsRequested extends AnalyticsEvent {
  final DateTime from;
  final DateTime to;
  final int limit;

  const ClientAnalyticsRequested({
    required this.from,
    required this.to,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [from, to, limit];
}
