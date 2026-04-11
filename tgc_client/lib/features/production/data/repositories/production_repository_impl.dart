import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/available_order_item_entity.dart';
import '../../domain/entities/machine_entity.dart';
import '../../domain/entities/production_batch_entity.dart';
import '../../domain/entities/production_batch_item_entity.dart';
import '../../domain/repositories/production_repository.dart';
import '../datasources/production_remote_datasource.dart';

class ProductionRepositoryImpl implements ProductionRepository {
  final ProductionRemoteDataSource remoteDataSource;

  const ProductionRepositoryImpl({required this.remoteDataSource});

  // ── Machines ──────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, PaginatedResponse<MachineEntity>>> getMachines({
    String? search,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final result = await remoteDataSource.getMachines(
        search: search,
        page: page,
        perPage: perPage,
      );
      return Right(
        PaginatedResponse<MachineEntity>(
          data: result.data,
          currentPage: result.currentPage,
          lastPage: result.lastPage,
          perPage: result.perPage,
          total: result.total,
        ),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, MachineEntity>> createMachine({
    required String name,
    String? modelName,
  }) async {
    try {
      final machine = await remoteDataSource.createMachine(
        name: name,
        modelName: modelName,
      );
      return Right(machine);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  // ── Production Batches ────────────────────────────────────────────────────

  @override
  Future<Either<Failure, PaginatedResponse<ProductionBatchEntity>>>
      getProductionBatches({
    String? status,
    String? type,
    int? machineId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getProductionBatches(
        status: status,
        type: type,
        machineId: machineId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
      );
      return Right(
        PaginatedResponse<ProductionBatchEntity>(
          data: result.data,
          currentPage: result.currentPage,
          lastPage: result.lastPage,
          perPage: result.perPage,
          total: result.total,
        ),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ProductionBatchEntity>> getProductionBatch(
      int id) async {
    try {
      final batch = await remoteDataSource.getProductionBatch(id);
      return Right(batch);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ProductionBatchEntity>> createProductionBatch({
    required String batchTitle,
    required int machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final batch = await remoteDataSource.createProductionBatch(
        batchTitle: batchTitle,
        machineId: machineId,
        plannedDatetime: plannedDatetime,
        type: type,
        notes: notes,
        items: items,
      );
      return Right(batch);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ProductionBatchEntity>> updateProductionBatch(
    int id, {
    String? batchTitle,
    int? machineId,
    String? plannedDatetime,
    String? type,
    String? notes,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final batch = await remoteDataSource.updateProductionBatch(
        id,
        batchTitle: batchTitle,
        machineId: machineId,
        plannedDatetime: plannedDatetime,
        type: type,
        notes: notes,
        items: items,
      );
      return Right(batch);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProductionBatch(int id) async {
    try {
      await remoteDataSource.deleteProductionBatch(id);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ProductionBatchEntity>> startProductionBatch(
      int id) async {
    try {
      final batch = await remoteDataSource.startProductionBatch(id);
      return Right(batch);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ProductionBatchEntity>> completeProductionBatch(
      int id) async {
    try {
      final batch = await remoteDataSource.completeProductionBatch(id);
      return Right(batch);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ProductionBatchEntity>> cancelProductionBatch(
      int id) async {
    try {
      final batch = await remoteDataSource.cancelProductionBatch(id);
      return Right(batch);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ProductionBatchItemEntity>> updateBatchItem(
    int batchId,
    int itemId, {
    int? producedQuantity,
    int? defectQuantity,
    String? notes,
  }) async {
    try {
      final item = await remoteDataSource.updateBatchItem(
        batchId,
        itemId,
        producedQuantity: producedQuantity,
        defectQuantity: defectQuantity,
        notes: notes,
      );
      return Right(item);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<AvailableOrderItemEntity>>>
      getAvailableOrderItems() async {
    try {
      final items = await remoteDataSource.getAvailableOrderItems();
      return Right(items);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
