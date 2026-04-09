import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_datasource.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remoteDataSource;

  const OrderRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<OrderEntity>>> getOrders({
    String? status,
    int? clientId,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getOrders(
        status: status,
        clientId: clientId,
        userId: userId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
      );
      return Right(
        PaginatedResponse<OrderEntity>(
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
  Future<Either<Failure, OrderEntity>> getOrder(int id) async {
    try {
      final order = await remoteDataSource.getOrder(id);
      return Right(order);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> createOrder({
    required String orderDate,
    required List<Map<String, dynamic>> items,
    required int clientId,
    String? notes,
    String? externalUuid,
  }) async {
    try {
      final order = await remoteDataSource.createOrder(
        orderDate: orderDate,
        items: items,
        clientId: clientId,
        notes: notes,
        externalUuid: externalUuid,
      );
      return Right(order);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> updateOrder(
    int id, {
    String? status,
    String? orderDate,
    List<Map<String, dynamic>>? items,
    int? clientId,
    String? notes,
  }) async {
    try {
      final order = await remoteDataSource.updateOrder(
        id,
        status: status,
        orderDate: orderDate,
        items: items,
        clientId: clientId,
        notes: notes,
      );
      return Right(order);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> deleteOrder(int id) async {
    try {
      await remoteDataSource.deleteOrder(id);
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
