import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_size_entity.dart';
import '../repositories/product_repository.dart';

class GetProductSizesUseCase {
  final ProductRepository _repository;

  const GetProductSizesUseCase(this._repository);

  Future<Either<Failure, List<ProductSizeEntity>>> call({int? productTypeId}) =>
      _repository.getProductSizes(productTypeId: productTypeId);
}
