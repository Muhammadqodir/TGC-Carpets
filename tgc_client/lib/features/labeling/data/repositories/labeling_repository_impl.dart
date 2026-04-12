import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/labeling_item_entity.dart';
import '../../domain/repositories/labeling_repository.dart';
import '../datasources/labeling_remote_datasource.dart';

class LabelingRepositoryImpl implements LabelingRepository {
  final LabelingRemoteDataSource remoteDataSource;

  const LabelingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<LabelingItemEntity>>> getLabelingItems() async {
    try {
      final result = await remoteDataSource.getLabelingItems();
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
  Future<Either<Failure, LabelingItemEntity>> printLabel({
    required int batchId,
    required int itemId,
  }) async {
    try {
      final result = await remoteDataSource.printLabel(
        batchId: batchId,
        itemId: itemId,
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
}
