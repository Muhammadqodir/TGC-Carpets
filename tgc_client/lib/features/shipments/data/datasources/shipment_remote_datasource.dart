import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/api_error_message.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../../../orders/data/models/order_model.dart';
import '../models/shipment_import_models.dart';
import '../models/shipment_model.dart';

abstract class ShipmentRemoteDataSource {
  Future<PaginatedResponse<ShipmentModel>> getShipments({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 30,
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

  Future<List<ShipmentImportClientModel>> getShipmentImportClients();

  Future<List<ShipmentImportQualityModel>> getShipmentImportQualities({
    required int clientId,
  });

  Future<List<ShipmentImportItemModel>> getShipmentImportItems({
    required int clientId,
    required String qualityName,
  });

  /// Resolves a scanned label QR code to a shippable item for [clientId].
  Future<ShipmentImportItemModel> getShipmentScanItem({
    required String code,
    required int clientId,
  });

  /// Cancels [id], returning the carpets to the warehouse. Admin only —
  /// the backend enforces it, a non-admin gets a 403.
  Future<ShipmentModel> cancelShipment({
    required int id,
    String? reason,
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
    int perPage = 30,
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

  @override
  Future<List<ShipmentImportClientModel>> getShipmentImportClients() async {
    try {
      final response = await _dio.get(ApiEndpoints.shipmentImportClients);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => ShipmentImportClientModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<ShipmentImportQualityModel>> getShipmentImportQualities({
    required int clientId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.shipmentImportQualities,
        queryParameters: {'client_id': clientId},
      );
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => ShipmentImportQualityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<ShipmentImportItemModel>> getShipmentImportItems({
    required int clientId,
    required String qualityName,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.shipmentImportItems,
        queryParameters: {
          'client_id': clientId,
          'quality_name': qualityName,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => ShipmentImportItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ShipmentImportItemModel> getShipmentScanItem({
    required String code,
    required int clientId,
  }) async {
    try {
      // POST, not GET: the scanned code is arbitrary text off a physical
      // label, and in the query string it depended on every hop between the
      // phone and nginx preserving it. In August 2026 some labels came back
      // as "code and client_id are required" — the server receiving neither —
      // which no amount of client-side encoding could explain. In a JSON body
      // there is nothing left to mangle.
      final response = await _dio.post(
        ApiEndpoints.shipmentImportScan,
        data: {
          'code': code,
          'client_id': clientId,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return ShipmentImportItemModel.fromJson(
        body['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      // A 404 carrying `unmatched` is not a failure: the label resolved to a
      // real carpet, this client just has no open order line for it. That is
      // the "add anyway" case, so the resolved product comes back as a normal
      // result with a null orderItemId and the UI offers to add it. Any other
      // 404 (unreadable code, unknown label) stays an error.
      final data = e.response?.data;
      if (e.response?.statusCode == 404 &&
          data is Map<String, dynamic> &&
          data['unmatched'] is Map<String, dynamic>) {
        return ShipmentImportItemModel.fromJson(
          data['unmatched'] as Map<String, dynamic>,
        );
      }

      // A 422 here means the server saw no `code`/`client_id`, which cannot
      // originate in this method: both are non-nullable, and they now travel
      // in a JSON body rather than a URL. If it still happens, the request
      // body itself is being lost in transit — so the card shows what the
      // phone had, and the difference from what the server reports names the
      // culprit. Remove once the field reports stop.
      if (e.response?.statusCode == 422) {
        throw ServerException(
          message: [
            apiErrorMessage(data) ?? 'Server error',
            'Yuborilgan kod: "$code" (mijoz #$clientId)',
          ].join('\n'),
          statusCode: 422,
        );
      }

      _handleDioError(e);
    }
  }

  @override
  Future<ShipmentModel> cancelShipment({
    required int id,
    String? reason,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.shipmentCancel(id),
        data: {
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );
      final body = response.data as Map<String, dynamic>;
      return ShipmentModel.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Never _handleDioError(DioException e) {
    // No response at all: the request never completed — airplane mode, wifi
    // that dropped between the racks, a timeout. The repository turns this
    // into "Internet aloqasi yo'q", which is the one message a worker on the
    // floor can act on themselves.
    if (e.response == null) throw const NetworkException();

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    // Every validation error, not Laravel's "(and 1 more error)" summary.
    final message = apiErrorMessage(data);
    throw ServerException(
      message: message ?? apiFallbackMessage(data, statusCode),
      statusCode: statusCode,
    );
  }
}
