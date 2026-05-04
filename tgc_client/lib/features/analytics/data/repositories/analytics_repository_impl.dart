import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/analytics/data/datasources/analytics_remote_datasource.dart';
import 'package:tgc_client/features/analytics/domain/entities/client_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/entities/financial_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/entities/production_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/entities/sales_analytics_entity.dart';
import 'package:tgc_client/features/analytics/domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsRemoteDataSource remoteDataSource;

  const AnalyticsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, SalesAnalyticsEntity>> getSalesAnalytics({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await remoteDataSource.getSalesAnalytics(
        from: from,
        to: to,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? 'Serverda xatolik yuz berdi'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProductionAnalyticsEntity>> getProductionAnalytics({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await remoteDataSource.getProductionAnalytics(
        from: from,
        to: to,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? 'Serverda xatolik yuz berdi'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FinancialAnalyticsEntity>> getFinancialAnalytics({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await remoteDataSource.getFinancialAnalytics(
        from: from,
        to: to,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? 'Serverda xatolik yuz berdi'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ClientAnalyticsEntity>> getClientAnalytics({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  }) async {
    try {
      final result = await remoteDataSource.getClientAnalytics(
        from: from,
        to: to,
        limit: limit,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? 'Serverda xatolik yuz berdi'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
