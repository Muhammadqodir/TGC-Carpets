import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/api_error_message.dart';
import '../../../../core/error/exceptions.dart';
import '../../../shipments/data/models/shipment_model.dart';

abstract class ShipmentPricingRemoteDataSource {
  Future<ShipmentModel> getShipment(int id);

  /// Prices the lines of an existing shipment. Comes back with regenerated
  /// document URLs.
  Future<ShipmentModel> updatePrices({
    required int id,
    required List<Map<String, dynamic>> items,
  });

  Future<double?> getLastPrice({
    required int variantId,
    required int clientId,
  });
}

class ShipmentPricingRemoteDataSourceImpl
    implements ShipmentPricingRemoteDataSource {
  final Dio _dio;

  const ShipmentPricingRemoteDataSourceImpl(this._dio);

  @override
  Future<ShipmentModel> getShipment(int id) async {
    try {
      final response = await _dio.get(ApiEndpoints.shipmentById(id));
      return ShipmentModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ShipmentModel> updatePrices({
    required int id,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.shipmentPrices(id),
        data: {'items': items},
      );
      return ShipmentModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
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
    // Same rules as the shipments datasource: a request that never completed
    // is a connection problem the user can act on, and an unreadable body
    // never surfaces Dio's own English explanation of validateStatus.
    if (e.response == null) throw const NetworkException();

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    throw ServerException(
      message: apiErrorMessage(data) ?? apiFallbackMessage(data, statusCode),
      statusCode: statusCode,
    );
  }
}
