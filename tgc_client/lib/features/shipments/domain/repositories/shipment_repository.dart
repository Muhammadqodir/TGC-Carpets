import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/shipment_entity.dart';

abstract class ShipmentRepository {
  Future<Either<Failure, PaginatedResponse<ShipmentEntity>>> getShipments({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });
}
