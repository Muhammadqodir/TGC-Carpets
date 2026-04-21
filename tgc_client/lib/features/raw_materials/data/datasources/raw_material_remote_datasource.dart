import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/raw_material_model.dart';
import '../models/raw_material_movement_model.dart';

abstract class RawMaterialRemoteDataSource {
  Future<PaginatedResponse<RawMaterialModel>> getMaterials({
    String? type,
    String? search,
    int page = 1,
    int perPage = 50,
  });

  Future<RawMaterialModel> createMaterial({
    required String name,
    required String type,
    required String unit,
  });

  Future<void> deleteMaterial(int id);

  Future<List<RawMaterialMovementModel>> storeBatchMovement({
    required String dateTime,
    required String type,
    String? notes,
    required List<Map<String, dynamic>> items,
  });
}

class RawMaterialRemoteDataSourceImpl implements RawMaterialRemoteDataSource {
  final Dio _dio;

  const RawMaterialRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<RawMaterialModel>> getMaterials({
    String? type,
    String? search,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.rawMaterials,
        queryParameters: {
          'page':     page,
          'per_page': perPage,
          if (type != null && type.isNotEmpty)   'type': type,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => RawMaterialModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<RawMaterialModel>(
        data:        dataList,
        currentPage: meta['current_page'] as int,
        lastPage:    meta['last_page'] as int,
        perPage:     meta['per_page'] as int,
        total:       meta['total'] as int,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const UnauthorizedException();
      throw ServerException(
        message:    e.response?.data?['message'] as String? ?? e.message ?? 'Server xatosi',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  @override
  Future<RawMaterialModel> createMaterial({
    required String name,
    required String type,
    required String unit,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.rawMaterials,
        data: {'name': name, 'type': type, 'unit': unit},
      );
      return RawMaterialModel.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const UnauthorizedException();
      throw ServerException(
        message:    e.response?.data?['message'] as String? ?? e.message ?? 'Server xatosi',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  @override
  Future<void> deleteMaterial(int id) async {
    try {
      await _dio.delete(ApiEndpoints.rawMaterialById(id));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const UnauthorizedException();
      throw ServerException(
        message:    e.response?.data?['message'] as String? ?? e.message ?? 'Server xatosi',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  @override
  Future<List<RawMaterialMovementModel>> storeBatchMovement({
    required String dateTime,
    required String type,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.rawMaterialMovementsBatch,
        data: {
          'date_time': dateTime,
          'type':      type,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'items':     items,
        },
      );

      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => RawMaterialMovementModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const UnauthorizedException();
      throw ServerException(
        message:    e.response?.data?['message'] as String? ?? e.message ?? 'Server xatosi',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }
}
