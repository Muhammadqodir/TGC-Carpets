import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class GetOrdersUseCase {
  final OrderRepository _repository;

  const GetOrdersUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<OrderEntity>>> call({
    String? status,
    int? clientId,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getOrders(
        status: status,
        clientId: clientId,
        userId: userId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
      );
}
