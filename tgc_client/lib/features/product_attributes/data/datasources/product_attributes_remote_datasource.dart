import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../products/data/models/color_model.dart';
import '../../../products/data/models/product_edge_model.dart';
import '../../../products/data/models/product_quality_model.dart';
import '../../../products/data/models/product_size_model.dart';
import '../../../products/data/models/product_type_model.dart';

abstract class ProductAttributesRemoteDataSource {
  // Colors
  Future<List<ColorModel>> getColors({String? search});
  Future<ColorModel> createColor({required String name});
  Future<ColorModel> updateColor({required int id, required String name});
  Future<int> checkColorUsage({required int id});
  Future<void> deleteColor({required int id, int? replaceWithId});

  // Product Types
  Future<List<ProductTypeModel>> getProductTypes();
  Future<ProductTypeModel> createProductType({required String type, bool isPrintable = true});
  Future<ProductTypeModel> updateProductType({required int id, required String type, bool isPrintable = true});
  Future<int> checkProductTypeUsage({required int id});
  Future<ProductTypeModel> archiveProductType({required int id});
  Future<ProductTypeModel> unarchiveProductType({required int id});
  Future<void> deleteProductType({required int id, int? replaceWithId});

  // Product Qualities
  Future<List<ProductQualityModel>> getProductQualities();
  Future<ProductQualityModel> createProductQuality({required String qualityName, int? density});
  Future<ProductQualityModel> updateProductQuality({required int id, required String qualityName, int? density});
  Future<int> checkProductQualityUsage({required int id});
  Future<ProductQualityModel> archiveProductQuality({required int id});
  Future<ProductQualityModel> unarchiveProductQuality({required int id});
  Future<void> deleteProductQuality({required int id, int? replaceWithId});

  // Product Sizes
  Future<List<ProductSizeModel>> getProductSizes({int? productTypeId});
  Future<ProductSizeModel> createProductSize({required int length, required int width, required int productTypeId});
  Future<ProductSizeModel> updateProductSize({required int id, required int length, required int width, required int productTypeId});
  Future<int> checkProductSizeUsage({required int id});
  Future<void> deleteProductSize({required int id, int? replaceWithId});

  // Product Edges
  Future<List<ProductEdgeModel>> getProductEdges();
  Future<ProductEdgeModel> createProductEdge({required String code, required String title});
  Future<ProductEdgeModel> updateProductEdge({required int id, required String code, required String title});
  Future<int> checkProductEdgeUsage({required int id});
  Future<void> deleteProductEdge({required int id, int? replaceWithId});
}

class ProductAttributesRemoteDataSourceImpl implements ProductAttributesRemoteDataSource {
  final Dio _dio;

  const ProductAttributesRemoteDataSourceImpl(this._dio);

  // ── Colors ─────────────────────────────────────────────────────────────────

  @override
  Future<List<ColorModel>> getColors({String? search}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.colors,
        queryParameters: {if (search != null && search.isNotEmpty) 'search': search},
      );
      final data = (response.data as Map<String, dynamic>)['data'] as List;
      return data.map((e) => ColorModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ColorModel> createColor({required String name}) async {
    try {
      final response = await _dio.post(ApiEndpoints.colors, data: {'name': name});
      return ColorModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ColorModel> updateColor({required int id, required String name}) async {
    try {
      final response = await _dio.put(ApiEndpoints.colorById(id), data: {'name': name});
      return ColorModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deleteColor({required int id, int? replaceWithId}) async {
    try {
      await _dio.delete(
        ApiEndpoints.colorById(id),
        data: {if (replaceWithId != null) 'replace_with_id': replaceWithId},
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<int> checkColorUsage({required int id}) async {
    try {
      final response = await _dio.get(ApiEndpoints.colorUsage(id));
      return (response.data as Map<String, dynamic>)['count'] as int;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Product Types ──────────────────────────────────────────────────────────

  @override
  Future<List<ProductTypeModel>> getProductTypes() async {
    try {
      final response = await _dio.get(ApiEndpoints.productTypes);
      final data = (response.data as Map<String, dynamic>)['data'] as List;
      return data.map((e) => ProductTypeModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductTypeModel> createProductType({required String type, bool isPrintable = true}) async {
    try {
      final response = await _dio.post(ApiEndpoints.productTypes, data: {'type': type, 'is_printable': isPrintable});
      return ProductTypeModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductTypeModel> updateProductType({required int id, required String type, bool isPrintable = true}) async {
    try {
      final response = await _dio.put(ApiEndpoints.productTypeById(id), data: {'type': type, 'is_printable': isPrintable});
      return ProductTypeModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductTypeModel> archiveProductType({required int id}) async {
    try {
      final response = await _dio.post(ApiEndpoints.productTypeArchive(id));
      return ProductTypeModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductTypeModel> unarchiveProductType({required int id}) async {
    try {
      final response = await _dio.post(ApiEndpoints.productTypeUnarchive(id));
      return ProductTypeModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deleteProductType({required int id, int? replaceWithId}) async {
    try {
      await _dio.delete(
        ApiEndpoints.productTypeById(id),
        data: {if (replaceWithId != null) 'replace_with_id': replaceWithId},
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<int> checkProductTypeUsage({required int id}) async {
    try {
      final response = await _dio.get(ApiEndpoints.productTypeUsage(id));
      return (response.data as Map<String, dynamic>)['count'] as int;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Product Qualities ──────────────────────────────────────────────────────

  @override
  Future<List<ProductQualityModel>> getProductQualities() async {
    try {
      final response = await _dio.get(ApiEndpoints.productQualities);
      final data = (response.data as Map<String, dynamic>)['data'] as List;
      return data.map((e) => ProductQualityModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductQualityModel> createProductQuality({required String qualityName, int? density}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.productQualities,
        data: {
          'quality_name': qualityName,
          if (density != null) 'density': density,
        },
      );
      return ProductQualityModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductQualityModel> updateProductQuality({required int id, required String qualityName, int? density}) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.productQualityById(id),
        data: {
          'quality_name': qualityName,
          'density': density,
        },
      );
      return ProductQualityModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductQualityModel> archiveProductQuality({required int id}) async {
    try {
      final response = await _dio.post(ApiEndpoints.productQualityArchive(id));
      return ProductQualityModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductQualityModel> unarchiveProductQuality({required int id}) async {
    try {
      final response = await _dio.post(ApiEndpoints.productQualityUnarchive(id));
      return ProductQualityModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deleteProductQuality({required int id, int? replaceWithId}) async {
    try {
      await _dio.delete(
        ApiEndpoints.productQualityById(id),
        data: {if (replaceWithId != null) 'replace_with_id': replaceWithId},
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<int> checkProductQualityUsage({required int id}) async {
    try {
      final response = await _dio.get(ApiEndpoints.productQualityUsage(id));
      return (response.data as Map<String, dynamic>)['count'] as int;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Product Sizes ──────────────────────────────────────────────────────────

  @override
  Future<List<ProductSizeModel>> getProductSizes({int? productTypeId}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.productSizes,
        queryParameters: {if (productTypeId != null) 'product_type_id': productTypeId},
      );
      final data = (response.data as Map<String, dynamic>)['data'] as List;
      return data.map((e) => ProductSizeModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductSizeModel> createProductSize({required int length, required int width, required int productTypeId}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.productSizes,
        data: {'length': length, 'width': width, 'product_type_id': productTypeId},
      );
      return ProductSizeModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductSizeModel> updateProductSize({required int id, required int length, required int width, required int productTypeId}) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.productSizeById(id),
        data: {'length': length, 'width': width, 'product_type_id': productTypeId},
      );
      return ProductSizeModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deleteProductSize({required int id, int? replaceWithId}) async {
    try {
      await _dio.delete(
        ApiEndpoints.productSizeById(id),
        data: {if (replaceWithId != null) 'replace_with_id': replaceWithId},
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<int> checkProductSizeUsage({required int id}) async {
    try {
      final response = await _dio.get(ApiEndpoints.productSizeUsage(id));
      return (response.data as Map<String, dynamic>)['count'] as int;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Product Edges ──────────────────────────────────────────────────────────

  @override
  Future<List<ProductEdgeModel>> getProductEdges() async {
    try {
      final response = await _dio.get(ApiEndpoints.productEdges);
      final data = (response.data as Map<String, dynamic>)['data'] as List;
      return data.map((e) => ProductEdgeModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductEdgeModel> createProductEdge({required String code, required String title}) async {
    try {
      final response = await _dio.post(ApiEndpoints.productEdges, data: {'code': code, 'title': title});
      return ProductEdgeModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductEdgeModel> updateProductEdge({required int id, required String code, required String title}) async {
    try {
      final response = await _dio.put(ApiEndpoints.productEdgeById(id), data: {'code': code, 'title': title});
      return ProductEdgeModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deleteProductEdge({required int id, int? replaceWithId}) async {
    try {
      await _dio.delete(
        ApiEndpoints.productEdgeById(id),
        data: {if (replaceWithId != null) 'replace_with_id': replaceWithId},
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<int> checkProductEdgeUsage({required int id}) async {
    try {
      final response = await _dio.get(ApiEndpoints.productEdgeUsage(id));
      return (response.data as Map<String, dynamic>)['count'] as int;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Error handling ─────────────────────────────────────────────────────────

  Never _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw NetworkException('Tarmoq xatosi. Internetni tekshiring.');
    }
    if (e.response?.statusCode == 401) {
      throw const UnauthorizedException();
    }
    final body = e.response?.data;
    final message = body is Map<String, dynamic>
        ? body['message'] as String? ?? 'Server xatosi yuz berdi.'
        : 'Server xatosi yuz berdi.';
    throw ServerException(message: message, statusCode: e.response?.statusCode);
  }
}
