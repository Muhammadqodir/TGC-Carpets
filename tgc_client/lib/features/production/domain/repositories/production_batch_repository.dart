import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/production_batch_entity.dart';

abstract class ProductionBatchRepository {
  Future<Either<Failure, PaginatedResponse<ProductionBatchEntity>>> getProductionBatches({
    String? status,
    String? type,
    int? machineId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, List<ProductionBatchMachine>>> getMachines({
    String? search,
  });

  Future<Either<Failure, ProductionBatchEntity>> createProductionBatch({
    required String batchTitle,
    required int machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  });

  Future<Either<Failure, ProductionBatchEntity>> updateProductionBatch(
    int id, {
    String? batchTitle,
    int? machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  });
}
