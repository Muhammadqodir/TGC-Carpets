import 'package:dio/dio.dart';
import 'package:tgc_client/core/constants/api_endpoints.dart';
import 'package:tgc_client/core/error/exceptions.dart';
import 'package:tgc_client/core/models/paginated_response.dart';
import '../models/stock_variant_model.dart';

abstract class ProductsStockRemoteDataSource {
  Future<PaginatedResponse<StockVariantModel>> getStockVariants({
    int? productTypeId,
    int? productQualityId,
    int? productSizeId,
    String? search,
    int page = 1,
    int perPage = 20,
  });
}

class ProductsStockRemoteDataSourceImpl implements ProductsStockRemoteDataSource {
  final Dio _dio;

  const ProductsStockRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<StockVariantModel>> getStockVariants({
    int? productTypeId,
    int? productQualityId,
    int? productSizeId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.stockVariants,
        queryParameters: {
          'page':     page,
          'per_page': perPage,
          if (productTypeId != null)                 'product_type_id': productTypeId,
          if (productQualityId != null)              'product_quality_id': productQualityId,
          if (productSizeId != null)                 'product_size_id': productSizeId,
          if (search != null && search.isNotEmpty)   'search': search,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => StockVariantModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<StockVariantModel>(
        data:        dataList,
        currentPage: meta['current_page'] as int,
        lastPage:    meta['last_page'] as int,
        perPage:     meta['per_page'] as int,
        total:       meta['total'] as int,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const UnauthorizedException();
      throw ServerException(
        message:    e.response?.data?['message'] as String? ?? e.message ?? 'Server xatosi',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }
}
