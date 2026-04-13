import 'package:dartz/dartz.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/core/models/paginated_response.dart';
import '../entities/stock_variant_entity.dart';
import '../repositories/products_stock_repository.dart';

class GetStockVariantsUseCase {
  final ProductsStockRepository _repository;

  const GetStockVariantsUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<StockVariantEntity>>> call({
    int? productTypeId,
    int? productQualityId,
    int? productSizeId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getStockVariants(
        productTypeId:    productTypeId,
        productQualityId: productQualityId,
        productSizeId:    productSizeId,
        search:           search,
        page:             page,
        perPage:          perPage,
      );
}
