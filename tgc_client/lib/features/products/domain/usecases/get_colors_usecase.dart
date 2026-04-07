import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/color_entity.dart';
import '../repositories/product_repository.dart';

class GetColorsUseCase {
  final ProductRepository _repository;

  const GetColorsUseCase(this._repository);

  Future<Either<Failure, List<ColorEntity>>> call() =>
      _repository.getColors();
}
