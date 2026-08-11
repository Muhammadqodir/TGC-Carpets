import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../shipments/domain/entities/shipment_entity.dart';
import '../repositories/shipment_pricing_repository.dart';

class GetShipmentForPricingUseCase {
  final ShipmentPricingRepository _repository;

  const GetShipmentForPricingUseCase(this._repository);

  Future<Either<Failure, ShipmentEntity>> call(int id) =>
      _repository.getShipment(id);
}
