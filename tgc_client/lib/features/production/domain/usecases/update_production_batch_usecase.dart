import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/production_batch_entity.dart';
import '../repositories/production_repository.dart';

class UpdateProductionBatchUseCase {
  final ProductionRepository repository;

  UpdateProductionBatchUseCase(this.repository);

  Future<Either<Failure, ProductionBatchEntity>> call(
    int id, {
    String? batchTitle,
    int? machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  }) {
    return repository.updateProductionBatch(
      id,
      batchTitle: batchTitle,
      machineId: machineId,
      plannedDatetime: plannedDatetime,
      type: type,
      notes: notes,
      items: items,
    );
  }
}
