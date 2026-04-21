import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/raw_material_movement_entity.dart';
import '../repositories/raw_material_repository.dart';

class StoreBatchMovementUseCase {
  final RawMaterialRepository repository;

  const StoreBatchMovementUseCase(this.repository);

  Future<Either<Failure, List<RawMaterialMovementEntity>>> call({
    required String dateTime,
    required String type,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) =>
      repository.storeBatchMovement(
        dateTime: dateTime,
        type: type,
        notes: notes,
        items: items,
      );
}
