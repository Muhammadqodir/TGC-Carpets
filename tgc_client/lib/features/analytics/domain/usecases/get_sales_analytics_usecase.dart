import 'package:dartz/dartz.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/analytics/domain/entities/sales_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/repositories/analytics_repository.dart';

class GetSalesAnalyticsUseCase {
  final AnalyticsRepository repository;

  const GetSalesAnalyticsUseCase(this.repository);

  Future<Either<Failure, SalesAnalyticsEntity>> call({
    required DateTime from,
    required DateTime to,
  }) async {
    return await repository.getSalesAnalytics(from: from, to: to);
  }
}
