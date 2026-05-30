import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../models/product_analytics_model.dart';

abstract class ProductAnalyticsRemoteDataSource {
  Future<ProductAnalyticsModel> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  });
}

class ProductAnalyticsRemoteDataSourceImpl
    implements ProductAnalyticsRemoteDataSource {
  final Dio _dio;

  const ProductAnalyticsRemoteDataSourceImpl(this._dio);

  @override
  Future<ProductAnalyticsModel> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.analyticsProducts,
        queryParameters: {
          'period_from': periodFrom,
          'period_to':   periodTo,
          'trend_by':    trendBy,
        },
      );

      final body = response.data as Map<String, dynamic>;
      return ProductAnalyticsModel.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const UnauthorizedException();
      final msg = (e.response?.data?['message'] as String?) ?? e.message ?? 'Server xatosi';
      throw ServerException(message: msg, statusCode: e.response?.statusCode);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }
}
