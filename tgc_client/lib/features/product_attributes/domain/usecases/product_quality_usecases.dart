import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../products/domain/entities/product_quality_entity.dart';
import '../repositories/product_attributes_repository.dart';

class CreateProductQualityUseCase {
  final ProductAttributesRepository _repository;
  const CreateProductQualityUseCase(this._repository);
  Future<Either<Failure, ProductQualityEntity>> call({required String qualityName, int? density}) =>
      _repository.createProductQuality(qualityName: qualityName, density: density);
}

class UpdateProductQualityUseCase {
  final ProductAttributesRepository _repository;
  const UpdateProductQualityUseCase(this._repository);
  Future<Either<Failure, ProductQualityEntity>> call({required int id, required String qualityName, int? density}) =>
      _repository.updateProductQuality(id: id, qualityName: qualityName, density: density);
}

class DeleteProductQualityUseCase {
  final ProductAttributesRepository _repository;
  const DeleteProductQualityUseCase(this._repository);
  Future<Either<Failure, void>> call({required int id, int? replaceWithId}) =>
      _repository.deleteProductQuality(id: id, replaceWithId: replaceWithId);
}
