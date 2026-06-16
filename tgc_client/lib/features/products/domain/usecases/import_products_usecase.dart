import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/import_product_item.dart';
import '../entities/import_summary_entity.dart';
import '../repositories/product_repository.dart';

class ImportProductsUseCase {
  final ProductRepository _repository;

  const ImportProductsUseCase(this._repository);

  Future<Either<Failure, ImportSummaryEntity>> call({
    int? productQualityId,
    int? productTypeId,
    required List<ImportProductItem> items,
  }) =>
      _repository.importProducts(
        productQualityId: productQualityId,
        productTypeId: productTypeId,
        items: items,
      );
}
