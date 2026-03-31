import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/client_model.dart';

abstract class ClientRemoteDataSource {
  Future<PaginatedResponse<ClientModel>> getClients({
    String? search,
    String? region,
    int page = 1,
    int perPage = 20,
  });

  Future<ClientModel> getClient(int id);

  Future<ClientModel> createClient({
    required String contactName,
    required String phone,
    required String shopName,
    required String region,
    String? address,
    String? notes,
  });
}

class ClientRemoteDataSourceImpl implements ClientRemoteDataSource {
  final Dio _dio;

  const ClientRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<ClientModel>> getClients({
    String? search,
    String? region,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (search != null && search.isNotEmpty) 'shop_name': search,
        if (region != null && region.isNotEmpty) 'region': region,
      };

      final response = await _dio.get(
        ApiEndpoints.clients,
        queryParameters: queryParams,
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<ClientModel>(
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
  Future<ClientModel> getClient(int id) async {
    try {
      final response = await _dio.get(ApiEndpoints.clientById(id));
      return ClientModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ClientModel> createClient({
    required String contactName,
    required String phone,
    required String shopName,
    required String region,
    String? address,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.clients,
        data: {
          'contact_name': contactName,
          'phone': phone,
          'shop_name': shopName,
          'region': region,
          if (address != null && address.isNotEmpty) 'address': address,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

      return ClientModel.fromJson(
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
    final message = (e.response?.data as Map<String, dynamic>?)?['message']
            as String? ??
        'Server xatosi yuz berdi.';
    throw ServerException(message: message, statusCode: e.response?.statusCode);
  }
}
