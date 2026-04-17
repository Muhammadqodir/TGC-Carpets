import 'package:equatable/equatable.dart';

abstract class DebitLedgerEvent extends Equatable {
  const DebitLedgerEvent();

  @override
  List<Object?> get props => [];
}

class DebitLedgerLoadRequested extends DebitLedgerEvent {
  final int clientId;

  const DebitLedgerLoadRequested(this.clientId);

  @override
  List<Object?> get props => [clientId];
}

class DebitLedgerRefreshRequested extends DebitLedgerEvent {
  final int clientId;

  const DebitLedgerRefreshRequested(this.clientId);

  @override
  List<Object?> get props => [clientId];
}
