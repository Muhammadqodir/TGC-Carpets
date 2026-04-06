import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class UpdateProductUseCase {
  final ProductRepository _repository;

  const UpdateProductUseCase(this._repository);

  Future<Either<Failure, ProductEntity>> call({
    required int id,
    String? name,
    int? productTypeId,
    int? productQualityId,
    String? color,
    String? unit,
    String? status,
    String? imagePath,
  }) =>
      _repository.updateProduct(
        id: id,
        name: name,
        productTypeId: productTypeId,
        productQualityId: productQualityId,
        color: color,
        unit: unit,
        status: status,
        imagePath: imagePath,
      );
}
