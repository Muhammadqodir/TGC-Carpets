import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/product_model.dart';
import '../models/product_quality_model.dart';
import '../models/product_type_model.dart';

abstract class ProductRemoteDataSource {
  Future<PaginatedResponse<ProductModel>> getProducts({
    String? search,
    String? color,
    String? status,
    int? productTypeId,
    int? productQualityId,
    int page = 1,
    int perPage = 20,
  });

  Future<ProductModel> getProduct(int id);

  Future<List<ProductTypeModel>> getProductTypes();

  Future<List<ProductQualityModel>> getProductQualities();

  Future<ProductModel> createProduct({
    required String name,
    int? productTypeId,
    int? productQualityId,
    required String color,
    String? edge,
    required String unit,
    String status = 'active',
    String? imagePath,
  });
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio _dio;

  const ProductRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<ProductModel>> getProducts({
    String? search,
    String? color,
    String? status,
    int? productTypeId,
    int? productQualityId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (search != null && search.isNotEmpty) 'search': search,
        if (color != null && color.isNotEmpty) 'color': color,
        if (status != null && status.isNotEmpty) 'status': status,
        if (productTypeId != null) 'product_type_id': productTypeId,
        if (productQualityId != null) 'product_quality_id': productQualityId,
      };

      final response = await _dio.get(
        ApiEndpoints.products,
        queryParameters: queryParams,
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<ProductModel>(
        data: dataList,
        currentPage: meta['current_page'] as int,
        lastPage: meta['last_page'] as int,
        perPage: meta['per_page'] as int,
        total: meta['total'] as int,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductModel> getProduct(int id) async {
    try {
      final response = await _dio.get(ApiEndpoints.productById(id));
      return ProductModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<ProductTypeModel>> getProductTypes() async {
    try {
      final response = await _dio.get(ApiEndpoints.productTypes);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => ProductTypeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<ProductQualityModel>> getProductQualities() async {
    try {
      final response = await _dio.get(ApiEndpoints.productQualities);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => ProductQualityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductModel> createProduct({
    required String name,
    int? productTypeId,
    int? productQualityId,
    required String color,
    String? edge,
    required String unit,
    String status = 'active',
    String? imagePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'name': name,
        if (productTypeId != null) 'product_type_id': productTypeId,
        if (productQualityId != null) 'product_quality_id': productQualityId,
        'color': color,
        if (edge != null && edge.isNotEmpty) 'edge': edge,
        'unit': unit,
        'status': status,
        if (imagePath != null)
          'image': await MultipartFile.fromFile(
            imagePath,
            filename: imagePath.split('/').last,
          ),
      });

      final response = await _dio.post(
        ApiEndpoints.products,
        data: formData,
      );

      return ProductModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Never _handleDioError(DioException e) {
    if (e.response?.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (e.response?.statusCode == 422) {
      final errors = e.response?.data?['errors'] as Map<String, dynamic>?;
      final firstError = errors?.values.first;
      final message = firstError is List
          ? firstError.first as String
          : e.response?.data?['message'] as String? ?? 'Validation error';
      throw ServerException(message: message, statusCode: 422);
    }
    if (e.response != null) {
      final message =
          e.response?.data?['message'] as String? ?? 'Server error';
      throw ServerException(
        message: message,
        statusCode: e.response?.statusCode,
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
        throw const NetworkException(
          'Cannot connect to server. Please check your network.',
        );
      case DioExceptionType.connectionTimeout:
        throw const NetworkException(
          'Connection timed out. The server may be unavailable.',
        );
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw const NetworkException('Request timed out. Please try again.');
      default:
        throw ServerException(
          message: e.message ?? 'Unexpected error',
          statusCode: e.response?.statusCode,
        );
    }
  }
}
