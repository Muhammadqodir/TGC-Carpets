import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../models/production_analytics_model.dart';

abstract class ProductionAnalyticsRemoteDataSource {
  Future<ProductionAnalyticsModel> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  });
}

class ProductionAnalyticsRemoteDataSourceImpl
    implements ProductionAnalyticsRemoteDataSource {
  final Dio _dio;

  const ProductionAnalyticsRemoteDataSourceImpl(this._dio);

  @override
  Future<ProductionAnalyticsModel> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.analyticsProduction,
        queryParameters: {
          'period_from': periodFrom,
          'period_to':   periodTo,
          'trend_by':    trendBy,
        },
      );

      final body = response.data as Map<String, dynamic>;
      return ProductionAnalyticsModel.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const UnauthorizedException();
      final data = e.response?.data;
      final msg = (data is Map ? data['message'] as String? : null) ?? e.message ?? 'Server xatosi';
      throw ServerException(message: msg, statusCode: e.response?.statusCode);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }
}
