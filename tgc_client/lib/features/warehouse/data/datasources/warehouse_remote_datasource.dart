import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/warehouse_document_model.dart';

abstract class WarehouseRemoteDataSource {
  Future<PaginatedResponse<WarehouseDocumentModel>> getDocuments({
    String? type,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int? clientId,
    int page = 1,
    int perPage = 20,
  });

  Future<WarehouseDocumentModel> getDocument(int id);

  Future<WarehouseDocumentModel> createDocument({
    required String type,
    required String documentDate,
    required List<Map<String, dynamic>> items,
    int? clientId,
    String? notes,
    String? externalUuid,
  });
}

class WarehouseRemoteDataSourceImpl implements WarehouseRemoteDataSource {
  final Dio _dio;

  const WarehouseRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<WarehouseDocumentModel>> getDocuments({
    String? type,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int? clientId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (type != null && type.isNotEmpty) 'type': type,
        if (userId != null) 'user_id': userId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        if (clientId != null) 'client_id': clientId,
      };

      final response = await _dio.get(
        ApiEndpoints.warehouseDocuments,
        queryParameters: queryParams,
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => WarehouseDocumentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<WarehouseDocumentModel>(
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
  Future<WarehouseDocumentModel> getDocument(int id) async {
    try {
      final response = await _dio.get(ApiEndpoints.warehouseDocumentById(id));
      return WarehouseDocumentModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<WarehouseDocumentModel> createDocument({
    required String type,
    required String documentDate,
    required List<Map<String, dynamic>> items,
    int? clientId,
    String? notes,
    String? externalUuid,
  }) async {
    try {
      final body = <String, dynamic>{
        'type': type,
        'document_date': documentDate,
        'items': items,
        if (clientId != null) 'client_id': clientId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (externalUuid != null && externalUuid.isNotEmpty)
          'external_uuid': externalUuid,
      };

      final response = await _dio.post(
        ApiEndpoints.warehouseDocuments,
        data: body,
      );

      return WarehouseDocumentModel.fromJson(
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
