import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/raw_material_entity.dart';
import '../../domain/entities/raw_material_movement_entity.dart';
import '../../domain/repositories/raw_material_repository.dart';
import '../datasources/raw_material_remote_datasource.dart';

class RawMaterialRepositoryImpl implements RawMaterialRepository {
  final RawMaterialRemoteDataSource remoteDataSource;

  const RawMaterialRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<RawMaterialEntity>>> getMaterials({
    String? type,
    String? search,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final result = await remoteDataSource.getMaterials(
        type:    type,
        search:  search,
        page:    page,
        perPage: perPage,
      );
      return Right(PaginatedResponse<RawMaterialEntity>(
        data:        result.data,
        currentPage: result.currentPage,
        lastPage:    result.lastPage,
        perPage:     result.perPage,
        total:       result.total,
      ));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, RawMaterialEntity>> createMaterial({
    required String name,
    required String type,
    required String unit,
  }) async {
    try {
      final model = await remoteDataSource.createMaterial(
        name: name,
        type: type,
        unit: unit,
      );
      return Right(model);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMaterial(int id) async {
    try {
      await remoteDataSource.deleteMaterial(id);
      return const Right(null);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<RawMaterialMovementEntity>>> storeBatchMovement({
    required String dateTime,
    required String type,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final models = await remoteDataSource.storeBatchMovement(
        dateTime: dateTime,
        type:     type,
        notes:    notes,
        items:    items,
      );
      return Right(models);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }
}
