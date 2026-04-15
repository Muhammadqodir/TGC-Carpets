import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/payment_model.dart';

abstract class PaymentRemoteDataSource {
  Future<PaginatedResponse<PaymentModel>> getPayments({
    int? clientId,
    int? orderId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<PaymentModel> createPayment({
    required int clientId,
    int? orderId,
    required double amount,
    String? notes,
  });

  Future<void> deletePayment(int id);
}

class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  final Dio _dio;

  const PaymentRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<PaymentModel>> getPayments({
    int? clientId,
    int? orderId,
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
        if (orderId != null) 'order_id': orderId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      };

      final response = await _dio.get(
        ApiEndpoints.payments,
        queryParameters: queryParams,
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<PaymentModel>(
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
  Future<PaymentModel> createPayment({
    required int clientId,
    int? orderId,
    required double amount,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'client_id': clientId,
        'amount': amount,
        if (orderId != null) 'order_id': orderId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await _dio.post(ApiEndpoints.payments, data: body);
      return PaymentModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deletePayment(int id) async {
    try {
      await _dio.delete(ApiEndpoints.paymentById(id));
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Never _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final message =
        (e.response?.data as Map<String, dynamic>?)?['message'] as String?;
    throw ServerException(
      message: message ?? e.message ?? 'Server error',
      statusCode: statusCode,
    );
  }
}
