import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/client_debit_entity.dart';
import '../repositories/debit_repository.dart';

class GetClientDebitsUseCase {
  final DebitRepository _repository;

  const GetClientDebitsUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<ClientDebitEntity>>> call({
    String? search,
    String? region,
    bool hasBalance = false,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getClientDebits(
        search: search,
        region: region,
        hasBalance: hasBalance,
        page: page,
        perPage: perPage,
      );
}
