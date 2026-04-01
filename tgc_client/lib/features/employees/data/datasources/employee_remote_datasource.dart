import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/employee_model.dart';

abstract class EmployeeRemoteDataSource {
  Future<PaginatedResponse<EmployeeModel>> getEmployees({
    String? search,
    String? role,
    int page = 1,
    int perPage = 20,
  });

  Future<EmployeeModel> createEmployee({
    required String name,
    required String email,
    String? phone,
    required String password,
    required String role,
  });

  Future<EmployeeModel> updateEmployee({
    required int id,
    String? name,
    String? email,
    String? phone,
    String? password,
    String? role,
  });
}

class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  final Dio _dio;
  const EmployeeRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<EmployeeModel>> getEmployees({
    String? search,
    String? role,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.employees,
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search != null && search.isNotEmpty) 'search': search,
          if (role != null && role.isNotEmpty) 'role': role,
        },
      );
      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;
      return PaginatedResponse<EmployeeModel>(
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
  Future<EmployeeModel> createEmployee({
    required String name,
    required String email,
    String? phone,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.employees,
        data: {
          'name': name,
          'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'password': password,
          'role': role,
        },
      );
      return EmployeeModel.fromJson(
          (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<EmployeeModel> updateEmployee({
    required int id,
    String? name,
    String? email,
    String? phone,
    String? password,
    String? role,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.employeeById(id),
        data: {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (password != null && password.isNotEmpty) 'password': password,
          if (role != null) 'role': role,
        },
      );
      return EmployeeModel.fromJson(
          (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
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
    if (e.response?.statusCode == 401) throw const UnauthorizedException();
    final message = (e.response?.data as Map<String, dynamic>?)?['message'] as String? ??
        'Server xatosi yuz berdi.';
    throw ServerException(message: message, statusCode: e.response?.statusCode);
  }
}
