import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/import_product_item.dart';
import '../entities/import_summary_entity.dart' show ImportItemResultEntity;
import '../repositories/product_repository.dart';

class ImportProductsUseCase {
  final ProductRepository _repository;

  const ImportProductsUseCase(this._repository);

  Future<Either<Failure, ImportItemResultEntity>> call({
    int? productQualityId,
    int? productTypeId,
    required ImportProductItem item,
  }) =>
      _repository.importProduct(
        productQualityId: productQualityId,
        productTypeId: productTypeId,
        item: item,
      );
}
