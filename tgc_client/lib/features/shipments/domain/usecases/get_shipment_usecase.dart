import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/shipment_entity.dart';
import '../repositories/shipment_repository.dart';

class GetShipmentUseCase {
  final ShipmentRepository _repository;

  const GetShipmentUseCase(this._repository);

  Future<Either<Failure, ShipmentEntity>> call(int id) =>
      _repository.getShipment(id);
}
