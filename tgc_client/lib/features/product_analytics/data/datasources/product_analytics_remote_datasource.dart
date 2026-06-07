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

  Future<List<TopProductItemModel>> getTopProducts({
    required String periodFrom,
    required String periodTo,
    required int limit,
    int? typeId,
    int? qualityId,
    int? sizeId,
    int? colorId,
    int? edgeId,
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

  @override
  Future<List<TopProductItemModel>> getTopProducts({
    required String periodFrom,
    required String periodTo,
    required int limit,
    int? typeId,
    int? qualityId,
    int? sizeId,
    int? colorId,
    int? edgeId,
  }) async {
    try {
      final params = <String, dynamic>{
        'period_from': periodFrom,
        'period_to':   periodTo,
        'limit':       limit,
        if (typeId != null)    'type_id':    typeId,
        if (qualityId != null) 'quality_id': qualityId,
        if (sizeId != null)    'size_id':    sizeId,
        if (colorId != null)   'color_id':   colorId,
        if (edgeId != null)    'edge_id':    edgeId,
      };

      final response = await _dio.get(
        ApiEndpoints.analyticsTopProducts,
        queryParameters: params,
      );

      final body = response.data as Map<String, dynamic>;
      final list  = body['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => TopProductItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const UnauthorizedException();
      final msg = (e.response?.data?['message'] as String?) ?? e.message ?? 'Server xatosi';
      throw ServerException(message: msg, statusCode: e.response?.statusCode);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }
}
