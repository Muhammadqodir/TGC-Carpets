import 'package:equatable/equatable.dart';

import '../../domain/entities/debit_ledger_summary.dart';

abstract class DebitLedgerState extends Equatable {
  const DebitLedgerState();

  @override
  List<Object?> get props => [];
}

class DebitLedgerInitial extends DebitLedgerState {
  const DebitLedgerInitial();
}

class DebitLedgerLoading extends DebitLedgerState {
  const DebitLedgerLoading();
}

class DebitLedgerLoaded extends DebitLedgerState {
  final DebitLedgerSummary data;

  const DebitLedgerLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class DebitLedgerError extends DebitLedgerState {
  final String message;

  const DebitLedgerError(this.message);

  @override
  List<Object?> get props => [message];
}
