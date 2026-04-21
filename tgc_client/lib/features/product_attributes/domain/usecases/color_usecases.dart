import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../products/domain/entities/color_entity.dart';
import '../repositories/product_attributes_repository.dart';

class CreateColorUseCase {
  final ProductAttributesRepository _repository;
  const CreateColorUseCase(this._repository);
  Future<Either<Failure, ColorEntity>> call({required String name}) =>
      _repository.createColor(name: name);
}

class UpdateColorUseCase {
  final ProductAttributesRepository _repository;
  const UpdateColorUseCase(this._repository);
  Future<Either<Failure, ColorEntity>> call({required int id, required String name}) =>
      _repository.updateColor(id: id, name: name);
}

class DeleteColorUseCase {
  final ProductAttributesRepository _repository;
  const DeleteColorUseCase(this._repository);
  Future<Either<Failure, void>> call({required int id, int? replaceWithId}) =>
      _repository.deleteColor(id: id, replaceWithId: replaceWithId);
}
