import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/production_batch_entity.dart';
import '../repositories/production_repository.dart';

class CreateProductionBatchUseCase {
  final ProductionRepository repository;

  CreateProductionBatchUseCase(this.repository);

  Future<Either<Failure, ProductionBatchEntity>> call({
    required String batchTitle,
    required int machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  }) {
    return repository.createProductionBatch(
      batchTitle: batchTitle,
      machineId: machineId,
      plannedDatetime: plannedDatetime,
      type: type,
      notes: notes,
      items: items,
    );
  }
}
