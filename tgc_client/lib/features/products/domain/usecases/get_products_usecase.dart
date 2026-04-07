import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetProductsUseCase {
  final ProductRepository _repository;

  const GetProductsUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<ProductEntity>>> call({
    String? search,
    String? status,
    int? productTypeId,
    int? productQualityId,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getProducts(
        search: search,
        status: status,
        productTypeId: productTypeId,
        productQualityId: productQualityId,
        page: page,
        perPage: perPage,
      );
}
