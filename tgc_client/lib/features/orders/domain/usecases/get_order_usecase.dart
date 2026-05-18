import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class GetOrderUseCase {
  final OrderRepository _repository;

  const GetOrderUseCase(this._repository);

  Future<Either<Failure, OrderEntity>> call(int id) =>
      _repository.getOrder(id);
}
