import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/production_analytics_entity.dart';
import '../repositories/production_analytics_repository.dart';

class GetProductionAnalyticsParams extends Equatable {
  final String periodFrom;
  final String periodTo;
  final String trendBy;

  const GetProductionAnalyticsParams({
    required this.periodFrom,
    required this.periodTo,
    this.trendBy = 'day',
  });

  @override
  List<Object?> get props => [periodFrom, periodTo, trendBy];
}

class GetProductionAnalyticsUseCase {
  final ProductionAnalyticsRepository _repository;

  const GetProductionAnalyticsUseCase(this._repository);

  Future<Either<Failure, ProductionAnalyticsEntity>> call(
    GetProductionAnalyticsParams params,
  ) {
    return _repository.getAnalytics(
      periodFrom: params.periodFrom,
      periodTo: params.periodTo,
      trendBy: params.trendBy,
    );
  }
}
