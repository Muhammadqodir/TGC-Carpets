import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/color_entity.dart';
import '../entities/product_color_entity.dart';
import '../entities/product_entity.dart';
import '../entities/product_quality_entity.dart';
import '../entities/product_size_entity.dart';
import '../entities/product_type_entity.dart';

abstract class ProductRepository {
  Future<Either<Failure, PaginatedResponse<ProductEntity>>> getProducts({
    String? search,
    String? status,
    int? productTypeId,
    int? productQualityId,
    int? colorId,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, ProductEntity>> getProduct(int id);

  Future<Either<Failure, List<ProductTypeEntity>>> getProductTypes();

  Future<Either<Failure, List<ProductQualityEntity>>> getProductQualities();

  Future<Either<Failure, List<ProductSizeEntity>>> getProductSizes({int? productTypeId});

  Future<Either<Failure, ProductEntity>> createProduct({
    required String name,
    int? productTypeId,
    int? productQualityId,
    required String unit,
    String status = 'active',
  });

  Future<Either<Failure, ProductEntity>> updateProduct({
    required int id,
    String? name,
    int? productTypeId,
    int? productQualityId,
    String? unit,
    String? status,
  });

  Future<Either<Failure, void>> deleteProduct({required int id});

  Future<Either<Failure, ProductColorEntity>> createProductColor({
    required int productId,
    required int colorId,
    String? imagePath,
  });

  Future<Either<Failure, ProductColorEntity>> updateProductColor({
    required int productColorId,
    int? colorId,
    String? imagePath,
  });

  Future<Either<Failure, void>> deleteProductColor({required int productColorId});

  Future<Either<Failure, List<ColorEntity>>> getColors();
}
