import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/production_batch_entity.dart';
import '../../domain/entities/production_batch_item_entity.dart';
import '../../domain/repositories/production_batch_repository.dart';
import '../datasources/production_batch_remote_datasource.dart';

class ProductionBatchRepositoryImpl implements ProductionBatchRepository {
  final ProductionBatchRemoteDataSource remoteDataSource;

  const ProductionBatchRepositoryImpl({required this.remoteDataSource});

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
    bool excludeWarehouseReceived = false,
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
        excludeWarehouseReceived: excludeWarehouseReceived,
      );
      return Right(
        PaginatedResponse<ProductionBatchEntity>(
          data:        result.data,
          currentPage: result.currentPage,
          lastPage:    result.lastPage,
          perPage:     result.perPage,
          total:       result.total,
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
  Future<Either<Failure, List<ProductionBatchMachine>>> getMachines({
    String? search,
  }) async {
    try {
      final result = await remoteDataSource.getMachines(search: search);
      return Right(result);
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
      final result = await remoteDataSource.createProductionBatch(
        batchTitle:       batchTitle,
        machineId:        machineId,
        plannedDatetime:  plannedDatetime,
        type:             type,
        notes:            notes,
        items:            items,
      );
      return Right(result);
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
      final result = await remoteDataSource.updateProductionBatch(
        id,
        batchTitle:      batchTitle,
        machineId:       machineId,
        plannedDatetime: plannedDatetime,
        type:            type,
        notes:           notes,
        items:           items,
      );
      return Right(result);
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
    int id, {
    bool excludeWarehouseReceived = false,
  }) async {
    try {
      final result = await remoteDataSource.getProductionBatch(
        id,
        excludeWarehouseReceived: excludeWarehouseReceived,
      );
      return Right(result);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ProductionBatchItemEntity>> getProductionBatchItem(
    int batchId,
    int itemId,
  ) async {
    try {
      final result =
          await remoteDataSource.getProductionBatchItem(batchId, itemId);
      return Right(result);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
