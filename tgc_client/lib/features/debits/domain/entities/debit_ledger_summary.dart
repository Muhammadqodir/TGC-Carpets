import 'package:equatable/equatable.dart';

import '../entities/client_debit_entity.dart';
import '../entities/debit_ledger_entry_entity.dart';

class DebitLedgerSummary extends Equatable {
  final ClientDebitEntity client;
  final double totalDebit;
  final double totalCredit;
  final double balance;
  final List<DebitLedgerEntryEntity> entries;

  const DebitLedgerSummary({
    required this.client,
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
    required this.entries,
  });

  @override
  List<Object?> get props => [client, totalDebit, totalCredit, balance, entries];
}
