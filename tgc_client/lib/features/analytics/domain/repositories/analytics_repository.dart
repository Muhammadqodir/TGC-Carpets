import 'package:dartz/dartz.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/analytics/domain/entities/client_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/entities/financial_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/entities/production_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/entities/sales_analytics_entity.dart';

abstract class AnalyticsRepository {
  Future<Either<Failure, SalesAnalyticsEntity>> getSalesAnalytics({
    required DateTime from,
    required DateTime to,
  });

  Future<Either<Failure, ProductionAnalyticsEntity>> getProductionAnalytics({
    required DateTime from,
    required DateTime to,
  });

  Future<Either<Failure, FinancialAnalyticsEntity>> getFinancialAnalytics({
    required DateTime from,
    required DateTime to,
  });

  Future<Either<Failure, ClientAnalyticsEntity>> getClientAnalytics({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  });
}
