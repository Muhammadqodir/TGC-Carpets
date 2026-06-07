import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../products/domain/entities/product_edge_entity.dart';
import '../repositories/product_attributes_repository.dart';

class CreateProductEdgeUseCase {
  final ProductAttributesRepository _repository;
  const CreateProductEdgeUseCase(this._repository);
  Future<Either<Failure, ProductEdgeEntity>> call({required String code, required String title}) =>
      _repository.createProductEdge(code: code, title: title);
}

class UpdateProductEdgeUseCase {
  final ProductAttributesRepository _repository;
  const UpdateProductEdgeUseCase(this._repository);
  Future<Either<Failure, ProductEdgeEntity>> call({required int id, required String code, required String title}) =>
      _repository.updateProductEdge(id: id, code: code, title: title);
}

class DeleteProductEdgeUseCase {
  final ProductAttributesRepository _repository;
  const DeleteProductEdgeUseCase(this._repository);
  Future<Either<Failure, void>> call({required int id, int? replaceWithId}) =>
      _repository.deleteProductEdge(id: id, replaceWithId: replaceWithId);
}
