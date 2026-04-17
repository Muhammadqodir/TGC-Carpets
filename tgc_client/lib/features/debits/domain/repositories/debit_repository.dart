import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/client_debit_entity.dart';
import '../entities/debit_ledger_summary.dart';

abstract class DebitRepository {
  Future<Either<Failure, PaginatedResponse<ClientDebitEntity>>> getClientDebits({
    String? search,
    String? region,
    bool hasBalance = false,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, DebitLedgerSummary>> getClientDebitLedger(int clientId);
}
