import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../products/domain/entities/color_entity.dart';
import '../../../products/domain/entities/product_quality_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../../products/domain/entities/product_type_entity.dart';
import '../../domain/repositories/product_attributes_repository.dart';
import '../datasources/product_attributes_remote_datasource.dart';

class ProductAttributesRepositoryImpl implements ProductAttributesRepository {
  final ProductAttributesRemoteDataSource remoteDataSource;

  const ProductAttributesRepositoryImpl({required this.remoteDataSource});

  // ── Helper ─────────────────────────────────────────────────────────────────

  Future<Either<Failure, T>> _execute<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  // ── Colors ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<ColorEntity>>> getColors({String? search}) =>
      _execute(() => remoteDataSource.getColors(search: search));

  @override
  Future<Either<Failure, ColorEntity>> createColor({required String name}) =>
      _execute(() => remoteDataSource.createColor(name: name));

  @override
  Future<Either<Failure, ColorEntity>> updateColor({required int id, required String name}) =>
      _execute(() => remoteDataSource.updateColor(id: id, name: name));

  @override
  Future<Either<Failure, int>> checkColorUsage({required int id}) =>
      _execute(() => remoteDataSource.checkColorUsage(id: id));

  @override
  Future<Either<Failure, void>> deleteColor({required int id, int? replaceWithId}) =>
      _execute(() => remoteDataSource.deleteColor(id: id, replaceWithId: replaceWithId));

  // ── Product Types ──────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<ProductTypeEntity>>> getProductTypes() =>
      _execute(() => remoteDataSource.getProductTypes());

  @override
  Future<Either<Failure, ProductTypeEntity>> createProductType({required String type}) =>
      _execute(() => remoteDataSource.createProductType(type: type));

  @override
  Future<Either<Failure, ProductTypeEntity>> updateProductType({required int id, required String type}) =>
      _execute(() => remoteDataSource.updateProductType(id: id, type: type));

  @override
  Future<Either<Failure, int>> checkProductTypeUsage({required int id}) =>
      _execute(() => remoteDataSource.checkProductTypeUsage(id: id));

  @override
  Future<Either<Failure, void>> deleteProductType({required int id, int? replaceWithId}) =>
      _execute(() => remoteDataSource.deleteProductType(id: id, replaceWithId: replaceWithId));

  // ── Product Qualities ──────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<ProductQualityEntity>>> getProductQualities() =>
      _execute(() => remoteDataSource.getProductQualities());

  @override
  Future<Either<Failure, ProductQualityEntity>> createProductQuality({required String qualityName, int? density}) =>
      _execute(() => remoteDataSource.createProductQuality(qualityName: qualityName, density: density));

  @override
  Future<Either<Failure, ProductQualityEntity>> updateProductQuality({required int id, required String qualityName, int? density}) =>
      _execute(() => remoteDataSource.updateProductQuality(id: id, qualityName: qualityName, density: density));

  @override
  Future<Either<Failure, int>> checkProductQualityUsage({required int id}) =>
      _execute(() => remoteDataSource.checkProductQualityUsage(id: id));

  @override
  Future<Either<Failure, void>> deleteProductQuality({required int id, int? replaceWithId}) =>
      _execute(() => remoteDataSource.deleteProductQuality(id: id, replaceWithId: replaceWithId));

  // ── Product Sizes ──────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<ProductSizeEntity>>> getProductSizes({int? productTypeId}) =>
      _execute(() => remoteDataSource.getProductSizes(productTypeId: productTypeId));

  @override
  Future<Either<Failure, ProductSizeEntity>> createProductSize({required int length, required int width, required int productTypeId}) =>
      _execute(() => remoteDataSource.createProductSize(length: length, width: width, productTypeId: productTypeId));

  @override
  Future<Either<Failure, ProductSizeEntity>> updateProductSize({required int id, required int length, required int width, required int productTypeId}) =>
      _execute(() => remoteDataSource.updateProductSize(id: id, length: length, width: width, productTypeId: productTypeId));

  @override
  Future<Either<Failure, int>> checkProductSizeUsage({required int id}) =>
      _execute(() => remoteDataSource.checkProductSizeUsage(id: id));

  @override
  Future<Either<Failure, void>> deleteProductSize({required int id, int? replaceWithId}) =>
      _execute(() => remoteDataSource.deleteProductSize(id: id, replaceWithId: replaceWithId));
}
