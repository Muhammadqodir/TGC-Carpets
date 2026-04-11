import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/production_batch_entity.dart';
import '../repositories/production_batch_repository.dart';

class CreateProductionBatchUseCase {
  final ProductionBatchRepository _repository;

  const CreateProductionBatchUseCase(this._repository);

  Future<Either<Failure, ProductionBatchEntity>> call({
    required String batchTitle,
    required int machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  }) =>
      _repository.createProductionBatch(
        batchTitle:      batchTitle,
        machineId:       machineId,
        plannedDatetime: plannedDatetime,
        type:            type,
        notes:           notes,
        items:           items,
      );
}
