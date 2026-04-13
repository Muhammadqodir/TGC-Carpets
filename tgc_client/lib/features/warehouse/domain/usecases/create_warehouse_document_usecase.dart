import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/warehouse_document_entity.dart';
import '../repositories/warehouse_repository.dart';

class CreateWarehouseDocumentUseCase {
  final WarehouseRepository _repository;

  const CreateWarehouseDocumentUseCase(this._repository);

  Future<Either<Failure, WarehouseDocumentEntity>> call({
    required String type,
    required String documentDate,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? externalUuid,
  }) =>
      _repository.createDocument(
        type: type,
        documentDate: documentDate,
        items: items,
        notes: notes,
        externalUuid: externalUuid,
      );
}
