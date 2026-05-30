import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/product_analytics_entity.dart';
import '../repositories/product_analytics_repository.dart';

class GetProductAnalyticsParams extends Equatable {
  final String periodFrom;
  final String periodTo;
  final String trendBy;

  const GetProductAnalyticsParams({
    required this.periodFrom,
    required this.periodTo,
    this.trendBy = 'day',
  });

  @override
  List<Object?> get props => [periodFrom, periodTo, trendBy];
}

class GetProductAnalyticsUseCase {
  final ProductAnalyticsRepository _repository;

  const GetProductAnalyticsUseCase(this._repository);

  Future<Either<Failure, ProductAnalyticsEntity>> call(
    GetProductAnalyticsParams params,
  ) {
    return _repository.getAnalytics(
      periodFrom: params.periodFrom,
      periodTo: params.periodTo,
      trendBy: params.trendBy,
    );
  }
}
