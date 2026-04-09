import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class UpdateOrderUseCase {
  final OrderRepository _repository;

  const UpdateOrderUseCase(this._repository);

  Future<Either<Failure, OrderEntity>> call(
    int id, {
    String? status,
    String? orderDate,
    List<Map<String, dynamic>>? items,
    int? clientId,
    String? notes,
  }) =>
      _repository.updateOrder(
        id,
        status: status,
        orderDate: orderDate,
        items: items,
        clientId: clientId,
        notes: notes,
      );
}
