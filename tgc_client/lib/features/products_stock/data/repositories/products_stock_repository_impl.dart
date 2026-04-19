import 'package:dartz/dartz.dart';
import 'package:tgc_client/core/error/exceptions.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/core/models/paginated_response.dart';
import '../../domain/entities/stock_variant_entity.dart';
import '../../domain/repositories/products_stock_repository.dart';
import '../datasources/products_stock_remote_datasource.dart';

class ProductsStockRepositoryImpl implements ProductsStockRepository {
  final ProductsStockRemoteDataSource remoteDataSource;

  const ProductsStockRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<StockVariantEntity>>> getStockVariants({
    int? productTypeId,
    int? productQualityId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await _remoteDataSource.getStockVariants(
        productTypeId:    productTypeId,
        productQualityId: productQualityId,
        search:           search,
        page:             page,
        perPage:          perPage,
      );
      return Right(
        PaginatedResponse<StockVariantEntity>(
          data:        result.data,
          currentPage: result.currentPage,
          lastPage:    result.lastPage,
          perPage:     result.perPage,
          total:       result.total,
        ),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
