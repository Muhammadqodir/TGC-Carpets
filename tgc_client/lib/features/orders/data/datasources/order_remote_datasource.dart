import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/order_model.dart';

abstract class OrderRemoteDataSource {
  Future<PaginatedResponse<OrderModel>> getOrders({
    String? status,
    int? clientId,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<OrderModel> getOrder(int id);

  /// Each item map must contain: product_color_id (required), product_size_id (nullable), quantity (required).
  Future<OrderModel> createOrder({
    required String orderDate,
    required List<Map<String, dynamic>> items,
    int? clientId,
    String status = 'pending',
    String? notes,
    String? externalUuid,
  });

  Future<OrderModel> updateOrder(
    int id, {
    String? status,
    String? orderDate,
    List<Map<String, dynamic>>? items,
    int? clientId,
    String? notes,
  });

  Future<void> deleteOrder(int id);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final Dio _dio;

  const OrderRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<OrderModel>> getOrders({
    String? status,
    int? clientId,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (clientId != null) 'client_id': clientId,
        if (userId != null) 'user_id': userId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      };

      final response = await _dio.get(
        ApiEndpoints.orders,
        queryParameters: queryParams,
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<OrderModel>(
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
  Future<OrderModel> getOrder(int id) async {
    try {
      final response = await _dio.get(ApiEndpoints.orderById(id));
      return OrderModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<OrderModel> createOrder({
    required String orderDate,
    required List<Map<String, dynamic>> items,
    int? clientId,
    String status = 'pending',
    String? notes,
    String? externalUuid,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.orders,
        data: {
          'order_date':    orderDate,
          'items':         items,
          'status':        status,
          if (clientId != null) 'client_id': clientId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (externalUuid != null) 'external_uuid': externalUuid,
        },
      );

      return OrderModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<OrderModel> updateOrder(
    int id, {
    String? status,
    String? orderDate,
    List<Map<String, dynamic>>? items,
    int? clientId,
    String? notes,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.orderById(id),
        data: {
          if (status != null) 'status': status,
          if (orderDate != null) 'order_date': orderDate,
          if (items != null) 'items': items,
          if (clientId != null) 'client_id': clientId,
          if (notes != null) 'notes': notes,
        },
      );

      return OrderModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deleteOrder(int id) async {
    try {
      await _dio.delete(ApiEndpoints.orderById(id));
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
      final message = e.response?.data?['message'] as String? ?? 'Server error';
      throw ServerException(message: message, statusCode: e.response?.statusCode);
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
        throw const NetworkException('Cannot connect to server. Please check your network.');
      case DioExceptionType.connectionTimeout:
        throw const NetworkException('Connection timed out. The server may be unavailable.');
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw const NetworkException('Request timed out. Please try again.');
      default:
        throw ServerException(message: e.message ?? 'Unexpected error', statusCode: e.response?.statusCode);
    }
  }
}
