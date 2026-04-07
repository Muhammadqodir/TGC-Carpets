import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/product_repository.dart';

class DeleteProductColorUseCase {
  final ProductRepository _repository;

  const DeleteProductColorUseCase(this._repository);

  Future<Either<Failure, void>> call({required int productColorId}) =>
      _repository.deleteProductColor(productColorId: productColorId);
}
