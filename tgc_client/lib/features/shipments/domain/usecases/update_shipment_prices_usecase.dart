import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/shipment_entity.dart';
import '../repositories/shipment_repository.dart';

/// Prices an already-created shipment. The server recomputes what the client
/// owes and rebuilds the hisob-faktura, so the returned shipment carries
/// fresh document URLs.
class UpdateShipmentPricesUseCase {
  final ShipmentRepository _repository;

  const UpdateShipmentPricesUseCase(this._repository);

  Future<Either<Failure, ShipmentEntity>> call({
    required int id,
    required List<Map<String, dynamic>> items,
  }) =>
      _repository.updateShipmentPrices(id: id, items: items);
}
