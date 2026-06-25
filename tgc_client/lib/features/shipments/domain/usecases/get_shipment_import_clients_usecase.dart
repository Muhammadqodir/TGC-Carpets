import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/shipment_import_entities.dart';
import '../repositories/shipment_repository.dart';

class GetShipmentImportClientsUseCase {
  final ShipmentRepository repository;
  const GetShipmentImportClientsUseCase(this.repository);

  Future<Either<Failure, List<ShipmentImportClientEntity>>> call() =>
      repository.getShipmentImportClients();
}
