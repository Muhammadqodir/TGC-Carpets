import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/product_analytics_entity.dart';

abstract class ProductAnalyticsRepository {
  Future<Either<Failure, ProductAnalyticsEntity>> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  });
}
