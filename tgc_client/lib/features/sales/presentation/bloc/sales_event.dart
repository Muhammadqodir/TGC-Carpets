import 'package:equatable/equatable.dart';

abstract class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

class SalesLoadRequested extends SalesEvent {
  const SalesLoadRequested();
}

class SalesFilterChanged extends SalesEvent {
  final String? paymentStatus;

  const SalesFilterChanged({this.paymentStatus});

  @override
  List<Object?> get props => [paymentStatus];
}

class SalesNextPageRequested extends SalesEvent {
  const SalesNextPageRequested();
}

class SalesRefreshRequested extends SalesEvent {
  const SalesRefreshRequested();
}
