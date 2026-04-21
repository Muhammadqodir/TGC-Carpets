import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/raw_material_entity.dart';
import '../repositories/raw_material_repository.dart';

class CreateRawMaterialUseCase {
  final RawMaterialRepository repository;

  const CreateRawMaterialUseCase(this.repository);

  Future<Either<Failure, RawMaterialEntity>> call({
    required String name,
    required String type,
    required String unit,
  }) =>
      repository.createMaterial(name: name, type: type, unit: unit);
}
