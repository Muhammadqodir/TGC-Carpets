import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/production_batch_model.dart';
import '../models/machine_model.dart';

abstract class ProductionBatchRemoteDataSource {
  Future<PaginatedResponse<ProductionBatchModel>> getProductionBatches({
    String? status,
    String? type,
    int? machineId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<List<MachineModel>> getMachines({String? search});

  Future<ProductionBatchModel> createProductionBatch({
    required String batchTitle,
    required int machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  });

  Future<ProductionBatchModel> updateProductionBatch(
    int id, {
    String? batchTitle,
    int? machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  });

  Future<ProductionBatchModel> getProductionBatch(int id);

  Future<ProductionBatchModel> startBatch(int id, {required int responsibleEmployeeId});

  Future<ProductionBatchModel> cancelBatch(int id);
}

class ProductionBatchRemoteDataSourceImpl
    implements ProductionBatchRemoteDataSource {
  final Dio _dio;

  const ProductionBatchRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<ProductionBatchModel>> getProductionBatches({
    String? status,
    String? type,
    int? machineId,
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
        if (type != null && type.isNotEmpty) 'type': type,
        if (machineId != null) 'machine_id': machineId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      };

      final response = await _dio.get(
        ApiEndpoints.productionBatches,
        queryParameters: queryParams,
      );

      final body     = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => ProductionBatchModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<ProductionBatchModel>(
        data:        dataList,
        currentPage: meta['current_page'] as int,
        lastPage:    meta['last_page'] as int,
        perPage:     meta['per_page'] as int,
        total:       meta['total'] as int,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<MachineModel>> getMachines({String? search}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.machines,
        queryParameters: <String, dynamic>{
          'per_page': 50,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => MachineModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductionBatchModel> createProductionBatch({
    required String batchTitle,
    required int machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final body = <String, dynamic>{
        'batch_title': batchTitle,
        'machine_id':  machineId,
        if (plannedDatetime != null) 'planned_datetime': plannedDatetime,
        if (type != null) 'type': type,
        if (notes != null) 'notes': notes,
        if (items != null && items.isNotEmpty) 'items': items,
      };
      final response =
          await _dio.post(ApiEndpoints.productionBatches, data: body);
      return ProductionBatchModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductionBatchModel> updateProductionBatch(
    int id, {
    String? batchTitle,
    int? machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final body = <String, dynamic>{
        if (batchTitle != null) 'batch_title': batchTitle,
        if (machineId != null) 'machine_id': machineId,
        if (plannedDatetime != null) 'planned_datetime': plannedDatetime,
        if (type != null) 'type': type,
        if (notes != null) 'notes': notes,
        if (items != null) 'items': items,
      };
      final response = await _dio.put(
          ApiEndpoints.productionBatchById(id), data: body);
      return ProductionBatchModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductionBatchModel> getProductionBatch(int id) async {
    try {
      final response = await _dio.get(ApiEndpoints.productionBatchById(id));
      return ProductionBatchModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductionBatchModel> startBatch(
    int id, {
    required int responsibleEmployeeId,
  }) async {
    try {
      final body = <String, dynamic>{
        'responsible_employee_id': responsibleEmployeeId,
      };
      final response = await _dio.post(
        ApiEndpoints.productionBatchStart(id),
        data: body,
      );
      return ProductionBatchModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductionBatchModel> cancelBatch(int id) async {
    try {
      final response = await _dio.post(ApiEndpoints.productionBatchCancel(id));
      return ProductionBatchModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Never _handleDioError(DioException e) {    if (e.response?.statusCode == 401) {
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
          e.response?.data?['message'] as String? ?? 'Server xatosi';
      throw ServerException(
          message: message, statusCode: e.response?.statusCode);
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
        throw const NetworkException('Serverga ulanib bo\'lmadi.');
      case DioExceptionType.connectionTimeout:
        throw const NetworkException('Ulanish vaqti tugadi.');
      case DioExceptionType.receiveTimeout:
        throw const NetworkException('So\'rov vaqti tugadi.');
      default:
        throw ServerException(
            message: e.message ?? 'Kutilmagan xatolik',
            statusCode: e.response?.statusCode);
    }
  }
}
