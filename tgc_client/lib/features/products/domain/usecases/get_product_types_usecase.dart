import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_type_entity.dart';
import '../repositories/product_repository.dart';

class GetProductTypesUseCase {
  final ProductRepository _repository;

  const GetProductTypesUseCase(this._repository);

  Future<Either<Failure, List<ProductTypeEntity>>> call() =>
      _repository.getProductTypes();
}
