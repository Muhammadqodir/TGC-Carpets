import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_color_entity.dart';
import '../repositories/product_repository.dart';

class UpdateProductColorUseCase {
  final ProductRepository _repository;

  const UpdateProductColorUseCase(this._repository);

  Future<Either<Failure, ProductColorEntity>> call({
    required int productColorId,
    int? colorId,
    String? imagePath,
  }) =>
      _repository.updateProductColor(
        productColorId: productColorId,
        colorId: colorId,
        imagePath: imagePath,
      );
}
