import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/warehouse_import_entities.dart';
import '../repositories/warehouse_repository.dart';

class GetImportItemsUseCase {
  final WarehouseRepository repository;
  const GetImportItemsUseCase(this.repository);

  Future<Either<Failure, List<ImportItemEntity>>> call({
    required int clientId,
    required String qualityName,
  }) =>
      repository.getImportItems(clientId: clientId, qualityName: qualityName);
}
