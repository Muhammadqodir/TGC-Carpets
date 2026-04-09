import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class CreateOrderUseCase {
  final OrderRepository _repository;

  const CreateOrderUseCase(this._repository);

  Future<Either<Failure, OrderEntity>> call({
    required String orderDate,
    required List<Map<String, dynamic>> items,
    int? clientId,
    String status = 'pending',
    String? notes,
    String? externalUuid,
  }) =>
      _repository.createOrder(
        orderDate: orderDate,
        items: items,
        clientId: clientId,
        status: status,
        notes: notes,
        externalUuid: externalUuid,
      );
}
