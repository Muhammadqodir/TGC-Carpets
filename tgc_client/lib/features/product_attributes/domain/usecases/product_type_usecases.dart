import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../products/domain/entities/product_type_entity.dart';
import '../repositories/product_attributes_repository.dart';

class CreateProductTypeUseCase {
  final ProductAttributesRepository _repository;
  const CreateProductTypeUseCase(this._repository);
  Future<Either<Failure, ProductTypeEntity>> call({required String type}) =>
      _repository.createProductType(type: type);
}

class UpdateProductTypeUseCase {
  final ProductAttributesRepository _repository;
  const UpdateProductTypeUseCase(this._repository);
  Future<Either<Failure, ProductTypeEntity>> call({required int id, required String type}) =>
      _repository.updateProductType(id: id, type: type);
}

class ArchiveProductTypeUseCase {
  final ProductAttributesRepository _repository;
  const ArchiveProductTypeUseCase(this._repository);
  Future<Either<Failure, ProductTypeEntity>> call({required int id}) =>
      _repository.archiveProductType(id: id);
}

class UnarchiveProductTypeUseCase {
  final ProductAttributesRepository _repository;
  const UnarchiveProductTypeUseCase(this._repository);
  Future<Either<Failure, ProductTypeEntity>> call({required int id}) =>
      _repository.unarchiveProductType(id: id);
}

class DeleteProductTypeUseCase {
  final ProductAttributesRepository _repository;
  const DeleteProductTypeUseCase(this._repository);
  Future<Either<Failure, void>> call({required int id, int? replaceWithId}) =>
      _repository.deleteProductType(id: id, replaceWithId: replaceWithId);
}
