import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/shipment_import_entities.dart';
import '../repositories/shipment_repository.dart';

class GetShipmentImportQualitiesUseCase {
  final ShipmentRepository repository;
  const GetShipmentImportQualitiesUseCase(this.repository);

  Future<Either<Failure, List<ShipmentImportQualityEntity>>> call({
    required int clientId,
  }) =>
      repository.getShipmentImportQualities(clientId: clientId);
}
