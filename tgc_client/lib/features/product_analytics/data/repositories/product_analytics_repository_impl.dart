import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/product_analytics_entity.dart';
import '../../domain/repositories/product_analytics_repository.dart';
import '../datasources/product_analytics_remote_datasource.dart';

class ProductAnalyticsRepositoryImpl implements ProductAnalyticsRepository {
  final ProductAnalyticsRemoteDataSource _remoteDataSource;

  const ProductAnalyticsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, ProductAnalyticsEntity>> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  }) async {
    try {
      final result = await _remoteDataSource.getAnalytics(
        periodFrom: periodFrom,
        periodTo:   periodTo,
        trendBy:    trendBy,
      );
      return Right(result);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }
}
