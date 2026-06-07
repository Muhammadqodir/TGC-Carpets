import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/product_analytics_entity.dart';
import '../repositories/product_analytics_repository.dart';

class GetTopProductsParams extends Equatable {
  final String periodFrom;
  final String periodTo;
  final int? typeId;
  final int? qualityId;
  final int? colorId;
  final int? sizeId;
  final int? edgeId;
  final int limit;

  const GetTopProductsParams({
    required this.periodFrom,
    required this.periodTo,
    this.typeId,
    this.qualityId,
    this.colorId,
    this.sizeId,
    this.edgeId,
    this.limit = 10,
  });

  @override
  List<Object?> get props =>
      [periodFrom, periodTo, typeId, qualityId, colorId, sizeId, edgeId, limit];
}

class GetTopProductsUseCase {
  final ProductAnalyticsRepository _repository;

  const GetTopProductsUseCase(this._repository);

  Future<Either<Failure, List<TopProductItem>>> call(GetTopProductsParams params) {
    return _repository.getTopProducts(
      periodFrom: params.periodFrom,
      periodTo:   params.periodTo,
      typeId:     params.typeId,
      qualityId:  params.qualityId,
      colorId:    params.colorId,
      sizeId:     params.sizeId,
      edgeId:     params.edgeId,
      limit:      params.limit,
    );
  }
}
