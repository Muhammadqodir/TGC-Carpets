import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../../../orders/data/models/order_model.dart';
import '../models/shipment_model.dart';

abstract class ShipmentRemoteDataSource {
  Future<PaginatedResponse<ShipmentModel>> getShipments({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<ShipmentModel> createShipment({
    required int clientId,
    int? orderId,
    required String shipmentDatetime,
    String? notes,
    required List<Map<String, dynamic>> items,
  });

  Future<PaginatedResponse<OrderModel>> getOrdersForShipment({
    int? clientId,
    int page = 1,
    int perPage = 50,
  });

  Future<double?> getLastPrice({
    required int variantId,
    required int clientId,
  });
}

class ShipmentRemoteDataSourceImpl implements ShipmentRemoteDataSource {
  final Dio _dio;

  const ShipmentRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<ShipmentModel>> getShipments({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (clientId != null) 'client_id': clientId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      };

      final response = await _dio.get(
        ApiEndpoints.shipments,
        queryParameters: queryParams,
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => ShipmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<ShipmentModel>(
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
  Future<ShipmentModel> createShipment({
    required int clientId,
    int? orderId,
    required String shipmentDatetime,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final body = <String, dynamic>{
        'client_id': clientId,
        'shipment_datetime': shipmentDatetime,
        'items': items,
        if (orderId != null) 'order_id': orderId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await _dio.post(ApiEndpoints.shipments, data: body);
      return ShipmentModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<PaginatedResponse<OrderModel>> getOrdersForShipment({
    int? clientId,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (clientId != null) 'client_id': clientId,
      };

      final response = await _dio.get(
        ApiEndpoints.shipmentsOrdersForShipment,
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
  Future<double?> getLastPrice({
    required int variantId,
    required int clientId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.shipmentsLastPrice,
        queryParameters: {
          'variant_id': variantId,
          'client_id': clientId,
        },
      );
      final data =
          (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final raw = data['price'];
      if (raw == null) return null;
      return double.tryParse('$raw');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Never _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final message = (e.response?.data as Map<String, dynamic>?)?['message']
        as String?;
    throw ServerException(
      message: message ?? e.message ?? 'Server error',
      statusCode: statusCode,
    );
  }
}
