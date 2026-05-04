import 'package:dio/dio.dart';
import 'package:tgc_client/core/constants/api_endpoints.dart';
import 'package:tgc_client/features/analytics/data/models/client_analytics_model.dart';
import 'package:tgc_client/features/analytics/data/models/financial_analytics_model.dart';
import 'package:tgc_client/features/analytics/data/models/production_analytics_model.dart';
import 'package:tgc_client/features/analytics/data/models/sales_analytics_model.dart';

abstract class AnalyticsRemoteDataSource {
  Future<SalesAnalyticsModel> getSalesAnalytics({
    required DateTime from,
    required DateTime to,
  });

  Future<ProductionAnalyticsModel> getProductionAnalytics({
    required DateTime from,
    required DateTime to,
  });

  Future<FinancialAnalyticsModel> getFinancialAnalytics({
    required DateTime from,
    required DateTime to,
  });

  Future<ClientAnalyticsModel> getClientAnalytics({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  });
}

class AnalyticsRemoteDataSourceImpl implements AnalyticsRemoteDataSource {
  final Dio dio;

  AnalyticsRemoteDataSourceImpl(this.dio);

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<SalesAnalyticsModel> getSalesAnalytics({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await dio.get(
      ApiEndpoints.analyticsSales,
      queryParameters: {
        'from': _formatDate(from),
        'to': _formatDate(to),
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return SalesAnalyticsModel.fromJson(data);
  }

  @override
  Future<ProductionAnalyticsModel> getProductionAnalytics({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await dio.get(
      ApiEndpoints.analyticsProduction,
      queryParameters: {
        'from': _formatDate(from),
        'to': _formatDate(to),
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return ProductionAnalyticsModel.fromJson(data);
  }

  @override
  Future<FinancialAnalyticsModel> getFinancialAnalytics({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await dio.get(
      ApiEndpoints.analyticsFinancial,
      queryParameters: {
        'from': _formatDate(from),
        'to': _formatDate(to),
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return FinancialAnalyticsModel.fromJson(data);
  }

  @override
  Future<ClientAnalyticsModel> getClientAnalytics({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  }) async {
    final response = await dio.get(
      ApiEndpoints.analyticsClients,
      queryParameters: {
        'from': _formatDate(from),
        'to': _formatDate(to),
        'limit': limit,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return ClientAnalyticsModel.fromJson(data);
  }
}
