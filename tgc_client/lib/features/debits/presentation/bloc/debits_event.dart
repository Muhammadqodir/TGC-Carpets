import 'package:equatable/equatable.dart';

abstract class DebitsEvent extends Equatable {
  const DebitsEvent();

  @override
  List<Object?> get props => [];
}

class DebitsLoadRequested extends DebitsEvent {
  const DebitsLoadRequested();
}

class DebitsRefreshRequested extends DebitsEvent {
  const DebitsRefreshRequested();
}

class DebitsNextPageRequested extends DebitsEvent {
  const DebitsNextPageRequested();
}

class DebitsFiltersChanged extends DebitsEvent {
  final String? search;
  final String? region;
  final bool hasBalance;

  const DebitsFiltersChanged({
    this.search,
    this.region,
    this.hasBalance = false,
  });

  @override
  List<Object?> get props => [search, region, hasBalance];
}
