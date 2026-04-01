import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../models/dashboard_stats_model.dart';

abstract class DashboardRemoteDataSource {
  Future<DashboardStatsModel> getStats({
    required String from,
    required String to,
  });
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final Dio _dio;

  const DashboardRemoteDataSourceImpl(this._dio);

  @override
  Future<DashboardStatsModel> getStats({
    required String from,
    required String to,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.dashboardStats,
        queryParameters: {'from': from, 'to': to},
      );
      final data = (response.data as Map<String, dynamic>)['data']
          as Map<String, dynamic>;
      return DashboardStatsModel.fromJson(data);
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? e.message ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
