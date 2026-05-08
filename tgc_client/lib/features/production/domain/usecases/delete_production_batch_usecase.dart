import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/production_batch_repository.dart';

class DeleteProductionBatchUseCase {
  final ProductionBatchRepository _repository;

  const DeleteProductionBatchUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) =>
      _repository.deleteProductionBatch(id);
}
