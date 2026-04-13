import 'package:dartz/dartz.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/core/models/paginated_response.dart';
import '../entities/stock_variant_entity.dart';

abstract class ProductsStockRepository {
  Future<Either<Failure, PaginatedResponse<StockVariantEntity>>> getStockVariants({
    int? productTypeId,
    int? productQualityId,
    int? productSizeId,
    String? search,
    int page = 1,
    int perPage = 20,
  });
}
