import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/available_order_item_entity.dart';
import '../entities/machine_entity.dart';
import '../entities/production_batch_entity.dart';
import '../entities/production_batch_item_entity.dart';

abstract class ProductionRepository {
  // Machines
  Future<Either<Failure, PaginatedResponse<MachineEntity>>> getMachines({
    String? search,
    int page = 1,
    int perPage = 50,
  });

  Future<Either<Failure, MachineEntity>> createMachine({
    required String name,
    String? modelName,
  });

  // Production Batches
  Future<Either<Failure, PaginatedResponse<ProductionBatchEntity>>>
      getProductionBatches({
    String? status,
    String? type,
    int? machineId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, ProductionBatchEntity>> getProductionBatch(int id);

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

  Future<Either<Failure, void>> deleteProductionBatch(int id);

  Future<Either<Failure, ProductionBatchEntity>> startProductionBatch(int id);
  Future<Either<Failure, ProductionBatchEntity>> completeProductionBatch(
      int id);
  Future<Either<Failure, ProductionBatchEntity>> cancelProductionBatch(int id);

  // Batch item updates
  Future<Either<Failure, ProductionBatchItemEntity>> updateBatchItem(
    int batchId,
    int itemId, {
    int? producedQuantity,
    int? defectQuantity,
    String? notes,
  });

  // Available order items for production
  Future<Either<Failure, List<AvailableOrderItemEntity>>>
      getAvailableOrderItems();
}
