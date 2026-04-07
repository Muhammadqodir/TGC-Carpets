import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_color_entity.dart';
import '../repositories/product_repository.dart';

class CreateProductColorUseCase {
  final ProductRepository _repository;

  const CreateProductColorUseCase(this._repository);

  Future<Either<Failure, ProductColorEntity>> call({
    required int productId,
    required int colorId,
    String? imagePath,
  }) =>
      _repository.createProductColor(
        productId: productId,
        colorId: colorId,
        imagePath: imagePath,
      );
}
