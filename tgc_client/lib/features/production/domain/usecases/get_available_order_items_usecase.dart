import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/available_order_item_entity.dart';
import '../repositories/production_repository.dart';

class GetAvailableOrderItemsUseCase {
  final ProductionRepository repository;

  GetAvailableOrderItemsUseCase(this.repository);

  Future<Either<Failure, List<AvailableOrderItemEntity>>> call() {
    return repository.getAvailableOrderItems();
  }
}
