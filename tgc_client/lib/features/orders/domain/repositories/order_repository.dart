import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/order_entity.dart';

abstract class OrderRepository {
  Future<Either<Failure, PaginatedResponse<OrderEntity>>> getOrders({
    String? status,
    int? clientId,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, OrderEntity>> getOrder(int id);

  Future<Either<Failure, OrderEntity>> createOrder({
    required String orderDate,
    required List<Map<String, dynamic>> items,
    required int clientId,
    String? notes,
    String? externalUuid,
  });

  Future<Either<Failure, OrderEntity>> updateOrder(
    int id, {
    String? status,
    String? orderDate,
    List<Map<String, dynamic>>? items,
    int? clientId,
    String? notes,
  });

  Future<Either<Failure, void>> deleteOrder(int id);
}
