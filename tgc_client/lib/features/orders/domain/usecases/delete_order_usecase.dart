import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/order_repository.dart';

class DeleteOrderUseCase {
  final OrderRepository _repository;

  const DeleteOrderUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) => _repository.deleteOrder(id);
}
