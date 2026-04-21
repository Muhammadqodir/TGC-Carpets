import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../products/domain/entities/color_entity.dart';
import '../../../products/domain/entities/product_quality_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../../products/domain/entities/product_type_entity.dart';
import '../repositories/product_attributes_repository.dart';

class LoadProductAttributesUseCase {
  final ProductAttributesRepository _repository;

  const LoadProductAttributesUseCase(this._repository);

  Future<
      (
        Either<Failure, List<ColorEntity>>,
        Either<Failure, List<ProductTypeEntity>>,
        Either<Failure, List<ProductQualityEntity>>,
        Either<Failure, List<ProductSizeEntity>>,
      )> call() async {
    final results = await Future.wait([
      _repository.getColors(),
      _repository.getProductTypes(),
      _repository.getProductQualities(),
      _repository.getProductSizes(),
    ]);

    return (
      results[0] as Either<Failure, List<ColorEntity>>,
      results[1] as Either<Failure, List<ProductTypeEntity>>,
      results[2] as Either<Failure, List<ProductQualityEntity>>,
      results[3] as Either<Failure, List<ProductSizeEntity>>,
    );
  }
}
