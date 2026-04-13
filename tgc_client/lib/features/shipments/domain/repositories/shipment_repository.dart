import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../entities/shipment_entity.dart';

abstract class ShipmentRepository {
  Future<Either<Failure, PaginatedResponse<ShipmentEntity>>> getShipments({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, ShipmentEntity>> createShipment({
    required int clientId,
    int? orderId,
    required String shipmentDatetime,
    String? notes,
    required List<Map<String, dynamic>> items,
  });

  Future<Either<Failure, PaginatedResponse<OrderEntity>>> getOrdersForShipment({
    int? clientId,
    int page = 1,
    int perPage = 50,
  });

  Future<Either<Failure, double?>> getLastPrice({
    required int variantId,
    required int clientId,
  });
}
