import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class CreateProductUseCase {
  final ProductRepository _repository;

  const CreateProductUseCase(this._repository);

  Future<Either<Failure, ProductEntity>> call({
    required String name,
    required int length,
    required int width,
    required String quality,
    required int density,
    required String color,
    String? edge,
    required String unit,
    String status = 'active',
    String? imagePath,
  }) =>
      _repository.createProduct(
        name: name,
        length: length,
        width: width,
        quality: quality,
        density: density,
        color: color,
        edge: edge,
        unit: unit,
        status: status,
        imagePath: imagePath,
      );
}
