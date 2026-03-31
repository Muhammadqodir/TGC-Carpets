import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/client_entity.dart';
import '../repositories/client_repository.dart';

class GetClientsUseCase {
  final ClientRepository _repository;

  const GetClientsUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<ClientEntity>>> call({
    String? search,
    String? region,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getClients(
        search: search,
        region: region,
        page: page,
        perPage: perPage,
      );
}
