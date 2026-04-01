import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class DashboardStatsRequested extends DashboardEvent {
  final DateTime from;
  final DateTime to;

  DashboardStatsRequested({required this.from, required this.to});

  @override
  List<Object?> get props => [from, to];
}
