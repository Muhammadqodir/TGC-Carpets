import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/shipment_model.dart';

abstract class ShipmentRemoteDataSource {
  Future<PaginatedResponse<ShipmentModel>> getShipments({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
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
