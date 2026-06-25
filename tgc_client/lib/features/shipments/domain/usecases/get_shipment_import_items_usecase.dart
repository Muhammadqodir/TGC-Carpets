import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/shipment_import_entities.dart';
import '../repositories/shipment_repository.dart';

class GetShipmentImportItemsUseCase {
  final ShipmentRepository repository;
  const GetShipmentImportItemsUseCase(this.repository);

  Future<Either<Failure, List<ShipmentImportItemEntity>>> call({
    required int clientId,
    required String qualityName,
  }) =>
      repository.getShipmentImportItems(
        clientId: clientId,
        qualityName: qualityName,
      );
}
