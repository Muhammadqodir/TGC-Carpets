import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/product_analytics_entity.dart';

abstract class ProductAnalyticsRepository {
  Future<Either<Failure, ProductAnalyticsEntity>> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  });

  Future<Either<Failure, List<TopProductItem>>> getTopProducts({
    required String periodFrom,
    required String periodTo,
    int? typeId,
    int? qualityId,
    int? colorId,
    int? sizeId,
    int? edgeId,
    int limit = 10,
  });
}
