import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/warehouse_import_entities.dart';
import '../repositories/warehouse_repository.dart';

class GetImportClientsUseCase {
  final WarehouseRepository repository;
  const GetImportClientsUseCase(this.repository);

  Future<Either<Failure, List<ImportClientEntity>>> call() =>
      repository.getImportClients();
}
