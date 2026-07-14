import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/production_analytics_entity.dart';

abstract class ProductionAnalyticsRepository {
  Future<Either<Failure, ProductionAnalyticsEntity>> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  });
}
