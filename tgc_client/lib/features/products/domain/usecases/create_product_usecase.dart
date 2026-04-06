import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class CreateProductUseCase {
  final ProductRepository _repository;

  const CreateProductUseCase(this._repository);

  Future<Either<Failure, ProductEntity>> call({
    required String name,
    int? productTypeId,
    int? productQualityId,
    required String color,
    required String unit,
    String status = 'active',
    String? imagePath,
  }) =>
      _repository.createProduct(
        name: name,
        productTypeId: productTypeId,
        productQualityId: productQualityId,
        color: color,
        unit: unit,
        status: status,
        imagePath: imagePath,
      );
}
