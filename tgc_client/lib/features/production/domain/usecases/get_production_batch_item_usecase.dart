import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/production_batch_item_entity.dart';
import '../repositories/production_batch_repository.dart';

class GetProductionBatchItemUseCase {
  final ProductionBatchRepository _repository;

  const GetProductionBatchItemUseCase(this._repository);

  Future<Either<Failure, ProductionBatchItemEntity>> call(
    int batchId,
    int itemId,
  ) =>
      _repository.getProductionBatchItem(batchId, itemId);
}
