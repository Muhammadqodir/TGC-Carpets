import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/warehouse_document_entity.dart';
import '../repositories/warehouse_repository.dart';

class GetWarehouseDocumentsUseCase {
  final WarehouseRepository _repository;

  const GetWarehouseDocumentsUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<WarehouseDocumentEntity>>> call({
    String? type,
    int? userId,
    String? dateFrom,
    String? dateTo,
    String? sourceType,
    int? sourceId,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getDocuments(
        type: type,
        userId: userId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        sourceType: sourceType,
        sourceId: sourceId,
        page: page,
        perPage: perPage,
      );
}
