import 'package:dartz/dartz.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/analytics/domain/entities/client_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/repositories/analytics_repository.dart';

class GetClientAnalyticsUseCase {
  final AnalyticsRepository repository;

  const GetClientAnalyticsUseCase(this.repository);

  Future<Either<Failure, ClientAnalyticsEntity>> call({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  }) async {
    return await repository.getClientAnalytics(from: from, to: to, limit: limit);
  }
}
