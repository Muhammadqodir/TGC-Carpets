import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/defect_document_entity.dart';

abstract class DefectDocumentRemoteDataSource {
  Future<PaginatedResponse<DefectDocumentEntity>> getDefectDocuments(
    int batchId, {
    int page = 1,
    int perPage = 20,
  });

  Future<DefectDocumentEntity> createDefectDocument({
    required int batchId,
    required String description,
    required List<Map<String, dynamic>> items,
    String? datetime,
    List<MultipartFile>? photos,
  });

  Future<void> deleteDefectDocument(int id);
}

class DefectDocumentRemoteDataSourceImpl
    implements DefectDocumentRemoteDataSource {
  final Dio _dio;

  const DefectDocumentRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<DefectDocumentEntity>> getDefectDocuments(
    int batchId, {
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.defectDocuments(batchId),
        queryParameters: {'page': page, 'per_page': perPage},
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<DefectDocumentEntity>(
        data:        dataList,
        currentPage: meta['current_page'] as int,
        lastPage:    meta['last_page'] as int,
        perPage:     meta['per_page'] as int,
        total:       meta['total'] as int,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<DefectDocumentEntity> createDefectDocument({
    required int batchId,
    required String description,
    required List<Map<String, dynamic>> items,
    String? datetime,
    List<MultipartFile>? photos,
  }) async {
    try {
      final formData = FormData();

      formData.fields.add(MapEntry('description', description));

      if (datetime != null) {
        formData.fields.add(MapEntry('datetime', datetime));
      }

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        formData.fields.add(MapEntry(
          'items[$i][production_batch_item_id]',
          item['production_batch_item_id'].toString(),
        ));
        formData.fields.add(MapEntry(
          'items[$i][quantity]',
          item['quantity'].toString(),
        ));
      }

      if (photos != null) {
        for (final photo in photos) {
          formData.files.add(MapEntry('photos[]', photo));
        }
      }

      final response = await _dio.post(
        ApiEndpoints.defectDocuments(batchId),
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return _fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<void> deleteDefectDocument(int id) async {
    try {
      await _dio.delete(ApiEndpoints.defectDocumentById(id));
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  DefectDocumentEntity _fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List? ?? [];
    final photosRaw = json['photos'] as List? ?? [];

    return DefectDocumentEntity(
      id:                  json['id'] as int,
      productionBatchId:   json['production_batch_id'] as int,
      datetime:            DateTime.parse(json['datetime'] as String),
      description:         json['description'] as String,
      userName:            (json['user'] as Map<String, dynamic>?)?['name'] as String?,
      userId:              (json['user'] as Map<String, dynamic>?)?['id'] as int?,
      items:               itemsRaw.map((e) => _itemFromJson(e as Map<String, dynamic>)).toList(),
      photos:              photosRaw.map((e) => _photoFromJson(e as Map<String, dynamic>)).toList(),
      createdAt:           DateTime.parse(json['created_at'] as String),
    );
  }

  DefectDocumentItemEntity _itemFromJson(Map<String, dynamic> json) {
    final batchItemRaw = json['batch_item'] as Map<String, dynamic>?;

    return DefectDocumentItemEntity(
      id:                      json['id'] as int,
      defectDocumentId:        json['defect_document_id'] as int,
      productionBatchItemId:   json['production_batch_item_id'] as int,
      quantity:                json['quantity'] as int,
      batchItem: batchItemRaw != null
          ? DefectDocumentBatchItemRef(
              id:              batchItemRaw['id'] as int,
              plannedQuantity: batchItemRaw['planned_quantity'] as int,
              productName:     batchItemRaw['product_name'] as String?,
              colorName:       batchItemRaw['color_name'] as String?,
              imageUrl:        batchItemRaw['image_url'] as String?,
              sizeLength:      batchItemRaw['size_length'] as int?,
              sizeWidth:       batchItemRaw['size_width'] as int?,
            )
          : null,
    );
  }

  DefectDocumentPhotoEntity _photoFromJson(Map<String, dynamic> json) {
    return DefectDocumentPhotoEntity(
      id:   json['id'] as int,
      url:  json['url'] as String,
      path: json['path'] as String,
    );
  }

  // ── Error handling ────────────────────────────────────────────────────────

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
