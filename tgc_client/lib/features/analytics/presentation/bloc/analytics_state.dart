import 'package:equatable/equatable.dart';
import 'package:tgc_client/features/analytics/domain/entities/client_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/entities/financial_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/entities/production_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/entities/sales_analytics_entity.dart';

abstract class AnalyticsState extends Equatable {
  const AnalyticsState();

  @override
  List<Object?> get props => [];
}

class AnalyticsInitial extends AnalyticsState {}

class AnalyticsLoading extends AnalyticsState {}

class SalesAnalyticsLoaded extends AnalyticsState {
  final SalesAnalyticsEntity data;
  final DateTime from;
  final DateTime to;

  const SalesAnalyticsLoaded({
    required this.data,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [data, from, to];
}

class ProductionAnalyticsLoaded extends AnalyticsState {
  final ProductionAnalyticsEntity data;
  final DateTime from;
  final DateTime to;

  const ProductionAnalyticsLoaded({
    required this.data,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [data, from, to];
}

class FinancialAnalyticsLoaded extends AnalyticsState {
  final FinancialAnalyticsEntity data;
  final DateTime from;
  final DateTime to;

  const FinancialAnalyticsLoaded({
    required this.data,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [data, from, to];
}

class ClientAnalyticsLoaded extends AnalyticsState {
  final ClientAnalyticsEntity data;
  final DateTime from;
  final DateTime to;

  const ClientAnalyticsLoaded({
    required this.data,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [data, from, to];
}

class AnalyticsError extends AnalyticsState {
  final String message;

  const AnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
