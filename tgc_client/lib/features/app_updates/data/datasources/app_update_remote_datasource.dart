import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/app_release_model.dart';

abstract class AppUpdateRemoteDataSource {
  /// Returns null when the server has no release for [platform] (404).
  Future<AppReleaseModel?> getLatestRelease({required String platform});
}

class AppUpdateRemoteDataSourceImpl implements AppUpdateRemoteDataSource {
  final Dio _dio;

  const AppUpdateRemoteDataSourceImpl(this._dio);

  @override
  Future<AppReleaseModel?> getLatestRelease({required String platform}) async {
    try {
      // This endpoint lives at /api/app-updates/latest, not under /api/v1/
      final url = AppConstants.publicApiUrl + ApiEndpoints.appUpdatesLatest;

      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'platform': platform},
      );

      final data = response.data;
      if (data == null) return null;
      return AppReleaseModel.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ServerException(
        message: e.response?.data?['message'] as String? ??
            e.message ??
            'Yangilanishni tekshirishda xatolik yuz berdi.',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
