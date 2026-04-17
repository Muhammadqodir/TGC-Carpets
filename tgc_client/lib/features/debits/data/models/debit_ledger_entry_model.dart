import '../../domain/entities/debit_ledger_entry_entity.dart';

class DebitLedgerEntryModel extends DebitLedgerEntryEntity {
  const DebitLedgerEntryModel({
    required super.type,
    required super.date,
    required super.reference,
    super.notes,
    required super.debit,
    required super.credit,
    required super.runningBalance,
    required super.sourceId,
  });

  factory DebitLedgerEntryModel.fromJson(Map<String, dynamic> json) =>
      DebitLedgerEntryModel(
        type:           json['type'] as String,
        date:           DateTime.parse(json['date'] as String),
        reference:      json['reference'] as String,
        notes:          json['notes'] as String?,
        debit:          (json['debit'] as num).toDouble(),
        credit:         (json['credit'] as num).toDouble(),
        runningBalance: (json['running_balance'] as num).toDouble(),
        sourceId:       json['source_id'] as int,
      );
}
