import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/production_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';
import '../../domain/repositories/production_analytics_repository.dart';
import '../datasources/production_analytics_remote_datasource.dart';

class ProductionAnalyticsRepositoryImpl implements ProductionAnalyticsRepository {
  final ProductionAnalyticsRemoteDataSource _remoteDataSource;

  const ProductionAnalyticsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, ProductionAnalyticsEntity>> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  }) async {
    try {
      // Fetched side by side. The shift / machine report is optional: a
      // server without that endpoint yet still shows the rest of the page.
      final results = await Future.wait<Object?>([
        _remoteDataSource.getAnalytics(
          periodFrom: periodFrom,
          periodTo:   periodTo,
          trendBy:    trendBy,
        ),
        _remoteDataSource
            .getOperations(periodFrom: periodFrom, periodTo: periodTo, trendBy: trendBy)
            .then<ProductionOperationsEntity?>((o) => o)
            .catchError((Object _) => null),
      ]);
      final report = results[0] as ProductionAnalyticsEntity;
      return Right(report.withOperations(results[1] as ProductionOperationsEntity?));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }
}
