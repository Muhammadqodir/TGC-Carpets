import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../repositories/shipment_repository.dart';

class GetOrdersForShipmentUseCase {
  final ShipmentRepository _repository;

  const GetOrdersForShipmentUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<OrderEntity>>> call({
    int? clientId,
    int page = 1,
    int perPage = 50,
  }) =>
      _repository.getOrdersForShipment(
        clientId: clientId,
        page: page,
        perPage: perPage,
      );
}
