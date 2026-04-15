import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/production_batch_entity.dart';
import '../repositories/production_batch_repository.dart';

class GetProductionBatchUseCase {
  final ProductionBatchRepository _repository;

  const GetProductionBatchUseCase(this._repository);

  Future<Either<Failure, ProductionBatchEntity>> call(
    int id, {
    bool excludeWarehouseReceived = false,
  }) =>
      _repository.getProductionBatch(
        id,
        excludeWarehouseReceived: excludeWarehouseReceived,
      );
}
