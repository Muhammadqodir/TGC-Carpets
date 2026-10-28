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

  Future<List<ShipmentImportClientModel>> getShipmentImportClients();

  Future<List<ShipmentImportQualityModel>> getShipmentImportQualities({
    required int clientId,
  });

  Future<List<ShipmentImportItemModel>> getShipmentImportItems({
    required int clientId,
    required String qualityName,
  });

  /// Resolves a scanned label QR code to a shippable item for [clientId].
  ///
  /// [inForm] is what the form already carries per order line
  /// ({orderItemId: quantity}), so the server can skip lines that are full.
  Future<ShipmentImportItemModel> getShipmentScanItem({
    required String code,
    required int clientId,
    Map<int, int> inForm = const {},
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
    Map<int, int> inForm = const {},
  }) async {
    try {
      return await _scanOnce(code, clientId, inForm);
    } on DioException catch (e) {
      // "code/client_id missing" means the request arrived without its
      // input: a transport accident, never a property of the label. One quiet
      // retry costs the worker nothing and turns a one-off loss into a normal
      // scan; only a second loss reaches the screen.
      if (!_isMissingScanInput(e)) _throwScanError(e, code, clientId);

      try {
        return await _scanOnce(code, clientId, inForm);
      } on DioException catch (retryError) {
        _throwScanError(retryError, code, clientId);
      }
    }
  }

  /// One scan round trip, with the "add anyway" 404 already turned into a
  /// result.
  Future<ShipmentImportItemModel> _scanOnce(
    String code,
    int clientId,
    Map<int, int> inForm,
  ) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.shipmentImportScan,
        // Code and client travel in BOTH the query string and the JSON body.
        // Field reports of "The code field is required. (and 1 more error)"
        // mean the server received neither; the August 2026 fix moved them
        // from the URL into the body, and now losing either copy still leaves
        // the other (Laravel merges query and body input). `in_form` rides in
        // the body only — without it the server suggests lines the old way.
        queryParameters: {
          'code': code,
          'client_id': clientId,
        },
        data: {
          'code': code,
          'client_id': clientId,
          if (inForm.isNotEmpty)
            'in_form': {
              for (final entry in inForm.entries) '${entry.key}': entry.value,
            },
        },
      );
      return _parseScanItem(response.data, 'data');
    } on DioException catch (e) {
      // The "add anyway" case — the label resolved to a real carpet, this
      // client just has no open order line with room for it — arrives as a
      // 200 with a null order_item_id under `data` since October 2026 and is
      // handled above. Servers before that sent it as a 404 carrying
      // `unmatched`, which prod's nginx replaced with its own HTML page; still
      // read here in case one answers that way.
      final data = e.response?.data;
      if (e.response?.statusCode == 404 &&
          data is Map<String, dynamic> &&
          data['unmatched'] is Map<String, dynamic>) {
        return _parseScanItem(data, 'unmatched');
      }
      rethrow;
    }
  }

  /// A 422 naming `code` or `client_id` — fields the app always sends, so
  /// their absence is never the worker's doing.
  bool _isMissingScanInput(DioException e) {
    final data = e.response?.data;
    if (e.response?.statusCode != 422 || data is! Map) return false;
    final errors = data['errors'];
    return errors is Map &&
        (errors.containsKey('code') || errors.containsKey('client_id'));
  }

  /// Reads the scan item under [key] of [data], turning a body of the wrong
  /// shape into a readable [ServerException]. A cast failure used to escape
  /// the repository uncaught: the scanner showed nothing, and went on
  /// ignoring that label until a different one was scanned.
  ShipmentImportItemModel _parseScanItem(dynamic data, String key) {
    try {
      final item = (data as Map<String, dynamic>)[key];
      return ShipmentImportItemModel.fromJson(item as Map<String, dynamic>);
    } on Object {
      throw ServerException(
        message: apiFallbackMessage(data, null),
      );
    }
  }

  Never _throwScanError(DioException e, String code, int clientId) {
    // A label the server could not resolve to any carpet. Sent as a 422
    // (under `label`) because a 404 body never got past prod's nginx; shown
    // as the 404 it means, so the headline reads "Yorliq topilmadi".
    final data = e.response?.data;
    if (e.response?.statusCode == 422 &&
        data is Map &&
        data['errors'] is Map &&
        (data['errors'] as Map).containsKey('label')) {
      throw ServerException(
        message: [
          apiErrorMessage(data) ?? 'Mahsulot topilmadi.',
          'Kod: "$code"',
        ].join('\n'),
        statusCode: 404,
      );
    }

    // A 422 that survived the retry: the server still saw no code or
    // client. Show what the phone had, so the difference from what the
    // server reports names the culprit in the next screenshot.
    if (e.response?.statusCode == 422) {
      throw ServerException(
        message: [
          apiErrorMessage(e.response?.data) ?? 'Server error',
          'Yuborilgan kod: "$code" (mijoz #$clientId)',
        ].join('\n'),
        statusCode: 422,
      );
    }

    _handleDioError(e);
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
