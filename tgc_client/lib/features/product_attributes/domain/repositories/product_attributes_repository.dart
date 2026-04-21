import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../products/domain/entities/color_entity.dart';
import '../../../products/domain/entities/product_quality_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../../products/domain/entities/product_type_entity.dart';

abstract class ProductAttributesRepository {
  // ── Colors ────────────────────────────────────────────────────────────────
  Future<Either<Failure, List<ColorEntity>>> getColors({String? search});
  Future<Either<Failure, ColorEntity>> createColor({required String name});
  Future<Either<Failure, ColorEntity>> updateColor({required int id, required String name});
  Future<Either<Failure, int>> checkColorUsage({required int id});
  Future<Either<Failure, void>> deleteColor({required int id, int? replaceWithId});

  // ── Product Types ─────────────────────────────────────────────────────────
  Future<Either<Failure, List<ProductTypeEntity>>> getProductTypes();
  Future<Either<Failure, ProductTypeEntity>> createProductType({required String type});
  Future<Either<Failure, ProductTypeEntity>> updateProductType({required int id, required String type});
  Future<Either<Failure, int>> checkProductTypeUsage({required int id});
  Future<Either<Failure, void>> deleteProductType({required int id, int? replaceWithId});

  // ── Product Qualities ─────────────────────────────────────────────────────
  Future<Either<Failure, List<ProductQualityEntity>>> getProductQualities();
  Future<Either<Failure, ProductQualityEntity>> createProductQuality({required String qualityName, int? density});
  Future<Either<Failure, ProductQualityEntity>> updateProductQuality({required int id, required String qualityName, int? density});
  Future<Either<Failure, int>> checkProductQualityUsage({required int id});
  Future<Either<Failure, void>> deleteProductQuality({required int id, int? replaceWithId});

  // ── Product Sizes ─────────────────────────────────────────────────────────
  Future<Either<Failure, List<ProductSizeEntity>>> getProductSizes({int? productTypeId});
  Future<Either<Failure, ProductSizeEntity>> createProductSize({required int length, required int width, required int productTypeId});
  Future<Either<Failure, ProductSizeEntity>> updateProductSize({required int id, required int length, required int width, required int productTypeId});
  Future<Either<Failure, int>> checkProductSizeUsage({required int id});
  Future<Either<Failure, void>> deleteProductSize({required int id, int? replaceWithId});
}
