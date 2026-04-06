import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/product_repository.dart';

class DeleteProductUseCase {
  final ProductRepository _repository;

  const DeleteProductUseCase(this._repository);

  Future<Either<Failure, void>> call({required int id}) =>
      _repository.deleteProduct(id: id);
}
