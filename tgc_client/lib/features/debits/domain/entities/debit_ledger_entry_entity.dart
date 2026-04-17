import 'package:equatable/equatable.dart';

/// A single row in a client's debit/credit ledger.
/// Type is either 'shipment' (debit) or 'payment' (credit).
class DebitLedgerEntryEntity extends Equatable {
  final String type; // 'shipment' | 'payment'
  final DateTime date;
  final String reference;
  final String? notes;
  final double debit;
  final double credit;
  final double runningBalance;
  final int sourceId;

  const DebitLedgerEntryEntity({
    required this.type,
    required this.date,
    required this.reference,
    this.notes,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    required this.sourceId,
  });

  bool get isShipment => type == 'shipment';
  bool get isPayment => type == 'payment';

  @override
  List<Object?> get props => [
        type,
        date,
        reference,
        notes,
        debit,
        credit,
        runningBalance,
        sourceId,
      ];
}
