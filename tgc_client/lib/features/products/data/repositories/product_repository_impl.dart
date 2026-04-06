import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_quality_entity.dart';
import '../../domain/entities/product_type_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  const ProductRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<ProductEntity>>> getProducts({
    String? search,
    String? color,
    String? status,
    int? productTypeId,
    int? productQualityId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getProducts(
        search: search,
        color: color,
        status: status,
        productTypeId: productTypeId,
        productQualityId: productQualityId,
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
  Future<Either<Failure, List<ProductTypeEntity>>> getProductTypes() async {
    try {
      final types = await remoteDataSource.getProductTypes();
      return Right(types);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<ProductQualityEntity>>> getProductQualities() async {
    try {
      final qualities = await remoteDataSource.getProductQualities();
      return Right(qualities);
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
    int? productTypeId,
    int? productQualityId,
    required String color,
    required String unit,
    String status = 'active',
    String? imagePath,
  }) async {
    try {
      final product = await remoteDataSource.createProduct(
        name: name,
        productTypeId: productTypeId,
        productQualityId: productQualityId,
        color: color,
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

  @override
  Future<Either<Failure, ProductEntity>> updateProduct({
    required int id,
    String? name,
    int? productTypeId,
    int? productQualityId,
    String? color,
    String? unit,
    String? status,
    String? imagePath,
  }) async {
    try {
      final product = await remoteDataSource.updateProduct(
        id: id,
        name: name,
        productTypeId: productTypeId,
        productQualityId: productQualityId,
        color: color,
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

  @override
  Future<Either<Failure, void>> deleteProduct({required int id}) async {
    try {
      await remoteDataSource.deleteProduct(id: id);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
