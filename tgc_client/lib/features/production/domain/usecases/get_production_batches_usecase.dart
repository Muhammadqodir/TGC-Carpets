import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/production_batch_entity.dart';
import '../repositories/production_batch_repository.dart';

class GetProductionBatchesUseCase {
  final ProductionBatchRepository _repository;

  const GetProductionBatchesUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<ProductionBatchEntity>>> call({
    String? status,
    String? type,
    int? machineId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getProductionBatches(
        status: status,
        type: type,
        machineId: machineId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
      );
}
