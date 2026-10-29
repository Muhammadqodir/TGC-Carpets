import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/label_print_result.dart';
import '../models/labeling_item_model.dart';

abstract class LabelingRemoteDataSource {
  Future<List<LabelingItemModel>> getLabelingItems();

  /// [reprint]: a replacement for a torn or misprinted label. The server
  /// records who printed it and when but does not count a carpet.
  ///
  /// Throws a [ServerException] when a 200 does not look like a recorded
  /// print (a proxy or captive portal page, a half-read body): the print
  /// queue then keeps the label and sends it again with the same key.
  Future<LabelPrintResult> printLabel({
    required int batchId,
    required int itemId,
    required String idempotencyKey,
    bool reprint = false,
    DateTime? printedAt,
  });

  /// The subset of [keys] the server has on record.
  Future<Set<String>> verifyPrintedLabels(List<String> keys);
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
  Future<LabelPrintResult> printLabel({
    required int batchId,
    required int itemId,
    required String idempotencyKey,
    bool reprint = false,
    DateTime? printedAt,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.productionBatchItemPrintLabel(batchId, itemId),
        data: {
          'idempotency_key': idempotencyKey,
          if (reprint) 'reprint': true,
          if (printedAt != null) 'printed_at': printedAt.toUtc().toIso8601String(),
        },
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final counted = body is Map ? body['counted'] : null;
      if (data is! Map<String, dynamic> || data['id'] != itemId || counted is! bool) {
        throw const ServerException(message: 'Server javobi noto\'g\'ri, qayta yuboriladi');
      }
      final unitMap = body['unit'] as Map<String, dynamic>?;
      return LabelPrintResult(
        item: LabelingItemModel.fromJson(data, unitSerial: unitMap?['serial'] as String?),
        counted: counted,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<Set<String>> verifyPrintedLabels(List<String> keys) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.printedLabelsVerify,
        data: {'keys': keys},
      );
      final body = response.data;
      final recorded = body is Map ? body['recorded'] : null;
      if (recorded is! List || body['missing'] is! List) {
        throw const ServerException(message: 'Server javobi noto\'g\'ri');
      }
      return recorded.map((k) => k.toString()).toSet();
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
