import 'package:dartz/dartz.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/analytics/domain/entities/production_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/repositories/analytics_repository.dart';

class GetProductionAnalyticsUseCase {
  final AnalyticsRepository repository;

  const GetProductionAnalyticsUseCase(this.repository);

  Future<Either<Failure, ProductionAnalyticsEntity>> call({
    required DateTime from,
    required DateTime to,
  }) async {
    return await repository.getProductionAnalytics(from: from, to: to);
  }
}
