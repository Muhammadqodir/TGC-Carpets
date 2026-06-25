import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/warehouse_document_entity.dart';
import '../entities/warehouse_import_entities.dart';

abstract class WarehouseRepository {
  Future<Either<Failure, PaginatedResponse<WarehouseDocumentEntity>>> getDocuments({
    String? type,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 30,
  });

  Future<Either<Failure, WarehouseDocumentEntity>> getDocument(int id);

  Future<Either<Failure, WarehouseDocumentEntity>> createDocument({
    required String type,
    required String documentDate,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? externalUuid,
  });

  Future<Either<Failure, List<ImportClientEntity>>> getImportClients();

  Future<Either<Failure, List<ImportQualityEntity>>> getImportQualities({
    required int clientId,
  });

  Future<Either<Failure, List<ImportItemEntity>>> getImportItems({
    required int clientId,
    required String qualityName,
  });
}
