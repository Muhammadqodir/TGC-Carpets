import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/warehouse_document_entity.dart';

abstract class WarehouseRepository {
  Future<Either<Failure, PaginatedResponse<WarehouseDocumentEntity>>> getDocuments({
    String? type,
    int? userId,
    String? dateFrom,
    String? dateTo,
    String? sourceType,
    int? sourceId,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, WarehouseDocumentEntity>> getDocument(int id);

  Future<Either<Failure, WarehouseDocumentEntity>> createDocument({
    required String type,
    required String documentDate,
    required List<Map<String, dynamic>> items,
    String? sourceType,
    int? sourceId,
    String? notes,
    String? externalUuid,
  });
}
