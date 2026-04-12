import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../models/labeling_item_model.dart';

abstract class LabelingRemoteDataSource {
  Future<List<LabelingItemModel>> getLabelingItems();

  Future<LabelingItemModel> printLabel({
    required int batchId,
    required int itemId,
  });
}

class LabelingRemoteDataSourceImpl implements LabelingRemoteDataSource {
  final Dio _dio;

  const LabelingRemoteDataSourceImpl(this._dio);

  @override
  Future<List<LabelingItemModel>> getLabelingItems() async {
    try {
      final response = await _dio.get(ApiEndpoints.labelingItems);
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => LabelingItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<LabelingItemModel> printLabel({
    required int batchId,
    required int itemId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.productionBatchItemPrintLabel(batchId, itemId),
      );
      final body = response.data as Map<String, dynamic>;
      return LabelingItemModel.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

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
