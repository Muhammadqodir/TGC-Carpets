import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/product_entity.dart';

abstract class ProductRepository {
  Future<Either<Failure, PaginatedResponse<ProductEntity>>> getProducts({
    String? search,
    String? quality,
    String? color,
    String? status,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, ProductEntity>> getProduct(int id);

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
  });
}
