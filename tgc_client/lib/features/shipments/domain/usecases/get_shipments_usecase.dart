import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/shipment_entity.dart';
import '../repositories/shipment_repository.dart';

class GetShipmentsUseCase {
  final ShipmentRepository _repository;

  const GetShipmentsUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<ShipmentEntity>>> call({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getShipments(
        clientId: clientId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
      );
}
