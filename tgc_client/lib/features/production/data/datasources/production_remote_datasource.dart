import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/available_order_item_model.dart';
import '../models/machine_model.dart';
import '../models/production_batch_item_model.dart';
import '../models/production_batch_model.dart';

abstract class ProductionRemoteDataSource {
  // Machines
  Future<PaginatedResponse<MachineModel>> getMachines({
    String? search,
    int page = 1,
    int perPage = 50,
  });

  Future<MachineModel> createMachine({
    required String name,
    String? modelName,
  });

  // Production Batches
  Future<PaginatedResponse<ProductionBatchModel>> getProductionBatches({
    String? status,
    String? type,
    int? machineId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<ProductionBatchModel> getProductionBatch(int id);

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

  Future<void> deleteProductionBatch(int id);

  Future<ProductionBatchModel> startProductionBatch(int id);
  Future<ProductionBatchModel> completeProductionBatch(int id);
  Future<ProductionBatchModel> cancelProductionBatch(int id);

  Future<ProductionBatchItemModel> updateBatchItem(
    int batchId,
    int itemId, {
    int? producedQuantity,
    int? defectQuantity,
    String? notes,
  });

  Future<List<AvailableOrderItemModel>> getAvailableOrderItems();
}

class ProductionRemoteDataSourceImpl implements ProductionRemoteDataSource {
  final Dio _dio;

  const ProductionRemoteDataSourceImpl(this._dio);

  // ── Machines ──────────────────────────────────────────────────────────────

  @override
  Future<PaginatedResponse<MachineModel>> getMachines({
    String? search,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.machines,
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => MachineModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<MachineModel>(
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
  Future<MachineModel> createMachine({
    required String name,
    String? modelName,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.machines,
        data: {
          'name': name,
          if (modelName != null && modelName.isNotEmpty) 'model_name': modelName,
        },
      );

      return MachineModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Production Batches ────────────────────────────────────────────────────

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
      final response = await _dio.get(
        ApiEndpoints.productionBatches,
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (status != null && status.isNotEmpty) 'status': status,
          if (type != null && type.isNotEmpty) 'type': type,
          if (machineId != null) 'machine_id': machineId,
          if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
          if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) =>
              ProductionBatchModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<ProductionBatchModel>(
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
  Future<ProductionBatchModel> getProductionBatch(int id) async {
    try {
      final response =
          await _dio.get(ApiEndpoints.productionBatchById(id));
      return ProductionBatchModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
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
      final response = await _dio.post(
        ApiEndpoints.productionBatches,
        data: {
          'batch_title': batchTitle,
          'machine_id': machineId,
          if (plannedDatetime != null) 'planned_datetime': plannedDatetime,
          if (type != null) 'type': type,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (items != null) 'items': items,
        },
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
      final response = await _dio.put(
        ApiEndpoints.productionBatchById(id),
        data: {
          if (batchTitle != null) 'batch_title': batchTitle,
          if (machineId != null) 'machine_id': machineId,
          if (plannedDatetime != null) 'planned_datetime': plannedDatetime,
          if (type != null) 'type': type,
          if (notes != null) 'notes': notes,
          if (items != null) 'items': items,
        },
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
  Future<void> deleteProductionBatch(int id) async {
    try {
      await _dio.delete(ApiEndpoints.productionBatchById(id));
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductionBatchModel> startProductionBatch(int id) async {
    try {
      final response =
          await _dio.post(ApiEndpoints.productionBatchStart(id));
      return ProductionBatchModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductionBatchModel> completeProductionBatch(int id) async {
    try {
      final response =
          await _dio.post(ApiEndpoints.productionBatchComplete(id));
      return ProductionBatchModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductionBatchModel> cancelProductionBatch(int id) async {
    try {
      final response =
          await _dio.post(ApiEndpoints.productionBatchCancel(id));
      return ProductionBatchModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProductionBatchItemModel> updateBatchItem(
    int batchId,
    int itemId, {
    int? producedQuantity,
    int? defectQuantity,
    String? notes,
  }) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.productionBatchItemUpdate(batchId, itemId),
        data: {
          if (producedQuantity != null) 'produced_quantity': producedQuantity,
          if (defectQuantity != null) 'defect_quantity': defectQuantity,
          if (notes != null) 'notes': notes,
        },
      );

      return ProductionBatchItemModel.fromJson(
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<AvailableOrderItemModel>> getAvailableOrderItems() async {
    try {
      final response =
          await _dio.get(ApiEndpoints.productionBatchOrderItems);

      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) =>
              AvailableOrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Error handling ────────────────────────────────────────────────────────

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
      final message =
          e.response?.data?['message'] as String? ?? 'Server error';
      throw ServerException(message: message, statusCode: e.response?.statusCode);
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
        throw const NetworkException(
            'Cannot connect to server. Please check your network.');
      case DioExceptionType.connectionTimeout:
        throw const NetworkException(
            'Connection timed out. The server may be unavailable.');
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw const NetworkException(
            'Request timed out. Please try again.');
      default:
        throw ServerException(
            message: e.message ?? 'Unexpected error',
            statusCode: e.response?.statusCode);
    }
  }
}
