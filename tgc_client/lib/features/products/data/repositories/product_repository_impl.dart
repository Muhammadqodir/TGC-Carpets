import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  const ProductRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<ProductEntity>>> getProducts({
    String? search,
    String? quality,
    String? color,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getProducts(
        search: search,
        quality: quality,
        color: color,
        status: status,
        page: page,
        perPage: perPage,
      );
      return Right(
        PaginatedResponse<ProductEntity>(
          data: result.data,
          currentPage: result.currentPage,
          lastPage: result.lastPage,
          perPage: result.perPage,
          total: result.total,
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

  @override
  Future<Either<Failure, ProductEntity>> getProduct(int id) async {
    try {
      final product = await remoteDataSource.getProduct(id);
      return Right(product);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> createProduct({
    required String name,
    required int length,
    required int width,
    required String quality,
    required int density,
    required String color,
    String? edge,
    required String unit,
    String status = 'active',
    String? imagePath,
  }) async {
    try {
      final product = await remoteDataSource.createProduct(
        name: name,
        length: length,
        width: width,
        quality: quality,
        density: density,
        color: color,
        edge: edge,
        unit: unit,
        status: status,
        imagePath: imagePath,
      );
      return Right(product);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
