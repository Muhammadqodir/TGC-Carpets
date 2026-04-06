import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_quality_entity.dart';
import '../repositories/product_repository.dart';

class GetProductQualitiesUseCase {
  final ProductRepository _repository;

  const GetProductQualitiesUseCase(this._repository);

  Future<Either<Failure, List<ProductQualityEntity>>> call() =>
      _repository.getProductQualities();
}
