import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/machine_entity.dart';
import '../repositories/production_repository.dart';

class GetMachinesUseCase {
  final ProductionRepository repository;

  GetMachinesUseCase(this.repository);

  Future<Either<Failure, PaginatedResponse<MachineEntity>>> call({
    String? search,
    int page = 1,
    int perPage = 50,
  }) {
    return repository.getMachines(
      search: search,
      page: page,
      perPage: perPage,
    );
  }
}
