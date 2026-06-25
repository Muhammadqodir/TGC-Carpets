import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/warehouse_import_entities.dart';
import '../repositories/warehouse_repository.dart';

class GetImportQualitiesUseCase {
  final WarehouseRepository repository;
  const GetImportQualitiesUseCase(this.repository);

  Future<Either<Failure, List<ImportQualityEntity>>> call({
    required int clientId,
  }) =>
      repository.getImportQualities(clientId: clientId);
}
