import 'package:dartz/dartz.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/analytics/domain/entities/financial_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/repositories/analytics_repository.dart';

class GetFinancialAnalyticsUseCase {
  final AnalyticsRepository repository;

  const GetFinancialAnalyticsUseCase(this.repository);

  Future<Either<Failure, FinancialAnalyticsEntity>> call({
    required DateTime from,
    required DateTime to,
  }) async {
    return await repository.getFinancialAnalytics(from: from, to: to);
  }
}
