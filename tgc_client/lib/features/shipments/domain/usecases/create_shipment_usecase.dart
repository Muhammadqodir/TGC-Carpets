import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/shipment_entity.dart';
import '../repositories/shipment_repository.dart';

class CreateShipmentUseCase {
  final ShipmentRepository _repository;

  const CreateShipmentUseCase(this._repository);

  Future<Either<Failure, ShipmentEntity>> call({
    required int clientId,
    int? orderId,
    required String shipmentDatetime,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) =>
      _repository.createShipment(
        clientId: clientId,
        orderId: orderId,
        shipmentDatetime: shipmentDatetime,
        notes: notes,
        items: items,
      );
}
