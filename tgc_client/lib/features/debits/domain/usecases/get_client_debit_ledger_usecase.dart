import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/debit_ledger_summary.dart';
import '../repositories/debit_repository.dart';

class GetClientDebitLedgerUseCase {
  final DebitRepository _repository;

  const GetClientDebitLedgerUseCase(this._repository);

  Future<Either<Failure, DebitLedgerSummary>> call(int clientId) =>
      _repository.getClientDebitLedger(clientId);
}
