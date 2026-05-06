import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/color_model.dart';
import '../models/product_color_model.dart';
import '../models/product_model.dart';
import '../models/product_quality_model.dart';
import '../models/product_size_model.dart';
import '../models/product_type_model.dart';

abstract class ProductRemoteDataSource {
  Future<PaginatedResponse<ProductModel>> getProducts({
    String? search,
    String? status,
    int? productTypeId,
    int? productQualityId,
    int? colorId,
    int page = 1,
    int perPage = 50,
  });

  Future<ProductModel> getProduct(int id);

  Future<List<ProductTypeModel>> getProductTypes();

  Future<List<ProductQualityModel>> getProductQualities();

  Future<List<ProductSizeModel>> getProductSizes({int? productTypeId});

  Future<ProductModel> createProduct({
    required String name,
    int? productTypeId,
    int? productQualityId,
    required String unit,
    String status = 'active',
  });

  Future<ProductModel> updateProduct({
    required int id,
    String? name,
    int? productTypeId,
    int? productQualityId,
    String? unit,
    String? status,
  });

  Future<void> deleteProduct({required int id});

  /// Creates a new product-color entry (color + optional image).
  Future<ProductColorModel> createProductColor({
    required int productId,
    required int colorId,
    String? imagePath,
  });

  /// Updates an existing product-color entry.
  Future<ProductColorModel> updateProductColor({
    required int productColorId,
    int? colorId,
    String? imagePath,
  });

  /// Deletes a product-color entry.
  Future<void> deleteProductColor({required int productColorId});

  /// Returns all available colors.
  Future<List<ColorModel>> getColors();
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio _dio;

  const ProductRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<ProductModel>> getProducts({
    String? search,
    String? status,
    int? productTypeId,
    int? productQualityId,
    int? colorId,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        if (productTypeId != null) 'product_type_id': productTypeId,
        if (productQualityId != null) 'product_quality_id': productQualityId,
        if (colorId != null) 'color_id': colorId,
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
        total: (meta['total'] as num?)?.toInt() ?? 0,
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
  Future<List<ProductSizeModel>> getProductSizes({int? productTypeId}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.productSizes,
        queryParameters: {
          if (productTypeId != null) 'product_type_id': productTypeId,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => ProductSizeModel.fromJson(e as Map<String, dynamic>))
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
    required String unit,
    String status = 'active',
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.products,
        data: {
          'name': name,
          if (productTypeId != null) 'product_type_id': productTypeId,
          if (productQualityId != null) 'product_quality_id': productQualityId,
          'unit': unit,
          'status': status,
        },
      );

      return ProductModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductModel> updateProduct({
    required int id,
    String? name,
    int? productTypeId,
    int? productQualityId,
    String? unit,
    String? status,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.productById(id),
        data: {
          if (name != null) 'name': name,
          if (productTypeId != null) 'product_type_id': productTypeId,
          if (productQualityId != null) 'product_quality_id': productQualityId,
          if (unit != null) 'unit': unit,
          if (status != null) 'status': status,
        },
      );
      return ProductModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deleteProduct({required int id}) async {
    try {
      await _dio.delete(ApiEndpoints.productById(id));
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductColorModel> createProductColor({
    required int productId,
    required int colorId,
    String? imagePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'product_id': productId,
        'color_id': colorId,
        if (imagePath != null)
          'image': await MultipartFile.fromFile(
            imagePath,
            filename: imagePath.split('/').last,
          ),
      });

      final response = await _dio.post(
        ApiEndpoints.productColors,
        data: formData,
      );

      return ProductColorModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductColorModel> updateProductColor({
    required int productColorId,
    int? colorId,
    String? imagePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (colorId != null) 'color_id': colorId,
        if (imagePath != null)
          'image': await MultipartFile.fromFile(
            imagePath,
            filename: imagePath.split('/').last,
          ),
      });

      final response = await _dio.post(
        ApiEndpoints.productColorById(productColorId),
        data: formData,
        queryParameters: {'_method': 'PUT'},
      );

      return ProductColorModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deleteProductColor({required int productColorId}) async {
    try {
      await _dio.delete(ApiEndpoints.productColorById(productColorId));
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<ColorModel>> getColors() async {
    try {
      final response = await _dio.get(ApiEndpoints.colors);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => ColorModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Never _handleDioError(DioException e) {
    if (e.response?.statusCode == 401) {
      throw const UnauthorizedException();
    }
    final data = e.response?.data;
    final isJson = data is Map<String, dynamic>;
    if (e.response?.statusCode == 422) {
      final errors = isJson ? data['errors'] as Map<String, dynamic>? : null;
      final firstError = errors?.values.first;
      final message = firstError is List
          ? firstError.first as String
          : (isJson ? data['message'] as String? : null) ?? 'Validation error';
      throw ServerException(message: message, statusCode: 422);
    }
    if (e.response != null) {
      final message =
          isJson ? data['message'] as String? ?? 'Server error' : 'Server error';
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
