import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../repositories/product_attributes_repository.dart';

class CreateProductSizeUseCase {
  final ProductAttributesRepository _repository;
  const CreateProductSizeUseCase(this._repository);
  Future<Either<Failure, ProductSizeEntity>> call({required int length, required int width, required int productTypeId}) =>
      _repository.createProductSize(length: length, width: width, productTypeId: productTypeId);
}

class UpdateProductSizeUseCase {
  final ProductAttributesRepository _repository;
  const UpdateProductSizeUseCase(this._repository);
  Future<Either<Failure, ProductSizeEntity>> call({required int id, required int length, required int width, required int productTypeId}) =>
      _repository.updateProductSize(id: id, length: length, width: width, productTypeId: productTypeId);
}

class DeleteProductSizeUseCase {
  final ProductAttributesRepository _repository;
  const DeleteProductSizeUseCase(this._repository);
  Future<Either<Failure, void>> call({required int id, int? replaceWithId}) =>
      _repository.deleteProductSize(id: id, replaceWithId: replaceWithId);
}
