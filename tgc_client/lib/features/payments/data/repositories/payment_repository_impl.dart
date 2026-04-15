import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/payment_entity.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_remote_datasource.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource remoteDataSource;

  const PaymentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<PaymentEntity>>> getPayments({
    int? clientId,
    int? orderId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getPayments(
        clientId: clientId,
        orderId: orderId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
      );
      return Right(
        PaginatedResponse<PaymentEntity>(
          data: result.data,
          currentPage: result.currentPage,
          lastPage: result.lastPage,
          perPage: result.perPage,
          total: result.total,
        ),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, PaymentEntity>> createPayment({
    required int clientId,
    int? orderId,
    required double amount,
    String? notes,
  }) async {
    try {
      final result = await remoteDataSource.createPayment(
        clientId: clientId,
        orderId: orderId,
        amount: amount,
        notes: notes,
      );
      return Right(result);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> deletePayment(int id) async {
    try {
      await remoteDataSource.deletePayment(id);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
