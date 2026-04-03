import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/sale_model.dart';

abstract class SaleRemoteDataSource {
  Future<PaginatedResponse<SaleModel>> getSales({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<SaleModel> getSale(int id);

  Future<SaleModel> createSale({
    required int clientId,
    required String saleDate,
    required List<Map<String, dynamic>> items,
    String? notes,
  });
}

class SaleRemoteDataSourceImpl implements SaleRemoteDataSource {
  final Dio _dio;

  const SaleRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<SaleModel>> getSales({
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
        ApiEndpoints.sales,
        queryParameters: queryParams,
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => SaleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<SaleModel>(
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
  Future<SaleModel> getSale(int id) async {
    try {
      final response = await _dio.get(ApiEndpoints.saleById(id));
      return SaleModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<SaleModel> createSale({
    required int clientId,
    required String saleDate,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.sales,
        data: {
          'client_id': clientId,
          'sale_date': saleDate,
          'items': items,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

      return SaleModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

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
    final message =
        (e.response?.data as Map<String, dynamic>?)?['message'] as String? ??
            'Server xatosi yuz berdi.';
    throw ServerException(message: message, statusCode: e.response?.statusCode);
  }
}
